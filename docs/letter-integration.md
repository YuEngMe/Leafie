# 편지 백엔드 연동 가이드

## 구현 상태

- 구현: `letters` 모델·migration, 트랜잭션 예약 함수, 생성·공개 Worker,
  OpenAI Provider, 우편함 5개 API, 편지 도착 알림·기존 FCM 연결.
- 미연결: #42 다이어리 최초 저장의 예약 함수 호출과 제목·날씨 최종 매핑,
  #52 실제 날짜별 센서 요약 조회. 현재 앱에서 다이어리를 저장해도 편지가 자동 생성되지는 않습니다.
- `UnconfiguredLetterSensorSummary`는 가짜 값을 반환하지 않습니다. 실수로 생성 작업이
  들어오면 유료 LLM 호출 전에 `LETTER_SENSOR_NOT_CONFIGURED`로 실패합니다.
- #49 채팅·Tool Calling 제거는 등록/진단 의존 경로 정리가 끝난 뒤 별도 PR에서 수행합니다.

## YuEngMe: 다이어리 저장 연결 (#42 → #45)

같은 `AsyncSession` 트랜잭션에서 다음 순서를 지켜 주세요.

1. 사용자 프로필 → 식물 순서로 잠그고 삭제 중이 아닌 소유 식물인지 확인합니다.
   `lock_active_plant(session, user_id, plant_id)`를 재사용할 수 있습니다.
2. 기존 다이어리 upsert 후 flush합니다. 새 행이 삽입된 경우만 `created=True`입니다.
3. `reserve_letter(session, queue, user_id=user_id, diary_id=diary.id, created=created)`를 호출합니다.
4. 다이어리·편지 예약·`pgmq.send`가 모두 성공한 후 기존 요청 트랜잭션을 커밋합니다.

`reserve_letter`는 스스로 commit하지 않습니다. Queue 등록 실패도 요청을 롤백해야 하며,
기존 다이어리 수정에 `created=True`를 넘기거나 별도 커밋 후 예약하면 안 됩니다.
사진 정리 등 기존 부수 작업 계약은 유지합니다. 날짜·식물별 unique는 #42에서 유지합니다.
기존 서비스가 식물을 먼저 잠그므로 연결 시 프로필 선행 잠금을 추가해 삭제 작업과
잠금 순서를 일치시켜 주세요. 센서 어댑터 준비 전에는 호출을 활성화하지 않습니다.

예약 결과는 `Letter | None`입니다. 신규 예약이면 `id`, `status`, `scheduled_at`을
다이어리 응답에 연결할 수 있습니다. 수정 호출은 `None`; 응답에 기존 편지 정보가 필요하면
별도로 조회합니다. `diary_id` unique는 편지 soft delete 후에도 유지됩니다.
전환 전 다이어리의 수정은 신규 편지를 만들지 않으며 backfill migration도 없습니다.

`LetterGenerationHandler`는 현 모델에 `title`, `weather`가 있을 때만 전달합니다.
#42의 확정 필드·날씨 코드에 맞게 이 매핑을 확인해야 합니다. 편지에서는 날씨 코드를
사용자가 이해할 한국어 요약으로 변환하여 전달하는 것을 연동 기준으로 합니다.

## jdk829355: 센서 요약 연결 (#52 → #46)

`LetterSensorSummary.read(plant_id: UUID, diary_date: date) -> str`를 구현한 어댑터를
Worker의 `UnconfiguredLetterSensorSummary()` 대신 주입합니다. 이 인터페이스는 내부
소비 경계이며 센서 테이블·필드·API 명칭을 정하는 계약이 아닙니다.

- 해당 날짜의 누적 조도와 물 요구/급수 이력을 담당자 계약에 따라 요약합니다.
- 일일 누적 조도를 순간 조도로 바꾸거나 급수 미확인을 급수 완료로 단정하지 않습니다.
- 원시 센서 연산, 센서 누락 보정, 가짜 운영 데이터 생성은 편지 Worker가 하지 않습니다.
- 문자열은 비어 있지 않은 최대 4000자입니다. 내부 입력 한도이지 센서 원시 데이터 한도가 아닙니다.
- 일시 조회 장애는 예외를 발생시켜 재시도합니다. 설정 오류는 `LetterPermanentError`로
  실패시키며 센서 데이터의 원문을 예외 메시지에 포함하지 않습니다.

## 생성·공개와 재시도

- 최초 예약 시 현재 시각 + 300~900초를 한 번 선택합니다. Queue 생성 작업은 즉시 실행합니다.
- `PENDING → PROCESSING → COMPLETED|FAILED`. 완료는 생성 완료이며 공개를 뜻하지 않습니다.
- 외부 호출 전에 입력 스냅샷을 저장합니다. 이후 API 재시도는 같은 스냅샷을 사용합니다.
  센서 조회 전에 실패한 작업은 아직 완전한 스냅샷이 없어 재조회합니다.
