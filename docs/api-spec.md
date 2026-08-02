# API 명세 v1

구현 후 FastAPI `/openapi.json`이 요청·응답 schema의 최종 기준입니다. Supabase Auth
SDK가 직접 처리하는 인증 동작은 이 문서의 Auth 절을 따릅니다.

## 1. 공통 규칙

- Base path: `/api/v1`
- 인증: `Authorization: Bearer <supabase_access_token>`
- 식별자: UUID
- 날짜: `YYYY-MM-DD`
- 시각: ISO 8601 UTC
- 기본 사용자 시간대: `Asia/Seoul`
- 목록: 커서 페이지네이션, 기본 최신순
- 앱은 다른 사용자의 ID를 보내더라도 접근할 수 없음

```json
{
  "items": [],
  "next_cursor": null,
  "has_next": false
}
```

오류 형식:

```json
{
  "error": {
    "code": "PLANT_NOT_FOUND",
    "message": "식물을 찾을 수 없습니다.",
    "details": null,
    "request_id": "req_01J..."
  }
}
```

| HTTP | 주요 code |
|---:|---|
| 400 | `INVALID_REQUEST`, `FUTURE_DATE_NOT_ALLOWED` |
| 401 | `AUTH_REQUIRED`, `TOKEN_EXPIRED`, `RECENT_AUTH_REQUIRED` |
| 403 | `EMAIL_NOT_VERIFIED`, `RESOURCE_FORBIDDEN` |
| 404 | `*_NOT_FOUND` |
| 409 | `INVALID_STATE_TRANSITION`, `ACCOUNT_DELETION_PENDING`, `PLANT_REGISTRATION_ID_REUSED` |
| 413 | `FILE_TOO_LARGE` |
| 415 | `UNSUPPORTED_MEDIA_TYPE` |
| 422 | `VALIDATION_ERROR` |
| 429 | `RATE_LIMITED` |
| 503 | `DEPENDENCY_UNAVAILABLE` |

## 2. Enum

| 이름 | 값 |
|---|---|
| `SpeciesSelectionMethod` | `SEARCH`, `PHOTO` |
| `PlantCategory` | `FOLIAGE`, `FLOWER`, `SUCCULENT_CACTUS`, `TREE`, `HERB`, `FRUIT`, `VINE` |
| `PotType` | `TERRACOTTA`, `PLASTIC`, `GLASS`, `CERAMIC`, `HYDROPONIC`, `OTHER` |
| `Placement` | `VERANDA`, `WINDOW`, `LIVING_ROOM`, `BEDROOM`, `DESK`, `OTHER` |
| `PersonalityType` | `OUTGOING`, `CHIC`, `CUTE`, `CRUSH`, `INTROVERTED`, `CHUNGCHEONG` |
| `RepottingHistoryStatus` | `KNOWN`, `NEVER`, `UNKNOWN` |
| `CareType` | `WATERING`, `REPOTTING`, `FERTILIZING`, `PRUNING`, `CUSTOM` |
| `CareStoredStatus` | `SCHEDULED`, `COMPLETED`, `CANCELLED` |
| `CareViewStatus` | `UPCOMING`, `TODAY`, `OVERDUE`, `COMPLETED`, `CANCELLED` |
| `CareSource` | `AUTO_SCHEDULE`, `USER_CREATED`, `AI_RECOMMENDED` |
| `MediaPurpose` | `PLANT_PROFILE`, `SPECIES_IDENTIFICATION`, `DIARY`, `DIAGNOSIS`, `CHAT` |
| `AsyncStatus` | `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED` |
| `DiagnosisStatus` | `PENDING`, `PROCESSING`, `COMPLETED`, `NEEDS_RETAKE`, `FAILED`, `CANCELLED` |
| `DiagnosisCondition` | `HEALTHY`, `UNHEALTHY`, `UNCERTAIN` |
| `AIActionStatus` | `PENDING_CONFIRMATION`, `EXECUTING`, `COMPLETED`, `CANCELLED`, `EXPIRED`, `FAILED` |

