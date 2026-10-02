"""Opt-in development smoke test against real Supabase and a running API/Worker."""

import argparse
import asyncio
import hashlib
import io
import json
import secrets
import time
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse
from uuid import uuid4
from zoneinfo import ZoneInfo

import httpx
from PIL import Image

from app.core.config import Settings
from app.integrations.storage import SupabaseStorageGateway
from app.models.enums import MediaPurpose
from app.services.media import MIME_EXTENSIONS, PURPOSE_PATHS


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


def validate_target(settings: Settings, api_url: str, allow_shared_dev: bool) -> None:
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
        not settings.letter_generation_enabled,
        "Keep letter generation disabled until sensor integration.",
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


def run(settings: Settings, api_url: str, photo: Path | None, timeout: float) -> list[str]:
    checks = []
    accounts: list[str] = []
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
            token = request(
                client,
                "POST",
                f"{auth}/token?grant_type=password",
                headers={
                    "apikey": settings.supabase_publishable_key or settings.supabase_secret_key
                },
                json={"email": email, "password": password},
            ).json()["access_token"]
            return user["id"], {"Authorization": f"Bearer {token}"}

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
                "nickname": "Smoke basil",
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
                "title": "Smoke",
                "content": "Integration test.",
                "media_file_id": media_id,
            }
            first = request(
                client, "PUT", diary_url, expected=(201,), headers=headers, json=diary
            ).json()
            diary["content"] = "Updated integration test."
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
                data = photo.read_bytes()
                with Image.open(io.BytesIO(data)) as image:
                    mime = Image.MIME[image.format]
                require(mime in MIME_EXTENSIONS, "Photo format must be JPEG, PNG or WebP.")
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
                    poll(client, job_url, headers, timeout)
                    checks.append(f"real_worker_{purpose.value.lower()}")
            request(client, "DELETE", diary_url, expected=(204,), headers=headers)
            request(client, "GET", diary_url, expected=(404,), headers=headers)
            request(client, "DELETE", plant_url, expected=(204,), headers=headers)
            request(client, "GET", plant_url, expected=(404,), headers=headers)
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
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()
    try:
        settings = Settings()
        validate_target(settings, args.api_url, args.allow_shared_dev)
        require(args.timeout > 0, "Timeout must be positive.")
        require(
            not args.photo or args.allow_paid,
            "--photo requires --allow-paid for external AI calls.",
        )
        checks = run(settings, args.api_url, args.photo, args.timeout)
        print(json.dumps({"passed": checks, "ai_skipped": args.photo is None}))
    except Exception as exc:
        message = str(exc) if isinstance(exc, SmokeError) else type(exc).__name__
        print(json.dumps({"error": message}))
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
