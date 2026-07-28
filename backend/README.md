# Backend

FastAPI API와 Supabase Queue를 소비하는 Python Worker가 같은 애플리케이션 코드를
공유합니다.

Worker는 식물명칭 사진 인식, 상태 진단, 채팅 이미지 처리, 앱 푸시 발송과 월간
Batch 작업을 처리합니다. 식물별 영구 채팅방과 대화 세션, 관리 자동화 규칙은
FastAPI 서비스 계층에서 소유권과 상태 전이를 검증합니다.

Queue Worker 실행:

```bash
python -m app.worker
```

`SUPABASE_QUEUE_NAME`과 `WORKER_*` 환경변수로 Queue 이름, polling 간격,
visibility timeout, 최대 재시도와 batch 크기를 설정합니다. Worker는 종료 신호를
받으면 현재 처리 중인 작업을 마친 뒤 DB와 Storage 연결을 닫습니다.

식물 사진 인식에는 My Pl@ntNet 개발자 대시보드에서 발급한
`PLANTNET_API_KEY`가 필요합니다. 키가 없거나 유효하지 않으면 인식 작업은
`FAILED`로 종료되며 `failure_code`로 원인을 반환합니다. Pl@ntNet이 지원하는
JPEG와 PNG만 인식 입력으로 사용합니다.

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