컨디션은 다음 다섯 정수 중 하나만 저장합니다.

```text
0=1단계, 25=2단계, 50=3단계, 75=4단계, 100=5단계
```

월평균 점수는 해당 월 점수의 산술평균을 반올림한 정수입니다. 평균 단계는 점수 사이의
중간값을 경계로 `0~12.49=1`, `12.5~37.49=2`, `37.5~62.49=3`,
`62.5~87.49=4`, `87.5~100=5`로 계산합니다. 정확히 경계값이면 높은 단계를 사용합니다.

## 3. Supabase Auth

FastAPI `/auth/*` 엔드포인트는 만들지 않습니다.

### 이메일 회원가입

Flutter가 Supabase `signUp`을 호출합니다.

```json
{
  "email": "user@example.com",
  "password": "********",
  "options": {
    "data": {
      "leafie_nickname": "새싹집사"
    },
    "emailRedirectTo": "leafie://auth/confirm"
  }
}
```

- 입력: 이메일, 비밀번호, 비밀번호 확인, 닉네임
- 이메일 인증 링크 확인 전 로그인 불가
- 비밀번호 확인은 앱에서만 검증하고 전송하지 않음

### OAuth

지원 Provider는 Naver, Kakao, Apple입니다. Kakao와 Apple은 Supabase 기본 Provider,
Naver는 Custom OAuth2 Provider를 사용합니다. OAuth 계정은 이메일 제공이 필수이며
`GET /users/me`의 `profile_completed=false`이면 닉네임 입력 화면으로 이동합니다.

### 비밀번호 재설정·변경

현재 계정 이메일로 Supabase recovery 링크를 전송합니다. 링크가 앱으로 돌아오면
새 비밀번호와 확인을 입력하고 Supabase `updateUser`를 호출합니다. 소셜 전용 계정은
`can_change_password=false`입니다.

## 4. 사용자·마이페이지

### `GET /users/me`

```json
{
  "user_id": "uuid",
  "email": "user@example.com",
  "email_verified_at": "2026-07-31T10:00:00Z",
  "auth_providers": ["email"],
  "can_change_password": true,
  "nickname": "새싹집사",
  "timezone": "Asia/Seoul",
  "selected_plant_id": "uuid",
  "push_enabled": true,
  "profile_completed": true,
  "profile_completed_at": "2026-07-31T10:00:00Z",
  "gardener_days": 128
}
```

프로필 사진과 한 줄 소개는 없습니다.

### `PATCH /users/me`

닉네임만 수정합니다. OAuth 최초 닉네임 입력도 같은 API를 사용합니다.

```json
{"nickname": "초록집사"}
```

### `PATCH /users/me/selected-plant`

```json
{"selected_plant_id": "uuid-or-null"}
```

### `PATCH /users/me/notification-settings`

```json
{"push_enabled": false}
```

### `DELETE /users/me`

최근 재인증 토큰과 다음 body가 필요합니다.

```json
{"confirmation": "DELETE"}
```

응답은 `204`입니다. 계정은 즉시 접근 차단 후 Worker가 데이터를 삭제합니다.

## 5. 미디어

### `POST /media/presign`

```json
{
  "purpose": "DIARY",
  "content_type": "image/jpeg",
  "size_bytes": 1048576,
  "checksum_sha256": "64자리-sha256-hex"
}
```

```json
{
  "media_file_id": "uuid",
  "upload_url": "https://...",
  "upload_method": "PUT",
  "upload_headers": {"Content-Type": "image/jpeg"},
  "expires_at": "2026-07-31T10:05:00Z"
}
```

### `POST /media/{media_file_id}/complete`

Storage 업로드 후 호출합니다. 서버가 객체 존재, 형식과 크기를 검증합니다.

### `GET /media/{media_file_id}/download-url`

본인 소유 파일에 대한 짧은 만료 Signed URL을 반환합니다.

### `DELETE /media/{media_file_id}`

리소스에 연결되지 않은 업로드를 삭제합니다. 식물·다이어리·식물 인식·진단·채팅에
연결된 파일은 `MEDIA_FILE_IN_USE`로 거부합니다. 응답은 `204`입니다.

