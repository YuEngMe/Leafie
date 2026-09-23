# 센서 telemetry 수신

센서 담당(#52) 문서다. 기기가 올리는 원시 측정값을 받아 DB에 저장하는 경로까지만 다룬다.
기기 등록(claim), 일별 집계, 편지·홈·알림 소비는 이 문서 범위가 아니다.

## 경로

```text
ESP32-C3 --HTTPS--> API Gateway --> SQS(표준 큐) --> Lambda(consumer) --> Supabase PostgreSQL
                                        |
                                        +--(5회 실패)--> DLQ
```

- API Gateway와 Lambda는 FastAPI와 별개로 AWS에서 운영한다. FastAPI는 이 경로를 거치지 않는다.
- 요청: `POST /devices/{device_id}/telemetry`. 이 `devices`는 푸시 수신용 `POST /devices`와
  무관한 센서 장치다.
- 인증은 `x-api-key`(모든 기기 공통 키)다. 기기별 인증은 claim API 구현 후 교체한다.

## 요청 본문

API Gateway 모델 `TelemetryRequest`(JSON Schema draft-04)가 검증한다. 세 필드 모두 필수이며
값이 없으면 필드를 빼지 않고 `null`로 보낸다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `created_at` | string \| null | 기기 측정 시각(UTC, `2026-09-24T01:30:00Z`). SNTP 동기화 전이면 `null` |
| `lux` | number \| null | BH1750 조도(0~54613). 센서 읽기 실패 시 `null` |
| `soilRaw` | integer \| null | 토양 수분 ADC raw(0~4095, 클수록 건조). 읽기 실패 시 `null` |

## SQS 메시지

API Gateway 매핑 템플릿이 경로의 `device_id`를 본문과 합쳐 큐에 넣는다. `deviceToken`과 API 키는
메시지에 넣지 않는다.

```json
{"deviceId": "D40592E7D168", "payload": {"created_at": "...", "lux": 123.4, "soilRaw": 3900}}
```

## 테이블

기기 등록(claim) 설계는 센서 펌웨어 저장소 `AGENTS.md` 10~17번을 따른다. 이 문서의 테이블은 그
설계를 반영하되, claim API 자체는 아직 구현하지 않았다.

| 테이블 | 설명 |
|---|---|
| `devices` | 센서 기기. `id`(MAC 기반 12자리 대문자 hex), `owner_user_id`, `device_token_hash`, `status`, `firmware_version`, `claimed_at`, `last_seen_at` |
| `device_claims` | 기기 claim "시도". `device_id`, `user_id`, `claim_token_hash`, `status`, `expires_at`, `completed_at` |
| `plant_devices` | 식물과 기기의 연결. 식물 하나에 기기 하나, 기기 하나에 식물 하나 |
| `sensor_readings` | 측정값. `device_id` FK, `sqs_message_id`(UNIQUE), `measured_at`, `received_at`, `lux`, `soil_raw` |

`devices`는 센서 장치이며, 푸시 수신용 앱 설치 정보인 `device_tokens`와 무관하다.

### devices

- `status`는 `UNCLAIMED` 또는 `CLAIMED`다. claim 성공 전에는 `owner_user_id`와 `device_token_hash`가
  `NULL`이고, 성공 이후에만 `owner_user_id`, `device_token_hash`, `claimed_at`이 **함께** 채워진다.
  CHECK 제약(`claimed_state`)이 이를 강제한다.
- `device_token_hash`는 SHA-256 hex(64자)이며 NULL이 아니면 유일하다.
- `last_seen_at`은 백엔드가 갱신한다. 수집 Lambda는 `devices`를 수정하지 않는다.
- 소유 사용자가 삭제되면 기기와 그 측정값도 함께 삭제된다.

### device_claims

- `status`는 `PENDING`, `COMPLETED`, `EXPIRED`, `CANCELLED`다. `completed_at`은 `COMPLETED`일 때만 채운다.
- 기기당 `PENDING` claim은 하나만 허용한다 (여러 claim credential 동시 지원 안 함).
- `device_claims.user_id`(claim을 요청한 사용자)와 `devices.owner_user_id`(현재 실제 소유자)는 의미가 다르다.

### plant_devices

- 식물이나 기기가 삭제되면 연결만 삭제된다. 식물 삭제는 기기와 측정값을 지우지 않는다.
- 식물의 `user_id`와 기기의 `owner_user_id`가 같은지는 서비스 계층에서 검증한다 (DB 제약 없음).

### sensor_readings

- `received_at`은 저장 시각이 아니라 SQS `SentTimestamp`(API Gateway 수신 시각)다. 큐가 밀려도
  수신 순서를 판단할 수 있다.
- `measured_at`은 null일 수 있으므로 시각 기준 조회는 `COALESCE(measured_at, received_at)`를 쓴다.
- 표준 SQS는 같은 메시지를 두 번 줄 수 있어 `sqs_message_id`로 중복 저장을 막는다.
- 등록되지 않은 `deviceId`는 FK 위반으로 저장되지 않고 DLQ로 간다.
- 아직 claim되지 않은 기기(`UNCLAIMED`)의 측정값은 DB가 막지 않는다. 정상 흐름에서는 기기가
  `deviceToken`을 받은 뒤에만 전송하며, 이를 강제하는 것은 기기별 인증(다음 단계)의 몫이다.

모든 센서 테이블은 RLS를 켜고 `anon`, `authenticated` 권한을 회수한다.

## consumer 전용 DB 역할

Lambda는 `sensor_ingest` 역할로만 접속한다. 이 역할은 `sensor_readings`에 **INSERT만** 할 수 있다.

- 저장 쿼리는 `ON CONFLICT DO NOTHING`(충돌 대상 없이)을 써야 한다. `ON CONFLICT (sqs_message_id)`처럼
  충돌 대상을 지정하면 PostgreSQL이 그 컬럼의 SELECT 권한을 요구해 거부된다.
- 역할은 migration이 만들지만 **비밀번호는 넣지 않는다.** 적용 후 운영자가 설정한다.

```sql
ALTER ROLE sensor_ingest PASSWORD '<새 비밀번호>';
```

접속은 직접 DB 주소(IPv6 전용)가 아니라 Supavisor 풀러 주소를 쓴다. 사용자명은
`sensor_ingest.<프로젝트 ref>` 형식이다.

## 배포 순서

1. 이 브랜치 PR을 병합하고 `alembic upgrade head`로 migration을 공유 DB에 적용한다.
2. `sensor_ingest` 비밀번호를 설정한다.
3. 접속 문자열을 SSM Parameter Store(SecureString)에 저장한다.
4. consumer Lambda를 배포한다. 2, 3번 전에 배포하면 모든 메시지가 DLQ로 이동한다.
5. 기기를 등록하고 telemetry가 저장되는지 확인한다. claim API가 구현되기 전에는 `devices`에
   `CLAIMED` 상태의 테스트 행(소유자, 64자 토큰 해시, `claimed_at`)을 직접 넣는다.

## 이 문서가 정하지 않는 것

- claim API(`POST /devices/{deviceId}/claims` 등), `deviceToken` 발급·저장, 기기별 telemetry 인증
- 일별 누적 조도, 물 요구, 급수 판정, 편지 요약 어댑터(`LetterSensorSummary`)
- 홈 표정과 센서 알림
