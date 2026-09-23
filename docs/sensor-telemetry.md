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

| 테이블 | 설명 |
|---|---|
| `sensor_devices` | `device_id`(MAC 기반 12자리 대문자 hex, PK), `user_id`, `plant_id`(null 가능). 식물 하나에 기기 하나 |
| `sensor_readings` | 측정값. `device_id` FK, `sqs_message_id`(UNIQUE), `measured_at`, `received_at`, `lux`, `soil_raw` |

- `received_at`은 저장 시각이 아니라 SQS `SentTimestamp`(API Gateway 수신 시각)다. 큐가 밀려도
  수신 순서를 판단할 수 있다.
- `measured_at`은 null일 수 있으므로 시각 기준 조회는 `COALESCE(measured_at, received_at)`를 쓴다.
- 표준 SQS는 같은 메시지를 두 번 줄 수 있어 `sqs_message_id`로 중복 저장을 막는다.
- 등록되지 않은 `deviceId`는 FK 위반으로 저장되지 않고 DLQ로 간다.
- 두 테이블 모두 RLS를 켜고 `anon`, `authenticated` 권한을 회수한다.

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
5. 기기(또는 `sensor_devices` 테스트 행)를 만들고 telemetry가 저장되는지 확인한다.

## 이 문서가 정하지 않는 것

- claim API, `deviceToken` 발급·저장, 기기별 인증(Lambda Authorizer)
- 일별 누적 조도, 물 요구, 급수 판정, 편지 요약 어댑터(`LetterSensorSummary`)
- 홈 표정과 센서 알림