## 6. 지원 식물 검색·사진 인식

### `GET /species?query=바질&limit=20&cursor=`

내부 지원 23종의 표시명과 별칭만 검색합니다.

```json
{
  "items": [
    {
      "reference_id": "catalog:ocimum-basilicum",
      "display_name": "바질",
      "scientific_name": "Ocimum basilicum",
      "family_name": "Lamiaceae",
      "flowering_period": "여름",
      "category": "HERB",
      "recommended_water": {
        "min_ml": 150,
        "max_ml": 250,
        "source": "SPECIES_GUIDE"
      },
      "default_care": {
        "watering_interval_days": 3,
        "repotting_interval_days": 365,
        "source": "SPECIES_GUIDE",
        "derived": true
      }
    }
  ],
  "next_cursor": null,
  "has_next": false
}
```

### `POST /species/identifications`

```json
{"media_file_id": "uuid"}
```

응답 `202`:

```json
{
  "identification_id": "uuid",
  "status": "PENDING",
  "created_at": "2026-07-31T10:05:00Z"
}
```

### `GET /species/identifications/{identification_id}`

후보는 확률순이며 지원 23종과 매칭된 값만 반환합니다. 사용자가 `맞아요`를 누르면
해당 `reference_id`로 등록하고 `다시 검색`은 앱이 다음 후보를 보여줍니다.
지원 종과 매칭되는 후보가 없으면 `FAILED`와 `SPECIES_NO_CANDIDATES`를 반환합니다.

## 7. 식물 등록·조회·수정

### `POST /plants`

등록 마지막 단계에서 한 번 호출합니다.

```json
{
  "client_registration_id": "uuid",
  "nickname": "새싹이",
  "species_reference_id": "catalog:ocimum-basilicum",
  "species_selection_method": "PHOTO",
  "species_identification_id": "uuid",
  "primary_media_file_id": "uuid",
  "started_on": "2026-03-01",
  "place_name": "학교",
  "pot_type": "PLASTIC",
  "placement": "WINDOW",
  "last_watered_on": "2026-07-30",
  "repotting_history": {
    "status": "UNKNOWN",
    "date": null
  },
  "personality_type": "OUTGOING",
  "color_id": "color_green_01",
  "hair_id": "hair_leaf_01",
  "accessory_id": "accessory_star_01"
}
```

- Flutter는 등록 흐름을 시작할 때 `client_registration_id` UUID를 한 번 생성하고 등록
  결과를 받을 때까지 로컬에 보관합니다. 네트워크 오류나 타임아웃으로 재전송할 때는
  반드시 같은 UUID와 같은 요청 내용을 사용합니다. 새로운 식물을 등록할 때는 새 UUID를
  생성합니다.
- 같은 사용자의 동일한 `client_registration_id`와 동일한 요청은 식물·일정·대화를 다시
  만들지 않고 최초 `201 Created` 응답을 반환합니다. 같은 ID를 다른 요청 내용에 재사용하면
  `409 PLANT_REGISTRATION_ID_REUSED`를 반환합니다.
- `SEARCH` 등록은 `species_identification_id`와 `primary_media_file_id`를 null로
  보냅니다.
- `PHOTO` 등록은 두 ID가 모두 필요하며, `primary_media_file_id`는 해당 인식 작업에
  사용한 사진 ID와 같아야 합니다.
- 캐릭터 외형 ID 목록은 디자인 확정 전까지 공백과 최대 길이만 검증합니다. 확정 목록을
  전달받은 뒤 `color_id`, `hair_id`, `accessory_id` 허용 목록 검증을 추가합니다.

서버는 다음을 한 트랜잭션에서 처리합니다.

