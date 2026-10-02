"""Opt-in development smoke test against real Supabase and a running API/Worker."""

import argparse
import asyncio
import hashlib
import io
import json
import secrets
import time
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urlparse
from uuid import uuid4
from zoneinfo import ZoneInfo

import httpx
from PIL import Image
from sqlalchemy import select

from app.core.config import Settings
from app.db.session import Database
from app.integrations.storage import SupabaseStorageGateway
from app.models.enums import MediaPurpose
from app.models.letter import Letter
from app.services.media import MIME_EXTENSIONS, PURPOSE_PATHS, detect_image_content_type


class SmokeError(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SmokeError(message)


def request(client: httpx.Client, method: str, url: str, expected=(200,), **kwargs):
    response = client.request(method, url, **kwargs)
    # Never include provider bodies, tokens, signed URLs or connection strings in failures.
    require(response.status_code in expected, f"HTTP_{response.status_code}: expected {expected}")
    return response


def validate_target(
    settings: Settings,
    api_url: str,
    allow_shared_dev: bool,
    *,
    letter: bool = False,
    allow_paid: bool = False,
) -> None:
    require(allow_shared_dev, "Pass --allow-shared-dev to create disposable test accounts.")
    require(settings.app_env == "local", "Only APP_ENV=local is allowed.")
    parsed = urlparse(api_url)
    require(
        parsed.scheme == "http"
        and parsed.hostname in {"localhost", "127.0.0.1"}
        and not parsed.username
        and not parsed.password
        and not parsed.query
        and not parsed.fragment,
        "The API must be a local HTTP server without credentials or query parameters.",
    )
    require(
        bool(settings.supabase_url and settings.supabase_secret_key), "Supabase is not configured."
    )
    require(
        settings.letter_generation_enabled == letter,
        "Enabled letter generation requires --letter; --letter requires an enabled server.",
    )
    require(not letter or allow_paid, "--letter requires --allow-paid for OpenAI calls.")


def letter_snapshot(settings: Settings, diary_id: str) -> dict:
    async def read():
        database = Database(settings)
        try:
            async with database.session_context() as session:
                rows = (
                    await session.scalars(select(Letter).where(Letter.diary_id == diary_id))
                ).all()
                require(len(rows) == 1, "Expected exactly one letter per test diary.")
                return {
                    column.name: getattr(rows[0], column.name)
                    for column in Letter.__table__.columns
                }
        finally:
            await database.close()

    return asyncio.run(read())


def verify_unpublished_letter(settings, client, api, headers, diary_id, letter_url):
    try:
        request(client, "GET", letter_url, expected=(404,), headers=headers)
        require(
            not request(client, "GET", f"{api}/letters", headers=headers).json()["items"],
            "Unpublished letter is visible in the mailbox.",
        )
        require(
            request(client, "GET", f"{api}/letters/unread-count", headers=headers).json()[
                "unread_count"
            ]
            == 0,
            "Unpublished letter is counted as unread.",
        )
        pending_notifications = request(
            client, "GET", f"{api}/notifications", headers=headers
        ).json()["items"]
        require(
            not any(item["source_type"] == "LETTER" for item in pending_notifications),
            "Letter arrival notification appeared before publication.",
        )
    except SmokeError:
        # The worker can publish between the DB snapshot and these HTTP requests.
        if letter_snapshot(settings, diary_id)["published_at"] is None:
            raise


def verify_letter(
    settings, client, api, headers, other_headers, diary_url, diary, diary_id, timeout
):
    deadline = time.monotonic() + timeout
    original = None
    last_progress = 0
    while time.monotonic() < deadline:
        row = letter_snapshot(settings, diary_id)
        require(row["status"] != "FAILED", f"Letter failed: {row['failure_code']}")
        delay = (row["scheduled_at"] - row["created_at"]).total_seconds()
        require(299 <= delay <= 901, "Letter delay is outside the 5-15 minute contract.")
        letter_url = f"{api}/letters/{row['id']}"
        request(client, "GET", letter_url, expected=(403, 404), headers=other_headers)
        if original:
            require(
                all(
                    row[key] == original[key]
                    for key in (
                        "id",
                        "content",
                        "input_snapshot",
                        "scheduled_at",
                        "generated_at",
                    )
                ),
                "Diary edit changed the existing generated letter.",
            )
        if row["status"] == "COMPLETED" and original is None:
            require(
                row["provider"] == "OPENAI" and bool(row["provider_response_id"]),
                "Letter was not generated by real OpenAI.",
            )
            require(bool(row["content"] and row["input_snapshot"]), "Empty generated letter.")
            original = row.copy()
            changed = dict(diary, content="오늘은 편지를 기다리며 바질 잎을 한 번 더 살펴봤어.")
            request(client, "PUT", diary_url, headers=headers, json=changed)
            print(
                json.dumps(
                    {
                        "letter_generated": {
                            "model": row["model"],
                            "input_tokens": row["input_tokens"],
                            "output_tokens": row["output_tokens"],
                            "content": row["content"],
                            "sensor_summary": row["input_snapshot"].get("sensor_summary"),
                            "scheduled_delay_seconds": round(delay),
                        }
                    },
                    ensure_ascii=False,
                ),
                flush=True,
            )
        if row["published_at"] is not None:
            require(original is not None, "Letter published without generation.")
            require(row["published_at"] >= row["scheduled_at"], "Letter published too early.")
            break
        verify_unpublished_letter(settings, client, api, headers, diary_id, letter_url)
        if time.monotonic() - last_progress >= 30:
            print(
                json.dumps(
                    {
                        "letter_wait": row["status"],
                        "remaining_seconds": max(
                            0, round((row["scheduled_at"] - datetime.now(UTC)).total_seconds())
                        ),
                    }
                ),
                flush=True,
            )
            last_progress = time.monotonic()
        time.sleep(5)
    else:
        raise SmokeError("Real letter generation/publication timed out.")

    detail = request(client, "GET", letter_url, headers=headers).json()
    require(
        detail["content"] == original["content"] and not detail["is_read"],
        "Letter detail changed content or implicitly marked it read.",
    )
    mailbox = request(client, "GET", f"{api}/letters", headers=headers).json()
    require(
        len(mailbox["items"]) == 1 and mailbox["items"][0]["id"] == str(row["id"]),
        "Published letter is missing or duplicated.",
    )
    require(
        request(client, "GET", f"{api}/letters/unread-count", headers=headers).json()[
            "unread_count"
        ]
        == 1,
        "Published unread count mismatch.",
    )
    notifications = request(client, "GET", f"{api}/notifications", headers=headers).json()
    matches = [
        item
        for item in notifications["items"]
        if item["source_type"] == "LETTER" and item["source_id"] == str(row["id"])
    ]
    require(
        len(matches) == 1 and matches[0]["type"] == "LETTER_ARRIVED",
        "Expected exactly one letter-arrival notification.",
    )
    notification_url = f"{api}/notifications/{matches[0]['id']}/read"
    request(client, "POST", notification_url, expected=(403, 404), headers=other_headers)
    require(
        request(client, "POST", notification_url, headers=headers).json()["read_at"],
        "Notification read failed.",
    )
    request(client, "POST", f"{letter_url}/read", expected=(403, 404), headers=other_headers)
    read = request(client, "POST", f"{letter_url}/read", headers=headers).json()
    replay = request(client, "POST", f"{letter_url}/read", headers=headers).json()
    require(read["is_read"] and read["read_at"] == replay["read_at"], "Read replay changed time.")
    require(
        request(client, "GET", f"{api}/letters/unread-count", headers=headers).json()[
            "unread_count"
        ]
        == 0,
        "Read letter still counted as unread.",
    )
    request(client, "DELETE", letter_url, expected=(403, 404), headers=other_headers)
    for _ in range(2):
        request(client, "DELETE", letter_url, expected=(204,), headers=headers)
    request(client, "GET", letter_url, expected=(404,), headers=headers)
    request(client, "GET", diary_url, headers=headers)
    require(
        not request(client, "GET", f"{api}/letters", headers=headers).json()["items"],
        "Deleted letter remains visible.",
    )
    remaining_notifications = request(
        client, "GET", f"{api}/notifications", headers=headers
    ).json()["items"]
    require(
        not any(item["source_id"] == str(row["id"]) for item in remaining_notifications),
        "Deleted letter notification remains visible.",
    )
    print(
        json.dumps(
            {
                "letter_publication_delay_seconds": round(
                    (row["published_at"] - row["created_at"]).total_seconds()
                )
            }
        ),
        flush=True,
    )


def poll(client: httpx.Client, url: str, headers: dict, timeout: float) -> dict:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = request(client, "GET", url, headers=headers).json()
        if result["status"] == "COMPLETED":
            return result
        require(
            result["status"] in {"PENDING", "PROCESSING"}, "AI job did not complete successfully."
        )
        time.sleep(1)
    raise SmokeError("Worker completion timed out.")


def read_photo(photo: Path) -> tuple[bytes, str]:
    data = photo.read_bytes()
    mime = detect_image_content_type(data)
    require(mime in MIME_EXTENSIONS, "Photo format must be JPEG, PNG or WebP.")
    with Image.open(io.BytesIO(data)) as image:
        image.verify()
    return data, mime


def run(
    settings: Settings,
    api_url: str,
    photo: Path | None,
    timeout: float,
    *,
    letter: bool = False,
    letter_timeout: float = 1200,
) -> list[str]:
    photo_data = read_photo(photo) if photo else None
    checks = []
    accounts: list[str] = []
    credentials: dict[str, tuple[str, str]] = {}
    objects: list[str] = []
    api = f"{api_url.rstrip('/')}{settings.api_v1_prefix}"
    auth = f"{settings.supabase_url.rstrip('/')}/auth/v1"
    admin_headers = {
        "apikey": settings.supabase_secret_key,
        "Authorization": f"Bearer {settings.supabase_secret_key}",
    }
    today = datetime.now(ZoneInfo("Asia/Seoul")).date().isoformat()
    buffer = io.BytesIO()
    Image.new("RGB", (64, 64), "green").save(buffer, format="PNG")

    with httpx.Client(timeout=15, follow_redirects=False) as client:

        def login(email: str, password: str) -> dict:
            token = request(
                client,
                "POST",
                f"{auth}/token?grant_type=password",
                headers={
                    "apikey": settings.supabase_publishable_key or settings.supabase_secret_key
                },
                json={"email": email, "password": password},
            ).json()["access_token"]
            return {"Authorization": f"Bearer {token}"}

        def create_account() -> tuple[str, dict]:
            email = f"leafie-smoke-{uuid4().hex}@example.invalid"
            password = secrets.token_urlsafe(32)
            user = request(
                client,
                "POST",
                f"{auth}/admin/users",
                expected=(200, 201),
                headers=admin_headers,
                json={"email": email, "password": password, "email_confirm": True},
            ).json()
            accounts.append(user["id"])
            credentials[user["id"]] = (email, password)
            return user["id"], login(email, password)

        def upload(user_id: str, headers: dict, purpose: MediaPurpose, data: bytes, mime: str):
            result = request(
                client,
                "POST",
                f"{api}/media/presign",
                expected=(201,),
                headers=headers,
                json={
                    "purpose": purpose.value,
                    "content_type": mime,
                    "size_bytes": len(data),
                    "checksum_sha256": hashlib.sha256(data).hexdigest(),
                },
            ).json()
            media_id = result["media_file_id"]
            objects.append(f"{user_id}/{PURPOSE_PATHS[purpose]}/{media_id}.{MIME_EXTENSIONS[mime]}")
            request(
                client,
                "PUT",
                result["upload_url"],
                expected=(200, 201),
                headers=result["upload_headers"],
                content=data,
            )
            for _ in range(2):
                complete = request(
                    client, "POST", f"{api}/media/{media_id}/complete", headers=headers
                ).json()
                require(complete["status"] == "READY", "Media completion failed.")
            return media_id

        try:
            request(client, "GET", f"{api}/ready")
            request(client, "GET", f"{api}/users/me", expected=(401,))
            user_id, headers = create_account()
            _, other_headers = create_account()
            request(client, "GET", f"{api}/users/me", headers=headers)
            request(
                client, "PATCH", f"{api}/users/me", headers=headers, json={"nickname": "Smoke test"}
            )
            checks.append("real_auth_jwt_profile")
            species = request(
                client, "GET", f"{api}/species", headers=headers, params={"query": "바질"}
            ).json()
            require(bool(species["items"]), "Basil is missing from the species catalog.")
            registration = {
                "client_registration_id": str(uuid4()),
                "nickname": "소심한 바질",
                "species_reference_id": species["items"][0]["reference_id"],
                "species_selection_method": "SEARCH",
                "started_on": today,
                "place_name": "Test",
                "personality_type": "INTROVERTED",
                "body_id": "body_circle",
                "color_id": "color_green",
                "hair_id": "hair_sprout",
                "expression_id": "expression_default",
            }
            plant = request(
                client, "POST", f"{api}/plants", expected=(201,), headers=headers, json=registration
            ).json()
            duplicate = request(
                client, "POST", f"{api}/plants", expected=(201,), headers=headers, json=registration
            ).json()
            require(plant["id"] == duplicate["id"], "Registration replay created a second plant.")
            plant_url = f"{api}/plants/{plant['id']}"
            request(client, "GET", plant_url, expected=(403, 404), headers=other_headers)
            checks.append("registration_replay_and_ownership")
            media_id = upload(user_id, headers, MediaPurpose.DIARY, buffer.getvalue(), "image/png")
            request(
                client,
                "GET",
                f"{api}/media/{media_id}/download-url",
                expected=(403, 404),
                headers=other_headers,
            )
            download = request(
                client, "GET", f"{api}/media/{media_id}/download-url", headers=headers
            ).json()
            require(
                request(client, "GET", download["download_url"]).content == buffer.getvalue(),
                "Storage round-trip mismatch.",
            )
            checks.append("real_storage_upload_complete_download")
            diary_url = f"{plant_url}/diaries/{today}"
            diary = {
                "weather": "SUNNY",
                "title": "바질과 함께한 하루",
                "content": "오늘 네 잎이 초록빛으로 반짝이는 걸 봤어. 오래 함께 지내고 싶어.",
                "media_file_id": media_id,
            }
            first = request(
                client, "PUT", diary_url, expected=(201,), headers=headers, json=diary
            ).json()
            diary["content"] = "오늘 네 잎이 반짝이는 걸 봤어. 조용히 곁에 있어 줘서 고마워."
            updated = request(client, "PUT", diary_url, headers=headers, json=diary).json()
            require(first["id"] == updated["id"], "Diary update created a second diary.")
            request(client, "GET", diary_url, expected=(403, 404), headers=other_headers)
            request(
                client,
                "GET",
                f"{plant_url}/calendar",
                headers=headers,
                params={"from": today, "to": today},
            )
            request(client, "GET", f"{api}/home", headers=headers)
            checks.append("diary_update_calendar_home")
            if photo:
                data, mime = photo_data
                for purpose, create_url, status_path, id_key in (
                    (
                        MediaPurpose.SPECIES_IDENTIFICATION,
                        f"{api}/species/identifications",
                        "species/identifications",
                        "identification_id",
                    ),
                    (MediaPurpose.DIAGNOSIS, f"{plant_url}/diagnoses", "diagnoses", "diagnosis_id"),
                ):
                    uploaded = upload(user_id, headers, purpose, data, mime)
                    job = request(
                        client,
                        "POST",
                        create_url,
                        expected=(202,),
                        headers=headers,
                        json={"media_file_id": uploaded},
                    ).json()
                    replay = request(
                        client,
                        "POST",
                        create_url,
                        expected=(202,),
                        headers=headers,
                        json={"media_file_id": uploaded},
                    ).json()
                    require(job[id_key] == replay[id_key], "AI request replay created another job.")
                    job_url = f"{api}/{status_path}/{job[id_key]}"
                    request(client, "GET", job_url, expected=(403, 404), headers=other_headers)
                    result = poll(client, job_url, headers, timeout)
                    if purpose == MediaPurpose.SPECIES_IDENTIFICATION:
                        require(bool(result["candidates"]), "No species candidates returned.")
                        summary = {"species": result["candidates"][0]}
                    else:
                        require(
                            bool(result["overall_condition"] and result["condition_label"]),
                            "Diagnosis condition is missing.",
                        )
                        require(bool(result["recommended_care"]), "Diagnosis guidance is empty.")
                        summary = {
                            "diagnosis": {
                                key: result[key]
                                for key in (
                                    "overall_condition",
                                    "condition_label",
                                    "observations",
                                    "possible_causes",
                                    "recommended_care",
                                )
                            }
                        }
                        require(
                            request(client, "GET", result["photo_url"]).content == data,
                            "Diagnosis photo round-trip mismatch.",
                        )
                    print(json.dumps(summary, ensure_ascii=False), flush=True)
                    checks.append(f"real_worker_{purpose.value.lower()}")
            if letter:
                verify_letter(
                    settings,
                    client,
                    api,
                    headers,
                    other_headers,
                    diary_url,
                    diary,
                    first["id"],
                    letter_timeout,
                )
                checks.append(
                    "real_openai_letter_delayed_publication_edit_read_delete_notification"
                )
            # The original signed URL can expire during the real 5-15 minute wait.
            download = request(
                client, "GET", f"{api}/media/{media_id}/download-url", headers=headers
            ).json()
            request(client, "GET", download["download_url"])
            request(client, "DELETE", diary_url, expected=(204,), headers=headers)
            request(client, "GET", diary_url, expected=(404,), headers=headers)
            request(client, "DELETE", plant_url, expected=(204,), headers=headers)
            request(client, "GET", plant_url, expected=(404,), headers=headers)
            # Account deletion deliberately requires a recent password/OAuth authentication.
            headers = login(*credentials[user_id])
            request(
                client,
                "DELETE",
                f"{api}/users/me",
                expected=(204,),
                headers=headers,
                json={"confirmation": "DELETE"},
            )
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                response = client.get(f"{auth}/admin/users/{user_id}", headers=admin_headers)
                if response.status_code == 404:
                    checks.append("real_pgmq_worker_account_deletion")
                    break
                require(response.status_code == 200, "Unable to verify account deletion.")
                time.sleep(1)
            else:
                raise SmokeError("Account deletion Worker timed out.")
            require(
                client.get(download["download_url"]).status_code in {400, 404},
                "Account media was not deleted.",
            )
            request(client, "GET", f"{api}/users/me", expected=(401,), headers=headers)
            checks.append("deleted_account_access_and_storage_cleanup")
        finally:
            # Only IDs/paths created by this run are eligible for cleanup.
            async def cleanup_objects():
                storage = SupabaseStorageGateway(settings)
                try:
                    for path in objects:
                        await storage.delete_object(path)
                finally:
                    await storage.close()

            try:
                asyncio.run(cleanup_objects())
            finally:
                for account in accounts:
                    request(
                        client,
                        "DELETE",
                        f"{auth}/admin/users/{account}",
                        expected=(200, 204, 404),
                        headers=admin_headers,
                    )
    return checks


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api-url", default="http://127.0.0.1:8000")
    parser.add_argument("--allow-shared-dev", action="store_true")
    parser.add_argument("--photo", type=Path)
    parser.add_argument("--allow-paid", action="store_true")
    parser.add_argument("--letter", action="store_true")
    parser.add_argument("--letter-timeout", type=float, default=1200)
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()
    try:
        settings = Settings()
        validate_target(
            settings,
            args.api_url,
            args.allow_shared_dev,
            letter=args.letter,
            allow_paid=args.allow_paid,
        )
        require(args.timeout > 0, "Timeout must be positive.")
        require(args.letter_timeout > 0, "Letter timeout must be positive.")
        require(
            not args.photo or args.allow_paid,
            "--photo requires --allow-paid for external AI calls.",
        )
        checks = run(
            settings,
            args.api_url,
            args.photo,
            args.timeout,
            letter=args.letter,
            letter_timeout=args.letter_timeout,
        )
        print(
            json.dumps(
                {
                    "passed": checks,
                    "photo_ai_skipped": args.photo is None,
                    "letter_skipped": not args.letter,
                }
            ),
            flush=True,
        )
    except Exception as exc:
        message = str(exc) if isinstance(exc, SmokeError) else type(exc).__name__
        print(json.dumps({"error": message}))
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
