from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import get_current_user, get_database_session, get_storage_gateway
from app.api.v1 import plants as plants_api
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.schemas.plant import PlantCreateResponse, PlantDetailResponse


def test_diagnosis_openapi_has_no_conversation_contract() -> None:
    schemas = create_app().openapi()["components"]["schemas"]
    request = schemas["DiagnosisCreateRequest"]
    assert request["required"] == ["media_file_id"]
    assert "conversation_id" not in request["properties"]
    assert request["additionalProperties"] is False
    assert "related_conversation_id" not in schemas["DiagnosisDetailResponse"]["properties"]


def test_diary_openapi_uses_weather_and_title_without_condition_statistics() -> None:
    schemas = create_app().openapi()["components"]["schemas"]
    request = schemas["DiaryUpsertRequest"]
    assert set(request["required"]) == {"weather", "title", "content"}
    assert request["properties"]["title"]["maxLength"] == 100
    assert "condition_score" not in request["properties"]
    assert "condition_level" not in schemas["DiaryResponse"]["properties"]
    assert set(schemas["DiaryMonthResponse"]["properties"]) == {"entries"}


def test_care_openapi_uses_three_type_calendar_contract() -> None:
    schemas = create_app().openapi()["components"]["schemas"]
    create_request = schemas["CareEventCreateRequest"]
    assert set(create_request["required"]) == {
        "client_event_id",
        "care_type",
        "due_date",
    }
    assert "title" not in create_request["properties"]
    assert "type" not in create_request["properties"]
    assert set(create_request["properties"]["care_type"]["enum"]) == {
        "REPOTTING",
        "FERTILIZING",
    }
    assert schemas["CalendarItemType"]["enum"] == [
        "WATERING",
        "REPOTTING",
        "FERTILIZING",
    ]
    assert "DailyMemoUpsertRequest" not in schemas


def test_home_openapi_uses_room_and_unread_letter_contract() -> None:
    schemas = create_app().openapi()["components"]["schemas"]
    properties = schemas["HomeResponse"]["properties"]
    assert set(properties) == {
        "plant",
        "room",
        "today_events",
        "unread_letter_count",
        "unread_notification_count",
    }
    assert "character" not in properties
    assert "device_connection_required" not in properties
    assert schemas["HomeBackgroundPhase"]["enum"] == ["DAY", "NIGHT"]


def test_plant_update_openapi_accepts_personality() -> None:
    schemas = create_app().openapi()["components"]["schemas"]
    properties = schemas["PlantUpdateRequest"]["properties"]
    assert set(properties) == {"nickname", "place_name", "personality_type"}


def test_plant_hair_openapi_exposes_the_nine_supported_designs() -> None:
    schemas = create_app().openapi()["components"]["schemas"]
    assert schemas["HairType"]["enum"] == [
        "hair_sunflower",
        "hair_cherry_tomato",
        "hair_hydrangea",
        "hair_pointed_succulent",
        "hair_monstera",
        "hair_flower_cactus",
        "hair_rosette_succulent",
        "hair_sprout",
        "hair_daisy",
    ]


def test_plant_body_openapi_exposes_the_three_supported_designs() -> None:
    schemas = create_app().openapi()["components"]["schemas"]
    assert schemas["BodyType"]["enum"] == [
        "body_circle",
        "body_thumb",
        "body_square",
    ]


def test_plant_color_openapi_exposes_the_ten_supported_colors() -> None:
    schemas = create_app().openapi()["components"]["schemas"]
    assert schemas["ColorType"]["enum"] == [
        "color_red",
        "color_orange",
        "color_yellow",
        "color_light_green",
        "color_green",
        "color_sky",
        "color_blue",
        "color_purple",
        "color_pink",
        "color_white",
    ]