- `(user_id, client_registration_id)` 멱등성 확인과 요청 해시 검증
- 식물과 외형·환경 저장
- 마지막 물 준 날짜를 기준으로 최초 물주기 일정 계산
- 마지막 물주기 완료 이력 저장
- 분갈이 상태가 `KNOWN`이면 입력 날짜를 완료 이력으로 저장하고 최초 반복 일정 계산
- 분갈이 상태가 `NEVER`이면 사용자가 입력한 `started_on`을 기준으로 최초 반복 일정 계산
- 첫 AI 대화 세션 생성
- 선택 식물 갱신

`started_on`, 마지막 관리일과 분갈이 날짜는 미래일 수 없습니다. 사진 인식으로 등록한
경우 인식 사진을 대표 사진으로 재사용합니다. 검색 등록은 대표 사진 없이 등록하며,
종별 분갈이 주기가 있으면 `KNOWN`과 `NEVER`에 최초 분갈이 반복 일정을 생성합니다.
계산된 예정일이 과거이면 주기 단위로 더해 오늘 이후의 첫 예정일로 이동합니다.
`NEVER`는 완료 이력을 만들지 않고 `UNKNOWN`은 기준 날짜가 없어 최초 일정과 완료
이력을 모두 만들지 않습니다. 종별 분갈이 주기가 없으면 `KNOWN` 날짜는 완료 이력으로만
저장합니다.

성공 응답은 `201 Created`입니다.

```json
{
  "id": "uuid",
  "created_at": "2026-08-01T12:30:00Z"
}
```

클라이언트는 반환된 `id`를 사용해 `GET /home?plant_id={id}`로 등록한 식물의 홈을
조회합니다. 첫 AI 대화 세션 ID는 등록 응답에 포함하지 않으며 대화 목록 API에서
조회합니다.

### `GET /plants`

소유 식물 목록을 반환합니다.

### `GET /plants/{plant_id}`

종명, 대분류, 학명, 환경, 캐릭터 외형, D+와 오늘 컨디션을 반환합니다.

### `PATCH /plants/{plant_id}`

```json
{
  "nickname": "새싹이",
  "place_name": "우리 집",
  "pot_type": "CERAMIC",
  "placement": "LIVING_ROOM"
}
```

식물 종, 성격과 마지막 물주기·분갈이 날짜는 이 API에서 변경하지 않습니다.

### `PATCH /plants/{plant_id}/appearance`

```json
{
  "color_id": "color_yellow_01",
  "hair_id": "hair_cactus_02",
  "accessory_id": "accessory_glasses_01"
}
```

### `DELETE /plants/{plant_id}`

확인 팝업 후 호출합니다. 선택 식물이면 남은 식물로 전환하고 없으면 null로 만듭니다.

## 8. 홈

### `GET /home?plant_id={optional}`

`plant_id`가 없으면 현재 선택 식물을 사용합니다.

```json
{
  "plant": {
    "id": "uuid",
    "nickname": "새싹이",
    "days_together": 153,
    "primary_photo_url": "https://..."
  },
  "character": {
    "personality_type": "OUTGOING",
    "color_id": "color_green_01",
    "hair_id": "hair_leaf_01",
    "accessory_id": "accessory_star_01",
    "expression_level": 4,
    "dialogue": "오늘도 같이 잘 지내보자!"
  },
  "condition": {"recorded": true, "score": 75, "level": 4},
  "today_events": [],
  "daily_memo": {"content": "새잎이 보였다."},
  "unread_notification_count": 2
}
```

오늘 다이어리가 없으면 `condition.recorded=false`, 점수와 단계는 null입니다. 대사는
성격·컨디션·일정 상태에 맞는 고정 문구 중 하나를 반환합니다.

### `PUT /plants/{plant_id}/daily-memos/{date}`

식물별 하루 메모 한 개를 생성하거나 수정합니다.

```json
{"content": "오늘 새잎이 보였다."}
```

본문은 공백을 제외한 `1~500자`입니다. 완료 상태는 없으며 `date`는 사용자 시간대의
오늘만 허용합니다.

### `DELETE /plants/{plant_id}/daily-memos/{date}`

오늘 홈 메모를 삭제합니다. 이미 메모가 없어도 `204`를 반환합니다.

## 9. 관리 일정과 캘린더

