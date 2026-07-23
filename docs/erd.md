# ERD 및 데이터 정책

## 1. ERD

Supabase의 `auth.users`, Storage, Queues 내부 테이블은 Supabase가 관리합니다.
아래 ERD에는 애플리케이션이 직접 소유하는 업무 테이블과 필요한 참조만 표시합니다.

```mermaid
erDiagram
    AUTH_USERS ||--|| USER_PROFILES : extends
    AUTH_USERS ||--o{ MEDIA_FILES : uploads
    AUTH_USERS ||--o{ SPECIES_IDENTIFICATIONS : requests
    AUTH_USERS ||--o{ PLANTS : owns
    AUTH_USERS ||--o{ AI_CHATS : owns
    AUTH_USERS ||--o{ AI_ACTIONS : approves
    AUTH_USERS ||--o{ NOTIFICATIONS : receives
    AUTH_USERS ||--|| NOTIFICATION_SETTINGS : configures
    AUTH_USERS ||--o{ DEVICE_TOKENS : registers

    MEDIA_FILES ||--o{ USER_PROFILES : profile_image
    MEDIA_FILES ||--o{ PLANTS : profile_image
    MEDIA_FILES ||--o{ SPECIES_IDENTIFICATIONS : identification_image
    MEDIA_FILES ||--o{ PLANT_DIARIES : diary_image
    MEDIA_FILES ||--o{ DIAGNOSIS_IMAGES : diagnosis_image
    MEDIA_FILES ||--o{ AI_MESSAGES : chat_attachment

    PLANTS ||--|| PLANT_CHARACTERS : has
    PLANTS ||--|| PLANT_ENVIRONMENTS : has
    PLANTS ||--o{ PLANT_DIARIES : has
    PLANTS ||--o{ CARE_SCHEDULES : configures
    PLANTS ||--o{ CARE_EVENTS : records
    PLANTS ||--o{ DIAGNOSES : receives
    PLANTS ||--o{ AI_CHATS : tagged_in
    PLANTS ||--o{ AI_ACTIONS : affected_by
    PLANTS ||--o{ AI_BATCH_ITEMS : batched_for
    PLANTS ||--o{ MONTHLY_REPORTS : summarized_by
    PLANTS ||--o{ NOTIFICATIONS : concerns

    SPECIES_IDENTIFICATIONS o|--o| PLANTS : selected_for

    CARE_SCHEDULES o|--o{ CARE_EVENTS : generates
    DIAGNOSES o|--o{ CARE_EVENTS : recommends
    DIAGNOSES ||--|| DIAGNOSIS_IMAGES : analyzes
    DIAGNOSES ||--o{ AI_MESSAGES : referenced_by

    AI_CHATS ||--o{ AI_MESSAGES : contains
    AI_MESSAGES ||--o{ AI_TOOL_CALLS : invokes
    AI_MESSAGES ||--o{ AI_ACTIONS : proposes

    AI_BATCH_JOBS ||--o{ AI_BATCH_ITEMS : contains
    AI_BATCH_ITEMS o|--o| MONTHLY_REPORTS : produces

    AUTH_USERS {
        uuid id PK
        varchar email UK
        timestamptz email_confirmed_at
        timestamptz created_at
    }

    USER_PROFILES {
        uuid user_id PK,FK
        uuid profile_media_file_id FK
        varchar nickname
        text bio
        varchar timezone
        uuid selected_plant_id FK
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }

    MEDIA_FILES {
        uuid id PK
        uuid user_id FK
        varchar purpose
        varchar status
        varchar bucket_name
        varchar object_path UK
        varchar content_type
        bigint size_bytes
        varchar checksum_sha256
        int width
        int height
        timestamptz created_at
        timestamptz deleted_at
    }

    SPECIES_IDENTIFICATIONS {
        uuid id PK
        uuid user_id FK
        uuid media_file_id FK
        varchar status
        varchar provider
        jsonb candidates
        varchar failure_code
        timestamptz created_at
        timestamptz completed_at
    }

    PLANTS {
        uuid id PK
        uuid user_id FK
        uuid primary_media_file_id FK
        uuid species_identification_id FK
        varchar name
        varchar category
        varchar species_name
        varchar species_scientific_name
        varchar species_reference_id
        varchar species_selection_method
        date started_on
        text memo
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }

    PLANT_CHARACTERS {
        uuid plant_id PK,FK
        varchar base_type
        varchar body_color
        varchar head_item
        varchar accessory
        varchar personality_type
        timestamptz updated_at
    }

    PLANT_ENVIRONMENTS {
        uuid plant_id PK,FK
        varchar place_name
        varchar pot_type
        varchar placement
        timestamptz updated_at
    }

    PLANT_DIARIES {
        uuid id PK
        uuid plant_id FK
        uuid media_file_id FK
        date diary_date
        text content
        varchar condition_level
        int condition_score
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }

    CARE_SCHEDULES {
        uuid id PK
        uuid plant_id FK
        varchar type
        int interval_days
        date next_due_date
        boolean enabled
        timestamptz created_at
        timestamptz updated_at
    }

    CARE_EVENTS {
        uuid id PK
        uuid plant_id FK
        uuid schedule_id FK
        uuid source_diagnosis_id FK
        varchar type
        varchar status
        timestamptz scheduled_at
        timestamptz completed_at
        text note
        timestamptz created_at
        timestamptz updated_at
    }

    DIAGNOSES {
        uuid id PK
        uuid plant_id FK
        varchar status
        varchar overall_condition
        date symptom_started_on
        jsonb environment
        text user_note
        text summary
        jsonb observations
        jsonb possible_causes
        jsonb recommendations
        numeric confidence
        boolean needs_retake
        varchar failure_code
        varchar provider
        varchar model_name
        varchar prompt_version
        varchar provider_response_id
        timestamptz created_at
        timestamptz started_at
        timestamptz completed_at
        timestamptz deleted_at
    }

    DIAGNOSIS_IMAGES {
        uuid diagnosis_id PK,FK
        uuid media_file_id FK
    }

    AI_CHATS {
        uuid id PK
        uuid user_id FK
        uuid plant_id FK
        varchar title
        varchar provider_conversation_id
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }

    AI_MESSAGES {
        uuid id PK
        uuid chat_id FK
        uuid related_diagnosis_id FK
        uuid media_file_id FK
        varchar role
        varchar status
        text content
        varchar provider
        varchar model_name
        varchar provider_response_id
        int input_tokens
        int output_tokens
        timestamptz created_at
    }

    AI_TOOL_CALLS {
        uuid id PK
        uuid message_id FK
        varchar provider_call_id UK
        varchar tool_name
        jsonb arguments
        jsonb result_summary
        varchar status
        int latency_ms
        varchar error_code
        timestamptz created_at
        timestamptz completed_at
    }

    AI_ACTIONS {
        uuid id PK
        uuid user_id FK
        uuid message_id FK
        uuid plant_id FK
        varchar action_type
        jsonb payload
        varchar status
        int version
        timestamptz expires_at
        timestamptz confirmed_at
        timestamptz executed_at
        timestamptz created_at
    }

    AI_BATCH_JOBS {
        uuid id PK
        varchar job_type
        varchar provider_batch_id UK
        varchar status
        varchar input_file_id
        varchar output_file_id
        int total_count
        int completed_count
        int failed_count
        varchar error_code
        timestamptz submitted_at
        timestamptz completed_at
        timestamptz created_at
    }

    AI_BATCH_ITEMS {
        uuid id PK
        uuid batch_job_id FK
        varchar custom_id UK
        uuid plant_id FK
        int target_year
        int target_month
        varchar status
        jsonb result
        varchar error_code
        timestamptz created_at
        timestamptz completed_at
    }

    MONTHLY_REPORTS {
        uuid id PK
        uuid plant_id FK
        uuid batch_item_id FK
        int report_year
        int report_month
        varchar status
        numeric average_condition_score
        text condition_summary
        text care_summary
        jsonb frequent_issues
        jsonb next_month_recommendations
        varchar model_name
        varchar prompt_version
        timestamptz generated_at
        timestamptz created_at
        timestamptz updated_at
    }

    NOTIFICATIONS {
        uuid id PK
        uuid user_id FK
        uuid plant_id FK
        varchar type
        varchar title
        text body
        varchar source_type
        uuid source_id
        timestamptz read_at
        timestamptz created_at
    }

    NOTIFICATION_SETTINGS {
        uuid user_id PK,FK
        boolean care_reminder_enabled
        boolean diagnosis_complete_enabled
        boolean monthly_report_enabled
        time quiet_hours_start
        time quiet_hours_end
        timestamptz updated_at
    }

    DEVICE_TOKENS {
        uuid id PK
        uuid user_id FK
        varchar platform
        varchar token UK
        timestamptz last_used_at
        timestamptz created_at
        timestamptz revoked_at
    }
```