def test_plant_appearance_registration_and_update_http_contract(monkeypatch) -> None:
    user_id = uuid4()
    plant_id = uuid4()
    registration = SimpleNamespace(
        create_plant=AsyncMock(
            return_value=PlantCreateResponse(id=plant_id, created_at=datetime.now(UTC))
        )
    )
    management = SimpleNamespace(
        update_appearance=AsyncMock(
            return_value=PlantDetailResponse(
                id=plant_id,
                nickname="새싹이",
                species_reference_id="catalog:ocimum-basilicum",
                species_display_name="바질",
                category="HERB",
                scientific_name="Ocimum basilicum",
                family_name=None,
                flowering_period=None,
                primary_photo_url=None,
                started_on=date(2026, 3, 1),
                place_name="학교",
                personality_type="OUTGOING",
                body_id="body_square",
                color_id="color_blue",
                hair_id="hair_sprout",
                created_at=datetime.now(UTC),
                updated_at=datetime.now(UTC),
            )
        )
    )
    monkeypatch.setattr(plants_api, "build_service", lambda _session: registration)
    monkeypatch.setattr(
        plants_api,
        "build_management_service",
        lambda _session, _storage: management,
    )

    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=user_id, email=None, role=None, claims={}
    )
    app.dependency_overrides[get_database_session] = lambda: object()
    app.dependency_overrides[get_storage_gateway] = lambda: object()
    client = TestClient(app)

    create_payload = {
        "client_registration_id": str(uuid4()),
        "nickname": "새싹이",
        "species_reference_id": "catalog:ocimum-basilicum",
        "species_selection_method": "SEARCH",
        "species_identification_id": None,
        "primary_media_file_id": None,
        "started_on": "2026-03-01",
        "place_name": "학교",
        "last_watered_on": "2026-07-30",
        "last_repotted_on": None,
        "personality_type": "OUTGOING",
        "body_id": "body_thumb",
        "color_id": "color_green",
        "hair_id": "hair_sprout",
    }
    created = client.post("/api/v1/plants", json=create_payload)
    assert created.status_code == 201
    assert registration.create_plant.await_args.args[1].body_id.value == "body_thumb"

    updated = client.patch(
        f"/api/v1/plants/{plant_id}/appearance",
        json={"body_id": "body_square", "color_id": "color_blue"},
    )
    assert updated.status_code == 200
    assert updated.json()["body_id"] == "body_square"
    assert management.update_appearance.await_args.args[2].body_id.value == "body_square"
    assert management.update_appearance.await_args.args[2].color_id.value == "color_blue"

    invalid = client.patch(
        f"/api/v1/plants/{plant_id}/appearance",
        json={"body_id": "body_unknown"},
    )
    assert invalid.status_code == 422

    invalid_color = client.patch(
        f"/api/v1/plants/{plant_id}/appearance",
        json={"color_id": "color_unknown"},
    )
    assert invalid_color.status_code == 422
    assert management.update_appearance.await_count == 1