- 만료된 작업은 새 UUID 선점 토큰으로 회수합니다. 이전 토큰의 늦은 성공·실패 응답은 무시합니다.
  활성 lease를 만난 중복 메시지는 lease 이후 복구 작업을 예약한 뒤 종료합니다.
- 생성 한도는 `WORKER_MAX_ATTEMPTS`, 외부 호출 timeout은 OpenAI timeout + 15초입니다.
  lease는 최소 120초이며 실제 Worker 조립 시 호출 timeout보다 길게 잡습니다.
- 일시 오류는 공통 QueueWorker backoff로 재시도합니다. 영구 오류·빈 응답은 최종 실패하며
  반복 전달되어도 유료 호출을 다시 하지 않습니다.
- 생성 완료 저장과 `LETTER_PUBLISH` 등록은 같은 트랜잭션입니다. 공개 목표 시각이
  이미 지났으면 지연 없이 공개 작업을 보냅니다. 조기 실행된 공개 작업은 다시 예약합니다.
- 공개는 `published_at`·Notification·푸시 Queue를 같은 트랜잭션으로 저장합니다.
  DB/Queue 장애로 공개 트랜잭션이 실패하면 archive하지 않고 계속 재시도해 운영 확인 대상으로
  남깁니다. 생성 실패와 달리 완성된 편지를 새로 생성하지 않습니다.
- 목록·상세·읽음·삭제·미확인 개수는 공개된 본인 식물의 편지만 대상으로 합니다.
  삭제된 계정/식물/다이어리의 작업은 완료·공개하지 않습니다.

## 우편함·홈·푸시 연결 (#47 → #48)

| API | 동작 |
|---|---|
| `GET /api/v1/letters` | 전체 식물 기본, 선택 `plant_id`, `unread_only`, `cursor`, `limit` |
| `GET /api/v1/letters/unread-count` | `{"unread_count": 0}`, 선택 `plant_id` |
| `GET /api/v1/letters/{id}` | 본문 상세; 읽음 부수 효과 없음 |
| `POST /api/v1/letters/{id}/read` | 최초 `read_at` 유지, 반복 성공 |
| `DELETE /api/v1/letters/{id}` | 편지만 soft delete, 본인 삭제 편지 재요청도 204 |

타인·비공개·존재하지 않는 편지는 404입니다. 삭제 상세도 404입니다. 삭제된 다이어리/식물로
hard delete된 편지는 재삭제 시 404입니다. 읽음 해제 API는 현재 계약에 없습니다.
목록 정렬은 `(published_at DESC, id DESC)` 키셋 방식이며 cursor는 불투명 문자열입니다.
홈 내부 조립에서는 같은 세션의 `LetterService.unread_count(user_id, plant_id)`를 사용합니다.

편지 알림은 `type=LETTER_ARRIVED`, `source_type=LETTER`, `source_id=letter.id`입니다.
푸시 data에 기존 `notification_id`, `plant_id`와 `source_type`, `source_id`를 제공합니다.
도착 문구는 성격별 고정 문구이고 편지 본문은 푸시에 넣지 않습니다.
기존 `push_enabled`와 device token을 그대로 사용합니다. 편지 삭제는 해당 알림도 제거하며,
대기 중인 푸시는 발송 직전 편지 공개/소유 상태를 다시 확인합니다. 이미 전달됐거나 전송 중인
푸시는 회수할 수 없으므로 앱에서 대상 404를 처리해야 합니다. 다이어리 hard delete로
남은 과거 알림도 대상 404 처리 기준을 따릅니다.

## 배포·검증

- revision `b2f416a83d09`는 `f1a8c3e05d92` 위에 새 테이블만 추가합니다. 기존 데이터 삭제 없음.
- #53에도 migration이 있으므로 두 PR 병합 시 부모 revision을 최신 head에 맞춰 재검증합니다.
  `alembic heads`는 반드시 한 개여야 합니다. downgrade는 편지 데이터 전체를 제거합니다.
- RLS 활성화, `anon`/`authenticated` 직접 테이블 권한 제거. 조회·변경은 JWT 검증 백엔드 API로만
  제공하며 DB 역할은 기존 백엔드 역할을 사용합니다. 스냅샷/실패코드/선점 정보는 API에 미노출입니다.
- migration → 새 Worker/API 배포 → #42/#52 연결 → 신규 저장 활성화 순서입니다.
  구버전 Worker는 신규 JobType을 모르면 archive하므로 생성 활성화 전에 교체해야 합니다.
- CI PostgreSQL 17에서 실제 트랜잭션·동시성·migration을 검증합니다. 테스트 전용 큐 테이블은
  `pgmq.send`의 동일 세션 원자성을 검증하기 위한 것으로 운영 migration에는 존재하지 않습니다.
- 로컬은 별도 localhost `leafie_letter_test` DB의 URL을 `LETTER_TEST_DATABASE_URL`로 전달해
  `pytest tests/test_letter_workflow.py`를 실행합니다. 다른 DB 이름/외부 호스트는 실행 거부합니다.
- 실제 센서·OpenAI 유료 한 건 smoke test와 APNs 수신은 연결 후 별도 출시 검증입니다.
