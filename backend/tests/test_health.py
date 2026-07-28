from fastapi.testclient import TestClient

from app.core.config import Settings
from app.db.session import Database
from app.main import app


def test_health_check() -> None:
    with TestClient(app) as client:
        response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert response.headers["X-Request-ID"].startswith("req_")


def test_readiness_fails_without_database_configuration() -> None:
    with TestClient(app) as client:
        app.state.database = Database(Settings(_env_file=None, database_url=None))
        response = client.get("/api/v1/ready")

    assert response.status_code == 503
    assert response.json() == {"status": "not_ready"}