### `GET /plants/{plant_id}/agenda?scope=active`

캐릭터 상세의 지연·오늘·미래 일정만 반환합니다.

### `POST /plants/{plant_id}/care-events`

비료, 가지치기와 자유 할 일 같은 일회성 이벤트를 생성합니다.

```json
{
  "client_event_id": "uuid",
  "type": "CUSTOM",
  "title": "화분 방향 돌려주기",
  "due_date": "2026-08-01"
}
```

사용자 생성 일회성 이벤트는 `FERTILIZING`, `PRUNING`, `CUSTOM`만 허용하며 제목은
필수입니다. `due_date`는 사용자 시간대의 오늘 또는 미래만 허용합니다. Flutter는 생성
흐름마다 `client_event_id` UUID를 만들고 성공 응답을 받을 때까지 유지합니다. 같은 ID와
같은 요청은 기존 이벤트를 반환하고 다른 요청에 재사용하면 `409 CLIENT_EVENT_ID_REUSED`로
차단합니다.

### `POST /care-events/{event_id}/complete`

오늘 완료:

```json
{}
```

과거 소급 완료:

```json
{"performed_on": "2026-07-30"}
```

```json
{
  "id": "uuid",
  "status": "COMPLETED",
  "due_date": "2026-07-30",
  "performed_on": "2026-07-30",
  "recorded_at": "2026-07-31T12:30:00Z",
  "next_event": {"id": "uuid", "due_date": "2026-08-06"}
}
```

`recorded_at`은 서버 시각이며 수정할 수 없습니다. 미래 `performed_on`은 거부합니다.
중복 완료 요청은 기존 완료 결과를 반환합니다. 반복 일정은 현재 `SCHEDULED` 이벤트를
완료한 뒤 `performed_on + interval_days`를 기준으로 `care_schedule.next_due_date`를
갱신하고 다음 `SCHEDULED` 이벤트 하나를 같은 트랜잭션에서 생성합니다. 계산된 날짜가
이미 과거이면 주기 단위로 오늘 이후 첫 날짜까지 이동합니다.

### `GET /plants/{plant_id}/calendar?from=2026-07-01&to=2026-07-31&types=WATERING,CONDITION`

- 월·주 모드는 같은 범위 API 사용
- 필터: 물주기, 분갈이, 비료, 가지치기, 컨디션
- 최대 조회 범위 3개월
- 미완료 일정은 `due_date`, 완료 기록은 `performed_on`에 표시
- 컨디션은 다이어리 날짜에 표시하고 완료할 수 없음

## 10. 다이어리

### `GET /plants/{plant_id}/diaries?year=2026&month=7`

```json
{
  "entries": [
    {
      "id": "uuid",
      "diary_date": "2026-07-20",
      "condition_score": 75,
      "condition_level": 4,
      "has_photo": true
    }
  ],
  "statistics": {
    "entry_count": 1,
    "average_score": 75,
    "average_level": 4
  }
}
```

기록 없는 달의 평균과 단계는 null입니다.

### `PUT /plants/{plant_id}/diaries/{date}`

같은 날짜의 기록이 없으면 생성하고 있으면 수정합니다.

```json
{
  "content": "오늘 새잎이 조금 더 펼쳐졌다.",
  "condition_score": 75,
  "media_file_id": "uuid-or-null"
}
```

- 본문은 공백 제거 후 `1~2,000자`, 점수는 `0`, `25`, `50`, `75`, `100` 중 하나
- 사진 최대 한 장
- 오늘과 과거 작성 가능, 미래 불가
- 생성할 때 사진 필드를 생략하거나 null로 보내면 사진 없이 저장
- 수정할 때 `media_file_id`를 생략하면 기존 사진 유지, null이면 기존 사진 제거,
  새 UUID이면 교체
- 사진 UUID는 본인 소유의 `DIARY`, `READY` 파일이어야 하며 하나의 다이어리에만 연결
- 같은 원본 이미지를 다른 다이어리에 사용하려면 새 업로드로 별도 UUID 생성