## 2. 핵심 관계

- `AUTH_USERS`는 Supabase `auth.users`를 나타내며 비밀번호와 세션은 Supabase가 관리합니다.
- `USER_PROFILES.user_id`는 `auth.users.id`와 동일한 1:1 키입니다.
- 사용자는 여러 식물을 소유하고 그중 하나를 현재 캐릭터 방으로 선택합니다.
- 컨디션은 다이어리에 포함되며 홈에서는 오늘 다이어리의 값을 읽기 전용으로 표시합니다.
- 다이어리는 사진을 최대 한 장, 진단은 정확히 한 장 사용합니다.
- 식물명칭은 검색 또는 사진 인식 후보에서 선택하며 사진 인식 결과는 사용자가 확정합니다.
- 자동 반복 일정은 물주기와 분갈이만 지원합니다.
- AI 대화방 하나는 정확히 한 식물에 고정됩니다.
- 읽기 Tool Call은 서버가 실행하고 변경 제안은 `AI_ACTIONS`에서 사용자 승인을 기다립니다.
- OpenAI Batch 하나는 여러 항목을 포함하고 각 항목은 최대 하나의 월간 리포트를 생성합니다.
- Supabase Queues 메시지는 업무 테이블 ID만 운반하며 업무 데이터의 원본은 아닙니다.

