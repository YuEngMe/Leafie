from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.main import create_app

PROTECTED_REQUESTS: list[tuple[str, str, dict[str, object] | None, dict[str, object] | None]] = [
    (
        "POST",
        "/api/v1/media/presign",
        {
            "purpose": "DIAGNOSIS",
            "content_type": "image/jpeg",
            "size_bytes": 1024,
            "checksum_sha256": "a" * 64,
        },
        None,
    ),
    ("POST", f"/api/v1/media/{uuid4()}/complete", None, None),
    ("GET", f"/api/v1/media/{uuid4()}/download-url", None, None),
    ("DELETE", f"/api/v1/media/{uuid4()}", None, None),
    ("GET", "/api/v1/users/me", None, None),
    ("PATCH", "/api/v1/users/me", {"nickname": "초록집사"}, None),
    ("DELETE", "/api/v1/users/me", {"confirmation": "DELETE"}, None),
    ("PATCH", "/api/v1/users/me/selected-plant", {"selected_plant_id": None}, None),
    ("GET", "/api/v1/users/me/stats", None, None),
    (
        "PATCH",
        "/api/v1/users/me/notification-settings",
        {"push_enabled": True},
        None,
    ),
    ("GET", "/api/v1/species", None, {"query": "바질"}),
    ("POST", "/api/v1/species/identifications", {"media_file_id": str(uuid4())}, None),
    ("GET", f"/api/v1/species/identifications/{uuid4()}", None, None),
    (
        "POST",
        "/api/v1/plants",
        {
            "client_registration_id": str(uuid4()),
            "nickname": "새싹이",
            "species_reference_id": "catalog:ocimum-basilicum",
            "species_selection_method": "SEARCH",
            "species_identification_id": None,
            "primary_media_file_id": None,
            "started_on": "2026-03-01",
            "place_name": "학교",
            "pot_type": "PLASTIC",
            "placement": "WINDOW",
            "last_watered_on": "2026-07-30",
            "repotting_history": {"status": "UNKNOWN", "date": None},
            "personality_type": "OUTGOING",
            "color_id": "color_green_01",
            "hair_id": "hair_leaf_01",
            "accessory_id": "accessory_star_01",
        },
        None,
    ),
    ("GET", f"/api/v1/plants/{uuid4()}/diaries", None, {"year": 2026, "month": 8}),
    (
        "PUT",
        f"/api/v1/plants/{uuid4()}/diaries/2026-08-01",
        {"content": "오늘의 기록", "condition_score": 75},
        None,
    ),
    ("GET", f"/api/v1/plants/{uuid4()}/diaries/2026-08-01", None, None),
    ("DELETE", f"/api/v1/plants/{uuid4()}/diaries/2026-08-01", None, None),
    (
        "POST",
        f"/api/v1/plants/{uuid4()}/care-events",
        {
            "client_event_id": str(uuid4()),
            "type": "CUSTOM",
            "title": "화분 방향 돌리기",
            "due_date": "2026-08-02",
        },
        None,
    ),
    ("POST", f"/api/v1/care-events/{uuid4()}/complete", {}, None),
    (
        "PUT",
        f"/api/v1/plants/{uuid4()}/daily-memos/2026-08-02",
        {"content": "오늘 메모"},
        None,
    ),
    ("DELETE", f"/api/v1/plants/{uuid4()}/daily-memos/2026-08-02", None, None),
    ("GET", f"/api/v1/plants/{uuid4()}/conversations", None, None),
    ("POST", f"/api/v1/plants/{uuid4()}/conversations", {"title": "새 채팅"}, None),
    ("DELETE", f"/api/v1/conversations/{uuid4()}", None, None),
    ("GET", f"/api/v1/conversations/{uuid4()}/messages", None, None),
    ("POST", f"/api/v1/conversations/{uuid4()}/messages", {"content": "안녕"}, None),
    ("POST", f"/api/v1/ai-actions/{uuid4()}/confirm", None, None),
    ("POST", f"/api/v1/ai-actions/{uuid4()}/cancel", None, None),
    (
        "POST",
        f"/api/v1/plants/{uuid4()}/diagnoses",
        {"conversation_id": str(uuid4()), "media_file_id": str(uuid4())},
        None,
    ),
    ("GET", f"/api/v1/plants/{uuid4()}/diagnoses", None, None),
    ("GET", f"/api/v1/diagnoses/{uuid4()}", None, None),
    ("POST", f"/api/v1/diagnoses/{uuid4()}/retry", None, None),
    ("POST", f"/api/v1/diagnoses/{uuid4()}/cancel", None, None),
]