최초 생성은 `201 Created`, 기존 날짜 수정은 `200 OK`입니다. 생성·수정·상세 조회는
다음 형식을 반환합니다.

```json
{
  "id": "uuid",
  "plant_id": "uuid",
  "diary_date": "2026-07-20",
  "content": "오늘 새잎이 조금 더 펼쳐졌다.",
  "condition_score": 75,
  "condition_level": 4,
  "media": {
    "id": "uuid",
    "download_url": "signed-url",
    "expires_at": "2026-07-20T12:35:00Z"
  },
  "created_at": "2026-07-20T12:30:00Z",
  "updated_at": "2026-07-20T12:30:00Z"
}
```

사진이 없으면 `media`는 null입니다. 날짜는 경로로 고정되며 수정할 수 없습니다.

### `GET /plants/{plant_id}/diaries/{date}`

위 다이어리 응답 형식으로 본문, 사진 Signed URL, 점수와 5단계를 반환합니다.

### `DELETE /plants/{plant_id}/diaries/{date}`

다이어리를 삭제하고 `204 No Content`를 반환합니다. 이미 없는 다이어리도 204로 처리합니다.
연결된 사진이 있으면 DB에서 `DELETED`로 전환하고 같은 트랜잭션에서 Storage 삭제 작업을
Queue에 넣습니다. 실제 Storage 객체는 Worker가 멱등하게 삭제하며 실패하면 재시도합니다.

## 11. AI 대화와 Tool Calling

식물별 별도 `ai_chats` 리소스는 없습니다. 대화 세션을 식물에 직접 연결합니다.

### `GET /plants/{plant_id}/conversations?query=&cursor=`

현재 식물의 대화 제목과 최근 사용일을 반환합니다.

### `POST /plants/{plant_id}/conversations`

새 채팅 세션을 생성합니다.

```json
{"title": "새 채팅"}
```

제목이 `새 채팅`인 세션은 첫 질문을 최대 30자로 정리해 대화목록 제목으로 사용합니다.
글 없이 사진만 보낸 첫 질문은 `사진 질문`으로 표시합니다.

### `DELETE /conversations/{conversation_id}`

대화 세션만 soft delete합니다. 식물의 다른 대화는 유지합니다.

### `GET /conversations/{conversation_id}/messages?cursor=`

메시지를 생성일 순으로 반환합니다. 사진 메시지는 `PENDING`, `PROCESSING`,
`COMPLETED`, `FAILED` 상태로 처리 진행 상황을 표시합니다.

### `POST /conversations/{conversation_id}/messages`

```json
{
  "content": "잎이 노랗게 변했어요.",
  "media_file_id": null
}
```

텍스트와 사진 중 하나는 필수이며 사진은 미리 `CHAT` 용도로 업로드를 완료해야 합니다.
한 대화에서 응답은 한 번에 하나만 생성합니다.

텍스트 응답은 `text/event-stream`으로 반환합니다.

```text
event: message.started
data: {"message_id":"assistant-message-uuid"}

event: message.delta
data: {"delta":"답변 일부"}

event: action.proposed
data: {"action_id":"uuid","status":"PENDING_CONFIRMATION","proposal":{"care_type":"FERTILIZING","due_date":"2026-08-03","title":"비료 주기","reason":"생장기 관리 제안"},"expires_at":"2026-08-02T12:00:00Z","requires_user_confirmation":true}

event: message.completed
data: {"message_id":"assistant-message-uuid","content":"전체 답변"}
```

생성 실패 시 `message.failed` 이벤트와 `error_code`를 반환합니다. 사진 메시지는
`202`와 사용자 메시지 ID를 반환한 뒤 `CHAT_IMAGE_ANALYSIS` Worker가 처리합니다.
클라이언트는 메시지 목록을 다시 조회해 처리 상태와 생성된 답변을 확인합니다.
메시지 목록의 각 항목에는 연결된 `actions` 배열이 포함되므로 화면 재진입 후에도
승인 대기·완료·취소 상태를 복원할 수 있습니다.

