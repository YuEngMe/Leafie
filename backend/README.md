# Backend

FastAPI API와 Supabase Queue를 소비하는 Python Worker가 같은 애플리케이션 코드를
공유합니다.

Worker는 식물명칭 사진 인식, 상태 진단, 채팅 이미지 처리, 앱 푸시 발송과 월간
Batch 작업을 처리합니다. 식물별 영구 채팅방과 대화 세션, 관리 자동화 규칙은
FastAPI 서비스 계층에서 소유권과 상태 전이를 검증합니다.

## 로컬 실행

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env
uvicorn app.main:app --reload
```

Supabase 프로젝트 URL, JWKS URL과 JWT issuer는 `.env`에 설정합니다. DB 작업을
시작할 때 팀에서 공유한 비밀번호로 `DATABASE_URL`을 추가합니다. 실제 secret은
저장소에 커밋하지 않습니다.

상태 확인:

```bash
curl http://127.0.0.1:8000/api/v1/health
curl http://127.0.0.1:8000/api/v1/ready
```

`health`는 프로세스 생존 여부를, `ready`는 DB 연결 가능 여부를 확인합니다.

## Migration

```bash
alembic revision --autogenerate -m "변경 내용"
alembic upgrade head
```

Migration 파일은 기능 PR에 포함하고 다른 백엔드 담당자의 리뷰를 받습니다.

## 테스트

```bash
pytest
ruff check .
```

환경변수는 `.env.example`을 기준으로 개인 `.env`에 설정하고 저장소에
커밋하지 않습니다.
