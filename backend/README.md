# Backend

FastAPI API와 Supabase Queue를 소비하는 Python Worker가 같은 애플리케이션 코드를
공유합니다.

## 로컬 실행

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --reload
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

## 테스트

```bash
pytest
ruff check .
```

환경변수는 `.env.example`을 기준으로 개인 `.env`에 설정하고 저장소에
커밋하지 않습니다.