AI 응답자는 식물 캐릭터가 아니라 `AI 식물박사 똑똑이`입니다. 모델 입력은 식물명,
애칭, 장소·화분·위치, 종별 관리 가이드, 현재 대화의 누적 요약과
최근 메시지만 사용합니다. 다른 식물이나 다른 대화 세션의 메시지는 섞지 않습니다.
식물 캐릭터의 성격은 AI 응답 말투에 적용하지 않으며 홈 대사와 푸시 알림 문구에만
사용합니다.

읽기 Tool은 서버가 실행합니다. 비료·가지치기 일정 변경은 `AI_ACTIONS` 제안만
만들고 승인 전에는 실행하지 않습니다.

지원 Tool:

- 식물 기본 정보, 종별 관리 가이드, 환경
- 지연·오늘·예정 관리 일정, 최근 완료 관리 이력
- 최근 다이어리 컨디션, 최근 완료 진단
- 비료·가지치기 1회성 일정 제안

모델이 생성한 Tool 인자에는 `user_id`, `plant_id`를 받지 않습니다. 서버가 인증 사용자와
현재 대화의 식물을 주입하며, 모든 호출은 `ai_tool_calls`에 성공·실패 상태로 기록합니다.
일정 제안은 24시간 동안 승인할 수 있습니다.

### `POST /ai-actions/{action_id}/confirm`

본인 식물의 `PENDING_CONFIRMATION` 제안만 승인할 수 있습니다. 승인하면
`AI_RECOMMENDED` 출처의 비료 또는 가지치기 1회성 일정이 생성됩니다.

```json
{
  "id": "uuid",
  "plant_id": "uuid",
  "action_type": "CREATE_ONE_TIME_CARE_EVENT",
  "payload": {
    "care_type": "FERTILIZING",
    "due_date": "2026-08-03",
    "title": "비료 주기",
    "reason": "생장기 관리 제안"
  },
  "status": "COMPLETED",
  "expires_at": "2026-08-02T12:00:00Z",
  "confirmed_at": "2026-08-01T12:10:00Z",
  "executed_at": "2026-08-01T12:10:00Z",
  "created_at": "2026-08-01T12:00:00Z"
}
```

### `POST /ai-actions/{action_id}/cancel`

본인 식물의 승인 대기 제안을 취소하고 같은 응답 구조에 `CANCELLED` 상태를 반환합니다.
이미 처리됐거나 만료된 제안은 `409`를 반환합니다.

## 12. 사진 진단

### `POST /plants/{plant_id}/diagnoses`

진단은 채팅 화면의 `진단하기`에서만 시작합니다.

```json
{
  "conversation_id": "uuid",
  "media_file_id": "uuid"
}
```

응답 `202`:

```json
{
  "diagnosis_id": "uuid",
  "status": "PENDING",
  "created_at": "2026-07-31T12:30:00Z"
}
```

동일한 `media_file_id`로 다시 요청하면 외부 API를 중복 호출하지 않고 기존 진단 ID를
반환합니다. 취소된 진단은 같은 ID를 `PENDING`으로 되돌려 다시 처리하고, 재시도할 수
없는 실패는 `409 DIAGNOSIS_NEW_PHOTO_REQUIRED`를 반환합니다. 사진은 `DIAGNOSIS`
용도로 업로드 완료된 JPEG·PNG·WebP 한 장이어야 합니다.

### `GET /plants/{plant_id}/diagnoses?cursor=`

현재 식물의 전체 진단 이력을 최신순으로 반환합니다.

### `GET /diagnoses/{diagnosis_id}`

```json
{
  "id": "uuid",
  "plant_id": "uuid",
  "status": "COMPLETED",
  "diagnosed_at": "2026-07-31T12:30:00Z",
  "photo_url": "https://...",
  "overall_condition": "UNHEALTHY",
  "condition_label": "조금 관리가 필요해요",
  "observations": ["잎 끝 마름", "잎 처짐"],
  "possible_causes": [
    {"name": "물 부족", "confidence": 0.76},
    {"name": "습도 부족", "confidence": 0.58}
  ],
  "recommended_care": [
    "흙 상태를 확인한 뒤 물을 주세요.",
    "밝은 간접광이 드는 곳으로 옮겨주세요."
  ],
  "related_conversation_id": "uuid"
}
```

