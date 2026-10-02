# Backend

현재 실행 설정은 `.env.example`과 코드를 기준으로 확인합니다.

FastAPI API와 Supabase Queue를 소비하는 Python Worker가 같은 애플리케이션 코드를
공유합니다.

Worker는 식물명칭 사진 인식, 상태 진단, 다이어리 기반 편지 생성, 앱 푸시와
파일·계정 삭제를 처리합니다. 관리 자동화와 편지 상태 전이는 FastAPI 서비스 계층과
Worker가 소유권, 멱등성과 원자적 전환을 함께 검증합니다. AI 채팅과 Tool Calling은
제품 범위에 포함하지 않습니다.

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

식물 상태 진단에는 Kindwise plant.id의 `KINDWISE_API_KEY`가 필요합니다. 앱에서
업로드한 사진은 Worker가 로컬에서 해상도·밝기·선명도를 먼저 검사한 뒤
`health_assessment` API에 한 번 전송합니다. 진단은 비동기로 처리되며 실패한 외부
요청은 Queue 정책에 따라 재시도합니다.

다이어리 기반 편지 생성에는 `OPENAI_API_KEY`가 필요합니다. 다이어리 최초 생성 시
공개 시각을 5~15분 뒤로 한 번 예약하고, 생성은 커밋 직후 시작합니다.
생성 시작 시 읽은 다이어리, 식물, 성격과 날짜별 센서 요약 스냅샷으로 한 통을 생성합니다.
완료 본문은 예약 시각까지 숨기며 지연 시 완료 후 공개합니다. 모델과 응답
한도는 `OPENAI_LETTER_MODEL`, `OPENAI_LETTER_MAX_OUTPUT_TOKENS`로 조정합니다. 실제
키는 `.env`에만 넣고 커밋하지 않습니다.

Provider, 편지 DB·예약 함수·다이어리 저장 연결, 생성/공개 Worker, 우편함 API와 도착
알림을 구현했습니다. 실제 센서 요약(#52)은 아직 연결하지 않았으므로
`LETTER_GENERATION_ENABLED=false`가 기본값입니다. 센서 어댑터 주입과 Worker 배포를
마친 뒤에만 `true`로 전환합니다. 센서 미설정 작업은 유료 호출 전에 실패합니다.
역할별 연결 방법과 배포 순서는 [편지 연동 가이드](../docs/letter-integration.md)를 따릅니다.
`LetterInput.sensor_summary`는 내부 입력 문자열이며 센서 API/필드 계약이 아닙니다.
센서 원시값을 계산하거나 운영용 가짜 값을 만들지 않습니다.
`OPENAI_LETTER_MODEL` 기본값은 `gpt-6-luna`, 출력 한도는 1200토큰입니다.
Responses API의 추론 강도는 `low`를 사용합니다.
성격은 기존 6개 enum을 사용합니다. 실제 OpenAI Provider 호출과 토큰 기록은 검증했으며,
성격별 어조 품질과 센서를 포함한 전체 흐름은 출시 전 별도로 검수합니다.

### 실제 개발 환경 통합 점검

API와 Worker를 같은 최신 코드로 실행한 뒤, backend 디렉터리에서 실행합니다.

```bash
python -m tools.smoke_live --allow-shared-dev
```

`APP_ENV=local`과 로컬 API만 허용합니다. `.env`의 실제 Supabase에 임시 계정 2개를
만들어 JWT·Storage·등록·다이어리·홈·Queue/Worker 삭제를 확인하고 정리합니다.
기존 계정·센서 데이터는 수정하지 않습니다. 기본 실행은 유료 AI를 호출하지 않습니다.
진단·종인식까지 확인하려면 식물 사진과 별도 유료 호출 동의를 지정합니다.

```bash
python -m tools.smoke_live --allow-shared-dev --photo /absolute/path/plant.jpg --allow-paid
```

편지 자동 생성은 센서 요약 연동 전까지 비활성 상태를 유지합니다. 이 도구는 센서,
FCM/APNs 또는 실제 편지 도착 흐름을 검증했다고 표시하지 않습니다.

앱 푸시는 Firebase Cloud Messaging HTTP v1을 사용합니다. Worker는 Application Default
Credentials를 우선 사용합니다. 비-GCP 환경에서는 Firebase 서비스 계정 JSON 전체를
한 줄로 만든 `FCM_CREDENTIALS_JSON`과 `FIREBASE_PROJECT_ID`를 설정합니다. iOS 전달을
위해 Firebase의 Apple 앱 설정에 APNs 인증 키도 등록해야 합니다. 서비스 계정 JSON과
APNs `.p8` 파일은 저장소에 커밋하지 않습니다.
앱은 Firebase Installations의 FID를 `/api/v1/devices`에 등록합니다.

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

애플리케이션 스키마·RLS·시드·Cron의 단일 기준은 `alembic/versions/` 입니다.
`supabase/migrations/`에 동일 스키마 SQL을 중복 관리하지 않습니다.

```bash
alembic heads
test "$(alembic heads | wc -l | tr -d ' ')" = "1"
alembic revision --autogenerate -m "변경 내용"
alembic upgrade head
```

Migration 파일은 기능 PR에 포함하고 다른 백엔드 담당자의 리뷰를 받습니다.
merge 전 단일 head인지 확인하고, 공유 DB에는 `upgrade head` 적용 여부를
PR에 적습니다.

## 테스트

```bash
pytest
ruff check .
```

환경변수는 `.env.example`을 기준으로 개인 `.env`에 설정하고 저장소에
커밋하지 않습니다.
