from fastapi import Query
from fastapi.testclient import TestClient

from app.core.errors import AppError
from app.main import create_app


def test_app_error_uses_standard_contract_and_request_id() -> None:
    application = create_app()

    @application.get("/test-error")
    async def test_error() -> None:
        raise AppError(
            code="PLANT_NOT_FOUND",
            message="식물을 찾을 수 없습니다.",
            status_code=404,
        )

    with TestClient(application) as client:
        response = client.get(
            "/test-error",
            headers={"X-Request-ID": "request_test_123"},
        )

    assert response.status_code == 404
    assert response.headers["X-Request-ID"] == "request_test_123"
    assert response.json() == {
        "error": {
            "code": "PLANT_NOT_FOUND",
            "message": "식물을 찾을 수 없습니다.",
            "details": None,
            "request_id": "request_test_123",
        }
    }


def test_validation_error_uses_standard_contract() -> None:
    application = create_app()

    @application.get("/test-validation")
    async def test_validation(limit: int = Query(ge=1, le=100)) -> dict[str, int]:
        return {"limit": limit}

    with TestClient(application) as client:
        response = client.get("/test-validation?limit=0")

    assert response.status_code == 422
    body = response.json()
    assert body["error"]["code"] == "VALIDATION_ERROR"
    assert body["error"]["request_id"].startswith("req_")
    assert body["error"]["details"]


def test_invalid_incoming_request_id_is_replaced() -> None:
    application = create_app()

    with TestClient(application) as client:
        response = client.get(
            "/api/v1/health",
            headers={"X-Request-ID": "bad\nvalue"},
        )

    assert response.status_code == 200
    assert response.headers["X-Request-ID"].startswith("req_")