원인 확률은 진단 Provider 값이 있을 때만 반환합니다. 건강점수, 단일 AI 신뢰도와
진단 점수 그래프는 제공하지 않습니다. 낮은 품질이나 식물 미검출은
`NEEDS_RETAKE`와 `retake_reason_code`, 처리 실패는 `FAILED`와 `failure_code`로
반환합니다.

### `POST /diagnoses/{diagnosis_id}/retry`

재시도 가능한 실패만 다시 Queue에 등록합니다.

### `POST /diagnoses/{diagnosis_id}/cancel`

`PENDING`만 취소할 수 있습니다.

## 13. 알림

### `GET /notifications?cursor=&unread_only=false&limit=20`

모든 식물의 앱 내 알림을 최신순으로 반환합니다. `limit`은 기본 `20`, 최소 `1`, 최대
`100`이며 잘못된 `cursor`는 `422 INVALID_CURSOR`를 반환합니다.

```json
{
  "items": [
    {
      "id": "uuid",
      "plant_id": "uuid",
      "type": "CARE_DUE",
      "title": "물 줄 시간이에요",
      "body": "새싹이에게 물을 주세요.",
      "source_type": "CARE_EVENT",
      "source_id": "uuid",
      "read_at": null,
      "created_at": "2026-08-02T09:00:00Z"
    }
  ],
  "next_cursor": null,
  "has_next": false
}
```

### `POST /notifications/{notification_id}/read`

본인 알림만 읽음 처리하며 이미 읽은 알림은 기존 결과를 반환합니다.
본인 알림이 아니거나 존재하지 않으면 `404 NOTIFICATION_NOT_FOUND`를 반환합니다.

### `POST /notifications/read-all`

현재 사용자의 읽지 않은 알림을 모두 읽음 처리하고 `204`를 반환합니다.

### `POST /devices`

```json
{"platform": "IOS", "installation_id": "firebase-installation-id"}
```

같은 활성 FID를 다시 등록하면 새 행을 만들지 않고 사용자, 플랫폼과 마지막 사용 시각을
갱신합니다. 응답의 `id`를 로컬에 저장해 로그아웃할 때 폐기 요청에 사용합니다.

### `DELETE /devices/{device_id}`

신규 Firebase 앱 인스턴스의 FID를 등록합니다. 로그아웃 또는 푸시 권한 철회 시
등록을 폐기합니다.
본인의 활성 기기가 아니면 `404 DEVICE_NOT_FOUND`를 반환합니다.

## 14. 내부 비동기 작업

외부에 노출하지 않는 Queue job type:

```text
SPECIES_IDENTIFICATION_RUN
DIAGNOSIS_RUN
CHAT_IMAGE_ANALYSIS
CARE_NOTIFICATION_COLLECT
PUSH_NOTIFICATION_SEND
STORAGE_OBJECT_DELETE
ACCOUNT_DELETE
```

`PUSH_NOTIFICATION_SEND.resource_id`는 `notifications.id`입니다. Worker는 사용자의
`push_enabled`와 활성 `device_tokens`를 다시 확인한 뒤 FCM으로 발송합니다. 미등록
FID는 폐기하고 일시 오류만 Queue 재시도 대상으로 처리합니다.

`CARE_NOTIFICATION_COLLECT`는 Supabase Cron이 매시간 발행합니다. Worker는 사용자
시간대의 오전 9시인 계정만 확인하여 오늘 또는 지연된 물주기·분갈이 일정마다
`CARE_DUE` 알림을 한 번 생성하고 `PUSH_NOTIFICATION_SEND`를 발행합니다.

Supabase Cron은 다음 작업만 시작합니다.

- 오늘·지연 일정 알림 대상 수집
- 재시도 대상 발행
- 고아 미디어 정리

OpenAI Batch API는 현재 MVP에서 사용하지 않습니다.