## 3. 제약조건

| 테이블 | 제약조건 |
|---|---|
| `user_profiles` | `user_id`는 Supabase `auth.users.id`, `selected_plant_id`는 본인 소유 식물 |
| `species_identifications` | 사진 한 장, 상태 전이 검증, 완료 후보의 표시명·학명·참조 ID·신뢰도 저장 |
| `plants` | `category`는 확정된 7개 Enum, `name`, `species_name`, `species_reference_id`, `species_selection_method` 필수 |
| `plant_characters` | `personality_type`은 확정된 6개 Enum |
| `plant_diaries` | `(plant_id, diary_date)` unique, 글과 컨디션 필수, 사진은 null 또는 한 장 |
| `care_schedules` | `type`은 `WATERING` 또는 `REPOTTING`, `(plant_id, type)` unique |
| `care_events` | 완료 시각은 완료 API의 서버 현재 시각이며 사용자 수정 불가 |
| `diagnosis_images` | 진단당 정확히 한 장 |
| `diagnoses` | `confidence`는 0~1 또는 null |
| `ai_chats` | `plant_id` 필수, 생성 후 변경 불가 |
| `ai_messages` | 첨부 사진은 null 또는 한 장 |
| `ai_actions` | `PENDING_CONFIRMATION`만 confirm/cancel 가능, 만료 후 실행 불가 |
| `ai_batch_items` | `custom_id` unique |
| `monthly_reports` | `(plant_id, report_year, report_month)` unique |
| `device_tokens` | 활성 token unique |

Tool 인자는 Pydantic schema로 검증합니다. `AI_TOOL_CALLS.arguments`와
`AI_ACTIONS.payload`에는 비밀값, 원본 이미지, 다른 사용자의 식별자를 저장하지
않습니다.

## 4. 인덱스

```text
user_profiles(selected_plant_id)
plants(user_id, deleted_at)
plant_diaries(plant_id, diary_date DESC)
care_schedules(plant_id, type)
care_schedules(enabled, next_due_date)
care_events(plant_id, scheduled_at)
care_events(status, scheduled_at)
diagnoses(plant_id, created_at DESC)
diagnoses(status, created_at)
ai_chats(user_id, updated_at DESC)
ai_chats(plant_id, updated_at DESC)
ai_messages(chat_id, created_at)
ai_tool_calls(message_id, created_at)
ai_actions(user_id, status, expires_at)
ai_batch_jobs(status, created_at)
ai_batch_items(batch_job_id, status)
monthly_reports(plant_id, report_year DESC, report_month DESC)
notifications(user_id, read_at, created_at DESC)
media_files(user_id, status, created_at)
device_tokens(user_id, revoked_at)
```

## 5. Supabase 보안

- Flutter 앱에는 publishable key만 포함합니다.
- `service_role` 키는 FastAPI와 Worker에서만 사용합니다.
- Supabase Storage 버킷은 비공개로 유지합니다.
- 앱은 업무 테이블을 직접 수정하지 않고 FastAPI를 호출합니다.
- Data API가 활성화된 업무 테이블에는 RLS를 적용해 본인 행만 접근하도록 방어합니다.
- Queue schema는 Flutter에 노출하지 않고 FastAPI, Worker, Cron만 접근합니다.
- FastAPI는 Supabase JWT 검증 후 모든 리소스의 소유권을 다시 검사합니다.

## 6. 삭제 정책

- 화면의 삭제는 우선 `deleted_at`을 기록하는 soft delete로 처리합니다.
- 계정 탈퇴 시 FastAPI가 세션의 최근 인증 여부를 확인하고 삭제 작업을 Queue에 넣습니다.
- Worker가 Supabase Storage 객체와 업무 데이터를 제거한 뒤 Auth Admin API로 사용자를 삭제합니다.
- AI 품질 개선에 사용자 사진이나 대화를 재사용하려면 별도의 명시적 동의와 철회 경로가 필요합니다.
- Tool Call 감사 로그는 개인정보를 제거한 최소 정보만 제한된 기간 동안 보관합니다.

## 7. 파생 데이터

- `days_together`: `plants.started_on`과 사용자 시간대의 오늘 날짜 차이
- `gardener_days`: Supabase `auth.users.created_at`과 오늘 날짜 차이
- `current_condition`: 오늘 다이어리의 컨디션, 없으면 `null`
- `care_event_counts`: 조회 기간 내 완료 이벤트 집계
- `monthly_condition.average_score`: 해당 월 다이어리 컨디션 평균
- `monthly_condition.level`: 평균을 5개 아이콘 구간으로 변환

컨디션은 `VERY_BAD=10`, `BAD=30`, `NORMAL=50`, `GOOD=70`,
`VERY_GOOD=90`으로 저장합니다. 기록이 없는 달은 평균을 0으로 만들지 않고
`null`로 반환합니다.