EXPECTED_API_OPERATIONS = {
    ("GET", "/api/v1/health"),
    ("GET", "/api/v1/ready"),
    ("POST", "/api/v1/media/presign"),
    ("POST", "/api/v1/media/{media_file_id}/complete"),
    ("GET", "/api/v1/media/{media_file_id}/download-url"),
    ("DELETE", "/api/v1/media/{media_file_id}"),
    ("GET", "/api/v1/users/me"),
    ("PATCH", "/api/v1/users/me"),
    ("DELETE", "/api/v1/users/me"),
    ("PATCH", "/api/v1/users/me/selected-plant"),
    ("GET", "/api/v1/users/me/stats"),
    ("PATCH", "/api/v1/users/me/notification-settings"),
    ("GET", "/api/v1/species"),
    ("POST", "/api/v1/species/identifications"),
    ("GET", "/api/v1/species/identifications/{identification_id}"),
    ("POST", "/api/v1/plants"),
    ("GET", "/api/v1/plants/{plant_id}/diaries"),
    ("PUT", "/api/v1/plants/{plant_id}/diaries/{date}"),
    ("GET", "/api/v1/plants/{plant_id}/diaries/{date}"),
    ("DELETE", "/api/v1/plants/{plant_id}/diaries/{date}"),
    ("POST", "/api/v1/plants/{plant_id}/care-events"),
    ("POST", "/api/v1/care-events/{event_id}/complete"),
    ("PUT", "/api/v1/plants/{plant_id}/daily-memos/{date}"),
    ("DELETE", "/api/v1/plants/{plant_id}/daily-memos/{date}"),
    ("GET", "/api/v1/plants/{plant_id}/conversations"),
    ("POST", "/api/v1/plants/{plant_id}/conversations"),
    ("DELETE", "/api/v1/conversations/{conversation_id}"),
    ("GET", "/api/v1/conversations/{conversation_id}/messages"),
    ("POST", "/api/v1/conversations/{conversation_id}/messages"),
    ("POST", "/api/v1/ai-actions/{action_id}/confirm"),
    ("POST", "/api/v1/ai-actions/{action_id}/cancel"),
    ("POST", "/api/v1/plants/{plant_id}/diagnoses"),
    ("GET", "/api/v1/plants/{plant_id}/diagnoses"),
    ("GET", "/api/v1/diagnoses/{diagnosis_id}"),
    ("POST", "/api/v1/diagnoses/{diagnosis_id}/retry"),
    ("POST", "/api/v1/diagnoses/{diagnosis_id}/cancel"),
}


def test_openapi_contains_every_expected_api_operation() -> None:
    application = create_app()

    with TestClient(application) as client:
        document = client.get("/api/v1/openapi.json").json()

    actual = {
        (method.upper(), path)
        for path, operations in document["paths"].items()
        for method in operations
        if method.lower() in {"get", "post", "put", "patch", "delete", "options", "head", "trace"}
    }
    assert actual == EXPECTED_API_OPERATIONS


@pytest.mark.parametrize(("method", "path", "body", "params"), PROTECTED_REQUESTS)
def test_every_protected_api_operation_rejects_missing_authentication(
    method: str,
    path: str,
    body: dict[str, object] | None,
    params: dict[str, object] | None,
) -> None:
    application = create_app()

    with TestClient(application) as client:
        response = client.request(method, path, json=body, params=params)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert response.headers["X-Request-ID"].startswith("req_")