PROTECTED_REQUESTS: list[tuple[str, str, dict[str, object] | None, dict[str, object] | None]] = [
    ("GET", "/api/v1/letters", None, None),
    ("GET", "/api/v1/letters/unread-count", None, None),
    ("GET", f"/api/v1/letters/{uuid4()}", None, None),
    ("POST", f"/api/v1/letters/{uuid4()}/read", None, None),
    ("DELETE", f"/api/v1/letters/{uuid4()}", None, None),
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
    ("GET", "/api/v1/notifications", None, None),
    ("POST", f"/api/v1/notifications/{uuid4()}/read", None, None),
    ("POST", "/api/v1/notifications/read-all", None, None),
    ("POST", "/api/v1/devices", {"platform": "IOS", "installation_id": "fid"}, None),
    ("DELETE", f"/api/v1/devices/{uuid4()}", None, None),
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
            "last_watered_on": "2026-07-30",
            "last_repotted_on": None,
            "personality_type": "OUTGOING",
            "body_id": "body_circle",
            "color_id": "color_green",
            "hair_id": "hair_sprout",
        },
        None,
    ),
    ("GET", "/api/v1/plants", None, None),
    ("GET", f"/api/v1/plants/{uuid4()}", None, None),
    ("PATCH", f"/api/v1/plants/{uuid4()}", {"nickname": "새싹이"}, None),
    (
        "PATCH",
        f"/api/v1/plants/{uuid4()}/appearance",
        {"color_id": "color_green"},
        None,
    ),
    ("DELETE", f"/api/v1/plants/{uuid4()}", None, None),
    ("GET", f"/api/v1/plants/{uuid4()}/agenda", None, {"scope": "active"}),
    (
        "GET",
        f"/api/v1/plants/{uuid4()}/calendar",
        None,
        {"from": "2026-08-01", "to": "2026-08-31", "types": "WATERING,REPOTTING"},
    ),
    ("GET", "/api/v1/home", None, None),
    ("GET", f"/api/v1/plants/{uuid4()}/diaries", None, {"year": 2026, "month": 8}),
    (
        "PUT",
        f"/api/v1/plants/{uuid4()}/diaries/2026-08-01",
        {"weather": "SUNNY", "title": "새잎이 난 날", "content": "오늘의 기록"},
        None,
    ),
    ("GET", f"/api/v1/plants/{uuid4()}/diaries/2026-08-01", None, None),
    ("DELETE", f"/api/v1/plants/{uuid4()}/diaries/2026-08-01", None, None),
    (
        "POST",
        f"/api/v1/plants/{uuid4()}/care-events",
        {
            "client_event_id": str(uuid4()),
            "care_type": "FERTILIZING",
            "due_date": "2026-08-02",
        },
        None,
    ),
    ("POST", f"/api/v1/care-events/{uuid4()}/complete", {}, None),
    (
        "POST",
        f"/api/v1/plants/{uuid4()}/diagnoses",
        {"media_file_id": str(uuid4())},
        None,
    ),
    ("GET", f"/api/v1/plants/{uuid4()}/diagnoses", None, None),
    ("GET", f"/api/v1/diagnoses/{uuid4()}", None, None),
    ("POST", f"/api/v1/diagnoses/{uuid4()}/retry", None, None),
    ("POST", f"/api/v1/diagnoses/{uuid4()}/cancel", None, None),
]

EXPECTED_API_OPERATIONS = {
    ("GET", "/api/v1/letters"),
    ("GET", "/api/v1/letters/unread-count"),
    ("GET", "/api/v1/letters/{letter_id}"),
    ("POST", "/api/v1/letters/{letter_id}/read"),
    ("DELETE", "/api/v1/letters/{letter_id}"),
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
    ("GET", "/api/v1/notifications"),
    ("POST", "/api/v1/notifications/{notification_id}/read"),
    ("POST", "/api/v1/notifications/read-all"),
    ("POST", "/api/v1/devices"),
    ("DELETE", "/api/v1/devices/{device_id}"),
    ("GET", "/api/v1/species"),
    ("POST", "/api/v1/species/identifications"),
    ("GET", "/api/v1/species/identifications/{identification_id}"),
    ("POST", "/api/v1/plants"),
    ("GET", "/api/v1/plants"),
    ("GET", "/api/v1/plants/{plant_id}"),
    ("PATCH", "/api/v1/plants/{plant_id}"),
    ("PATCH", "/api/v1/plants/{plant_id}/appearance"),
    ("DELETE", "/api/v1/plants/{plant_id}"),
    ("GET", "/api/v1/plants/{plant_id}/agenda"),
    ("GET", "/api/v1/plants/{plant_id}/calendar"),
    ("GET", "/api/v1/home"),
    ("GET", "/api/v1/plants/{plant_id}/diaries"),
    ("PUT", "/api/v1/plants/{plant_id}/diaries/{date}"),
    ("GET", "/api/v1/plants/{plant_id}/diaries/{date}"),
    ("DELETE", "/api/v1/plants/{plant_id}/diaries/{date}"),
    ("POST", "/api/v1/plants/{plant_id}/care-events"),
    ("POST", "/api/v1/care-events/{event_id}/complete"),
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

    async def unexpected_database_access():
        raise AssertionError("Missing authentication must be rejected before database access")

    application.dependency_overrides[get_database_session] = unexpected_database_access

    with TestClient(application) as client:
        response = client.request(method, path, json=body, params=params)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert response.headers["X-Request-ID"].startswith("req_")
