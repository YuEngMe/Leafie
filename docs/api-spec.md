# API 명세 v0.6

이 문서는 구현 전 프론트엔드와 합의할 계약 초안입니다. 구현 이후 `/openapi.json`을 최종 기준으로 사용합니다.

## 1. 공통 규칙

- Base path: `/api/v1`
- Content-Type: `application/json; charset=utf-8`
- 인증: `Authorization: Bearer <supabase_access_token>`
- 식별자: UUID 문자열
- 시간: ISO 8601 UTC (`2026-07-17T03:00:00Z`)
- 날짜: `YYYY-MM-DD`
- 앱 표시 시간대 기본값: `Asia/Seoul`
- 목록 정렬 기본값: 최신순
- 삭제 성공: `204 No Content`

### 페이지네이션

커서 기반 페이지네이션을 사용합니다.

```json
{
  "items": [],
  "next_cursor": "opaque-cursor-or-null",
  "has_next": false
}
```

### 에러 응답

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

주요 공통 코드:

| HTTP | code | 의미 |
|---:|---|---|
| 400 | `INVALID_REQUEST` | 요청 형식 또는 상태가 올바르지 않음 |
| 401 | `AUTH_REQUIRED` | 인증 필요 |
| 401 | `TOKEN_EXPIRED` | Supabase Access Token 만료 |
| 403 | `EMAIL_NOT_VERIFIED` | 이메일 인증 전 로그인 시도 |
| 403 | `RESOURCE_FORBIDDEN` | 다른 사용자의 리소스 접근 |
| 404 | `*_NOT_FOUND` | 리소스 없음 |
| 409 | `EMAIL_ALREADY_EXISTS` | 이메일 중복 |
| 409 | `INVALID_STATE_TRANSITION` | 허용되지 않는 상태 변경 |
| 413 | `FILE_TOO_LARGE` | 파일 크기 초과 |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | 지원하지 않는 이미지 형식 |
| 422 | `VALIDATION_ERROR` | 필드 검증 실패 |
| 429 | `RATE_LIMITED` | 요청 횟수 제한 |
| 500 | `INTERNAL_ERROR` | 예상하지 못한 서버 오류 |

## 2. Enum

| 이름 | 값 |
|---|---|
| `PlantCategory` | `FOLIAGE`, `FLOWER`, `SUCCULENT_CACTUS`, `TREE`, `HERB`, `FRUIT`, `VINE` |
| `SpeciesSelectionMethod` | `SEARCH`, `PHOTO` |
| `SpeciesIdentificationStatus` | `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED` |
| `ConditionLevel` | `VERY_BAD`, `BAD`, `NORMAL`, `GOOD`, `VERY_GOOD` |
| `DiagnosisCondition` | `HEALTHY`, `OBSERVE`, `WARNING`, `CRITICAL`, `UNKNOWN` |
| `PersonalityType` | `OUTGOING`, `CHIC`, `CUTE`, `CRUSH`, `INTROVERTED`, `CHUNGCHEONG` |
| `CareEventType` | `WATERING`, `REPOTTING`, `FERTILIZING`, `PRUNING` |
| `CareEventStatus` | `SCHEDULED`, `OVERDUE`, `COMPLETED`, `CANCELLED` |
| `MediaPurpose` | `USER_PROFILE`, `PLANT_PROFILE`, `SPECIES_IDENTIFICATION`, `DIARY`, `DIAGNOSIS`, `CHAT` |
| `DiagnosisStatus` | `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`, `CANCELLED` |
| `ChatRole` | `USER`, `ASSISTANT`, `SYSTEM` |
| `AIMessageStatus` | `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED` |
| `ToolCallStatus` | `PENDING`, `COMPLETED`, `FAILED` |
| `AIActionStatus` | `PENDING_CONFIRMATION`, `EXECUTING`, `COMPLETED`, `CANCELLED`, `EXPIRED`, `FAILED` |
| `BatchJobStatus` | `CREATED`, `SUBMITTED`, `IN_PROGRESS`, `COMPLETED`, `FAILED`, `CANCELLED` |
| `MonthlyReportStatus` | `PENDING`, `COMPLETED`, `FAILED` |

컨디션 입력 UI는 5개 지점에 스냅되는 슬라이더입니다. 사용자는 숫자를 직접 입력하지 않습니다.

| 선택 단계 | 저장 점수 |
|---|---:|
| `VERY_BAD` | 10 |
| `BAD` | 30 |
| `NORMAL` | 50 |
| `GOOD` | 70 |
| `VERY_GOOD` | 90 |

월 평균을 아이콘으로 변환할 때는 `0~19`, `20~39`, `40~59`, `60~79`, `80~100` 구간을 사용합니다.

식물 종류 표시명은 다음과 같습니다.

| 값 | 표시명 |
|---|---|
| `FOLIAGE` | 관엽식물 |
| `FLOWER` | 꽃 |
| `SUCCULENT_CACTUS` | 다육이/선인장 |
| `TREE` | 나무 |
| `HERB` | 허브 |
| `FRUIT` | 열매 |
| `VINE` | 덩굴식물 |

## 3. Supabase Auth

회원가입, 이메일 인증, 로그인, 세션 갱신, 비밀번호 재설정, 로그아웃은 Flutter의
Supabase Auth SDK가 직접 처리합니다. FastAPI에는 별도의 `/auth/*` API를 만들지
않습니다.

| 화면 동작 | Supabase Auth 동작 |
|---|---|
| 회원가입 | `signUp(email, password)` |
| 인증 메일 재발송 | `resend(type: signup, email)` |
| 로그인 | `signInWithPassword(email, password)` |
| 비밀번호 재설정 메일 | `resetPasswordForEmail(email)` |
| 새 비밀번호 저장 | `updateUser(password)` |
| 로그아웃 | `signOut()` |

Supabase 프로젝트의 `Confirm email`을 활성화합니다. 인증 전 회원가입 응답에는
세션이 없으며 인증이 완료돼야 로그인할 수 있습니다. 로그인 식별자는 이메일로
통일하고 별도의 아이디 찾기는 제공하지 않습니다.

Flutter는 Supabase Access Token을 FastAPI에 전달합니다. FastAPI는 Supabase
JWKS로 JWT를 검증하고 `sub` claim을 현재 사용자 ID로 사용합니다. 만료된
Access Token의 갱신은 Supabase SDK가 담당합니다.

## 4. 사용자

| Method | Path | 설명 |
|---|---|---|
| GET | `/users/me` | 내 정보 조회 |
| PATCH | `/users/me` | 닉네임, 한 줄 소개, 프로필 사진, 시간대 수정 |
| PATCH | `/users/me/selected-plant` | 홈에서 선택한 식물 변경 |
| DELETE | `/users/me` | 계정과 사용자 데이터 삭제 요청 |
| GET | `/users/me/stats` | 전체 식물 및 기록 요약 |

`GET /users/me`의 사용자 객체에는 Supabase Auth에서 조합한 `email`,
`email_verified_at`과 애플리케이션 프로필의 `nickname`,
`bio`, `profile_image_url`, `timezone`, `selected_plant_id`, `gardener_days`가
포함됩니다. `gardener_days`는 가입일과 사용자 시간대의 오늘 날짜로 계산합니다.

`DELETE /users/me` 요청:

```json
{
  "confirmation": "DELETE"
}
```

비밀번호 변경과 로그아웃은 Supabase Auth SDK를 사용합니다. 회원 탈퇴는
삭제 직전에 Supabase Auth로 재로그인해 최근 발급된 Access Token을 사용해야
합니다. FastAPI가 업무 데이터와 Storage 삭제를 예약한 뒤 서버 권한으로
Supabase Auth 사용자를 삭제합니다.

## 5. 미디어 업로드

### `POST /media/presign`

```json
{
  "purpose": "DIAGNOSIS",
  "file_name": "plant.jpg",
  "content_type": "image/jpeg",
  "size_bytes": 1842301,
  "checksum_sha256": "hex-value"
}
```

응답 `201`:

```json
{
  "media_file_id": "uuid",
  "upload_url": "https://project.supabase.co/storage/v1/upload/sign/...",
  "upload_method": "PUT",
  "upload_headers": {
    "Content-Type": "image/jpeg"
  },
  "expires_at": "2026-07-17T03:10:00Z"
}
```

### `POST /media/{media_file_id}/complete`

저장소 업로드가 끝난 뒤 호출합니다. 서버가 파일 존재, 크기, 형식을 검사하고 `READY`로 변경합니다.

응답 `200`:

```json
{
  "id": "uuid",
  "status": "READY",
  "content_type": "image/jpeg",
  "size_bytes": 1842301
}
```

## 6. 식물

식물명칭은 필수입니다. 사용자는 임의 문자열을 바로 저장하지 않고 다음 두 경로 중
하나로 후보를 찾은 뒤 하나를 선택합니다.

1. 이름으로 검색하여 후보 선택
2. 사진을 한 장 촬영하거나 업로드하여 인식 후보 선택

사진 인식 결과는 자동 확정하지 않습니다. 서버는 신뢰도 순 후보를 반환하고 사용자가
하나를 선택해야 등록할 수 있습니다. 정해진 7개 `PlantCategory` 선택은 식물명칭과
별개의 필수 입력입니다.

| Method | Path | 설명 |
|---|---|---|
| GET | `/plant-species/search?query=` | 식물명칭 검색 후보 |
| POST | `/plant-species/identifications` | 사진 인식 작업 생성 |
| GET | `/plant-species/identifications/{identification_id}` | 사진 인식 상태와 후보 조회 |
| POST | `/plants` | 식물 등록 |
| GET | `/plants` | 내 식물 목록 |
| GET | `/plants/{plant_id}` | 식물 상세 |
| PATCH | `/plants/{plant_id}` | 식물 정보 수정 |
| PATCH | `/plants/{plant_id}/character` | 캐릭터 외형과 성격 수정 |
| PATCH | `/plants/{plant_id}/environment` | 장소, 화분, 위치 수정 |
| DELETE | `/plants/{plant_id}` | 식물 삭제 |
| GET | `/character-options` | 캐릭터 베이스, 색, 머리, 장식, 성격과 대사 미리보기 조회 |

`GET /plant-species/search?query=바질` 응답 `200`:

```json
{
  "items": [
    {
      "reference_id": "catalog:ocimum-basilicum",
      "display_name": "바질",
      "scientific_name": "Ocimum basilicum",
      "category_suggestion": "HERB",
      "confidence": null
    }
  ],
  "next_cursor": null,
  "has_next": false
}
```

`POST /plant-species/identifications`:

```json
{
  "media_file_id": "uuid"
}
```

`media_file_id`는 본인이 `SPECIES_IDENTIFICATION` 목적으로 업로드해 `READY`가 된
사진 한 장이어야 합니다. 응답 `202`:

```json
{
  "id": "uuid",
  "status": "PENDING",
  "created_at": "2026-07-23T13:30:00Z"
}
```

`GET /plant-species/identifications/{identification_id}` 응답 `200`:

```json
{
  "id": "uuid",
  "status": "COMPLETED",
  "candidates": [
    {
      "reference_id": "provider:ocimum-basilicum",
      "display_name": "바질",
      "scientific_name": "Ocimum basilicum",
      "category_suggestion": "HERB",
      "confidence": 0.91
    }
  ],
  "failure_code": null,
  "completed_at": "2026-07-23T13:30:04Z"
}
```

검색 결과의 `category_suggestion`은 UI의 초기 추천일 뿐이며 사용자가 최종 종류를
확인합니다. 사진 인식은 `COMPLETED` 후보 중 하나를 선택해야 하고, 인식 실패 또는
적합한 후보가 없으면 검색 방식으로 전환할 수 있습니다.

`POST /plants`:

```json
{
  "name": "씩씩이",
  "category": "HERB",
  "species_name": "바질",
  "species_scientific_name": "Ocimum basilicum",
  "species_reference_id": "provider:ocimum-basilicum",
  "species_selection_method": "PHOTO",
  "species_identification_id": "uuid",
  "started_on": "2026-07-16",
  "primary_media_file_id": "uuid-or-null",
  "character": {
    "base_type": "SPROUT",
    "body_color": "GREEN_01",
    "head_item": null,
    "accessory": null,
    "personality_type": "CHIC"
  },
  "environment": {
    "place_name": "학교",
    "pot_type": "PLASTIC",
    "placement": "VERANDA"
  },
  "initial_care": {
    "last_watered_on": "2026-07-15",
    "last_repotted_on": "2026-03-01",
    "watering_interval_days": 7,
    "repotting_interval_days": 180
  },
  "memo": null
}
```

`initial_care`가 있으면 식물 생성 트랜잭션에서 마지막 완료일의
`CARE_EVENTS`와 종류별 `CARE_SCHEDULES`를 함께 만듭니다. 첫 다음 예정일은
`마지막 실제 완료일 + interval_days`입니다.

응답 `201`:

```json
{
  "id": "uuid",
  "name": "씩씩이",
  "category": "HERB",
  "species_name": "바질",
  "species_scientific_name": "Ocimum basilicum",
  "species_selection_method": "PHOTO",
  "started_on": "2026-07-16",
  "days_together": 2,
  "primary_image_url": "short-lived-url-or-null",
  "character": {
    "base_type": "SPROUT",
    "body_color": "GREEN_01",
    "head_item": null,
    "accessory": null,
    "personality_type": "CHIC"
  },
  "current_condition": null,
  "created_at": "2026-07-17T03:00:00Z",
  "updated_at": "2026-07-17T03:00:00Z"
}
```

## 7. 홈

### `GET /home?date=2026-07-17`

선택 식물의 방, 식물 전환 목록, 오늘 다이어리의 컨디션과 할 일을 한 번에 제공합니다.

```json
{
  "selected_plant": {
    "id": "uuid",
    "name": "씩씩이",
    "character": {
      "base_type": "SPROUT",
      "body_color": "GREEN_01",
      "head_item": null,
      "accessory": null,
      "personality_type": "CHIC",
      "dialogue": "뭘 봐? 물이나 줘."
    },
    "condition_icon": {
      "state": "RECORDED",
      "level": "NORMAL",
      "score": 50,
      "diary_id": "uuid",
      "action": "NONE"
    },
    "days_together": 76
  },
  "plant_switcher": [
    {
      "id": "uuid",
      "name": "무럭이",
      "character_thumbnail_url": "short-lived-url"
    }
  ],
  "today_events": [
    {
      "id": "uuid",
      "type": "WATERING",
      "status": "OVERDUE",
      "scheduled_date": "2026-07-15",
      "overdue_days": 2
    }
  ],
  "daily_checkin": {
    "diary_written": true
  },
  "unread_notification_count": 2
}
```

대표 식물 변경은 `PATCH /users/me/selected-plant`로 처리합니다. 캘린더와 다이어리 API는 숨은 서버 상태에 의존하지 않고 항상 `plant_id`를 경로에 명시합니다.

오늘 다이어리가 없으면 `condition_icon`은 다음과 같습니다.

```json
{
  "state": "EMPTY",
  "level": null,
  "score": null,
  "diary_id": null,
  "action": "OPEN_DIARY_EDITOR",
  "diary_date": "2026-07-17"
}
```

식물 상세의 컨디션 아이콘은 직접 수정하는 컨트롤이 아닙니다. `RECORDED`
아이콘은 눌러도 동작하지 않습니다. `EMPTY` 전용 아이콘만 오늘 날짜의 다이어리
작성 화면으로 이동합니다.

## 8. 다이어리

| Method | Path | 설명 |
|---|---|---|
| PUT | `/plants/{plant_id}/diaries/{diary_date}` | 해당 날짜 다이어리 작성 또는 수정 |
| GET | `/plants/{plant_id}/diaries` | 다이어리 목록 |
| GET | `/diaries/{diary_id}` | 다이어리 상세 |
| PATCH | `/diaries/{diary_id}` | 다이어리 수정 |
| DELETE | `/diaries/{diary_id}` | 다이어리 삭제 |
| GET | `/plants/{plant_id}/diary-stats` | 월별 컨디션 평균과 일별 추이 |

`PUT /plants/{plant_id}/diaries/2026-07-17`:

```json
{
  "content": "새 잎이 펼쳐지기 시작했다.",
  "condition_level": "GOOD",
  "media_file_id": "uuid-or-null"
}
```

다이어리는 식물별 하루 한 개만 허용하고 사진은 최대 한 장입니다.
`content`와 `condition_level`은 필수이고 사진은 선택입니다. 프론트는 5지점
슬라이더에서 선택한 단계만
전송합니다. 서버가 `condition_score`로 변환해 다이어리에 함께 저장합니다.
숫자 직접 입력은 허용하지 않습니다. 같은 날짜의 `PUT`은 기존 다이어리를
갱신합니다.

## 9. 관리 일정 및 기록

| Method | Path | 설명 |
|---|---|---|
| POST | `/plants/{plant_id}/care-schedules` | 물주기 또는 분갈이 반복 규칙 생성 |
| GET | `/plants/{plant_id}/care-schedules` | 관리 규칙 목록 |
| PATCH | `/care-schedules/{schedule_id}` | 반복 간격과 활성 상태 수정 |
| POST | `/plants/{plant_id}/care-events` | 진단 기반 비료·가지치기 일회성 권장 일정 생성 |
| GET | `/plants/{plant_id}/care-events` | 기간별 관리 기록 조회 |
| GET | `/plants/{plant_id}/agenda` | 이번 주 할 일과 다음 일정 |
| GET | `/care-events/{event_id}` | 상세 조회 |
| PATCH | `/care-events/{event_id}` | 일정 수정 |
| POST | `/care-events/{event_id}/complete` | 일정 완료 처리 |
| DELETE | `/care-events/{event_id}` | 일정 취소 또는 삭제 |

`POST /plants/{plant_id}/care-schedules`:

```json
{
  "type": "WATERING",
  "interval_days": 7,
  "next_due_date": "2026-07-20",
  "enabled": true
}
```

기한이 지나도 완료되지 않은 일정은 삭제하거나 날짜를 이동하지 않고
`OVERDUE`로 유지합니다. 완료하면 서버가 기록한 완료일에 `interval_days`를
더해 다음 이벤트를 생성합니다.

반복 규칙은 `WATERING`, `REPOTTING`만 허용합니다. `FERTILIZING`,
`PRUNING`은 진단 결과에서 필요할 때 먼저 권장만 합니다. 사용자가 캘린더 추가를
선택한 경우에만 `source_diagnosis_id`가 있는 일회성 일정으로 생성하며 자동
반복하지 않습니다.
`POST /care-events/{event_id}/complete`는 요청 본문을 받지 않으며 서버의 현재
시각을 `completed_at`으로 저장합니다. 사용자는 완료 날짜와 시각을 수정하거나
과거로 입력할 수 없습니다. 다음 예정일은 이 시각을 사용자 시간대의 날짜로
변환한 뒤 반복 간격을 더해 계산합니다.

## 10. 캘린더 및 통계

### `GET /plants/{plant_id}/calendar?year=2026&month=7`

```json
{
  "year": 2026,
  "month": 7,
  "days": [
    {
      "date": "2026-07-17",
      "diary": {
        "id": "uuid",
        "thumbnail_url": "short-lived-url",
        "condition_level": "GOOD",
        "condition_score": 70
      },
      "care_events": [{"id": "uuid", "type": "WATERING", "status": "COMPLETED"}]
    }
  ]
}
```

### `GET /plants/{plant_id}/stats?from=2026-06-01&to=2026-07-31`

```json
{
  "days_together": 76,
  "diary_count": 12,
  "care_event_counts": {
    "WATERING": 8,
    "REPOTTING": 1,
    "FERTILIZING": 2
  },
  "condition_trend": [
    {"date": "2026-07-01", "level": "GOOD", "score": 70},
    {"date": "2026-07-17", "level": "NORMAL", "score": 50}
  ],
  "monthly_condition": {
    "average_score": 60.0,
    "level": "GOOD",
    "record_count": 2
  }
}
```

월 평균은 해당 월에 작성한 다이어리의 컨디션 점수를 사용합니다. 다이어리를
작성하지 않은 날은 평균에서 제외합니다. 기록이 없는 달은 `average_score`와
`level`을 `null`로 반환하며 0점으로 처리하지 않습니다.
진단표 막대그래프는 `condition_trend`를 날짜순으로 표시하며 X축은 날짜, Y축은
10·30·50·70·90점 컨디션 점수입니다.

## 11. 사진 기반 상태 분석

### `POST /plants/{plant_id}/diagnoses`

사진은 미리 `/media/presign`으로 업로드해야 합니다.

```json
{
  "media_file_id": "uuid-1",
  "symptom_started_on": "2026-07-14",
  "environment": {
    "location": "INDOOR",
    "light_level": "BRIGHT_INDIRECT",
    "soil_moisture": "DRY",
    "visible_pests": false
  },
  "user_note": "최근 잎 끝이 갈색으로 변했어요."
}
```

응답 `202 Accepted`:

```json
{
  "id": "uuid",
  "status": "PENDING",
  "created_at": "2026-07-17T03:00:00Z",
  "poll_after_seconds": 3
}
```

### `GET /diagnoses/{diagnosis_id}`

완료 응답:

```json
{
  "id": "uuid",
  "plant_id": "uuid",
  "status": "COMPLETED",
  "overall_condition": "WARNING",
  "summary": "잎 끝 갈변과 가벼운 처짐이 관찰됩니다.",
  "observations": ["잎 끝 갈변", "잎 처짐"],
  "possible_causes": [
    {
      "code": "UNDERWATERING_SUSPECTED",
      "label": "수분 부족 가능성",
      "confidence": 0.76,
      "evidence": ["마른 흙", "잎 처짐"]
    },
    {
      "code": "LIGHT_STRESS_SUSPECTED",
      "label": "강한 빛에 의한 스트레스 가능성",
      "confidence": 0.41,
      "evidence": ["잎 끝 갈변"]
    }
  ],
  "recommendations": [
    "흙 속 2~3cm의 수분 상태를 확인하세요.",
    "완전히 말랐다면 화분 아래로 물이 흐를 때까지 물을 주세요."
  ],
  "additional_question": null,
  "needs_retake": false,
  "confidence": 0.72,
  "disclaimer": "사진과 관리 기록을 기반으로 한 상태 분석이며 확정 진단이 아닙니다.",
  "completed_at": "2026-07-17T03:00:08Z"
}
```

진단 요청은 사진 한 장만 허용합니다. 재촬영 필요 응답도 HTTP `200`이며 `needs_retake=true`, `retake_reason`을 포함합니다.

### 기타 진단 API

| Method | Path | 설명 |
|---|---|---|
| GET | `/plants/{plant_id}/diagnoses` | 진단 기록 목록 |
| POST | `/diagnoses/{diagnosis_id}/retry` | 실패한 분석 재시도 |
| POST | `/diagnoses/{diagnosis_id}/cancel` | 대기 중인 분석 취소 |
| DELETE | `/diagnoses/{diagnosis_id}` | 진단과 연결 이미지 삭제 요청 |

## 12. AI 상담과 Tool Calling

| Method | Path | 설명 |
|---|---|---|
| POST | `/ai-chats` | 선택된 식물을 태그한 대화방 생성 |
| GET | `/ai-chats?query=&plant_id=` | 전체 대화 검색 및 식물 필터 |
| GET | `/ai-chats/{chat_id}/messages` | 메시지 목록 |
| POST | `/ai-chats/{chat_id}/messages` | 사용자 메시지 전송 |
| DELETE | `/ai-chats/{chat_id}` | 대화 삭제 |
| POST | `/ai-actions/{action_id}/confirm` | AI가 제안한 변경 작업을 사용자 승인 후 실행 |
| POST | `/ai-actions/{action_id}/cancel` | AI가 제안한 변경 작업 취소 |

`POST /ai-chats`:

```json
{
  "plant_id": "uuid",
  "title": "씩씩이의 물주기"
}
```

대화방 하나는 식물 하나에만 연결됩니다. 홈에서 선택된 식물은 새 대화방의 기본 태그일 뿐이며 기존 대화방의 식물은 변경되지 않습니다. 초기에는 일반 JSON 응답을 사용하고 응답 지연이 문제가 되면 SSE 스트리밍을 추가합니다.

`POST /ai-chats/{chat_id}/messages`는 `content`와 선택적인
`media_file_id` 한 개를 받습니다. 메시지의 식물 태그는 별도로 받지 않고
대화방의 `plant_id`를 사용해 한 대화에 여러 식물이 섞이지 않게 합니다.
AI 채팅의 사진 첨부는 MVP에 포함합니다. 정식 진단 결과가 필요한 경우에도 사진은
한 장만 사용하며, 진단 생성 API가 같은 `media_file_id`를 참조할 수 있습니다.
텍스트만 있는 메시지는 실시간으로 처리합니다. 사진이 첨부된 메시지는
`PROCESSING` 상태로 저장하고 `CHAT_IMAGE_ANALYSIS` Queue 작업을 만든 뒤 Worker가
처리합니다. 앱은 메시지 목록을 다시 조회하거나 완료 푸시를 받아 결과를 표시합니다.

`POST /ai-chats/{chat_id}/messages`는 OpenAI Responses API를 호출하고 필요할 때
다음 읽기 도구를 서버 내부에서 실행합니다.

```text
get_plant_profile
get_plant_environment
get_care_schedule
get_recent_care_events
get_recent_diaries
get_latest_diagnosis
get_today_tasks
get_condition_trend
```

FastAPI는 `user_id`와 `plant_id`를 대화방에서 주입하며 모델 입력값을 신뢰하지
않습니다. 읽기 도구는 즉시 실행합니다. 진단 기반 비료·가지치기 일회성 일정
추가는 바로 실행하지 않고 `AI_ACTIONS`에 `PENDING_CONFIRMATION` 상태로 저장해
사용자 승인을 받습니다. 물주기·분갈이 완료는 AI 도구로 제공하지 않고 일정
화면의 완료 버튼으로만 처리합니다.

Assistant 메시지에 변경 제안이 있으면 다음 형태의 액션 카드를 함께 반환합니다.

```json
{
  "action_id": "uuid",
  "action_type": "CREATE_ONE_TIME_CARE_TASK",
  "summary": "7월 25일 가지치기 일정을 추가할까요?",
  "status": "PENDING_CONFIRMATION",
  "expires_at": "2026-07-24T03:00:00Z"
}
```

`POST /ai-actions/{action_id}/confirm` 요청:

```json
{
  "expected_version": 1
}
```

이미 실행·취소·만료됐거나 원본 데이터가 바뀐 액션은 `409
INVALID_STATE_TRANSITION`을 반환합니다.

## 13. 월간 AI 리포트와 Batch

| Method | Path | 설명 |
|---|---|---|
| GET | `/plants/{plant_id}/monthly-reports` | 식물의 월간 AI 리포트 목록 |
| GET | `/monthly-reports/{report_id}` | 월간 AI 리포트 상세 |

월간 리포트 생성은 앱 요청이 아니라 매월 Supabase Cron이 시작합니다. Python
Worker가 대상 식물 데이터를 JSONL로 묶어 OpenAI Batch API에 제출하고 최대
24시간 안에 결과를 수집합니다.

```json
{
  "id": "uuid",
  "plant_id": "uuid",
  "year": 2026,
  "month": 7,
  "status": "COMPLETED",
  "average_condition_score": 64.3,
  "condition_summary": "월 초보다 후반의 컨디션이 안정적이었습니다.",
  "care_summary": "물주기 4회 중 3회를 예정일 안에 완료했습니다.",
  "frequent_issues": ["잎 처짐"],
  "next_month_recommendations": ["물주기 전 흙의 건조 상태를 확인하세요."],
  "generated_at": "2026-08-01T04:12:00Z"
}
```

실시간 AI 채팅과 사진 진단은 OpenAI Batch API를 사용하지 않습니다. Batch
항목의 `custom_id`는 식물과 대상 월을 연결하며 같은 식물·연·월 리포트는 한
개만 저장합니다.

## 14. 알림

| Method | Path | 설명 |
|---|---|---|
| POST | `/devices` | 푸시 기기 토큰 등록 |
| DELETE | `/devices/{device_id}` | 로그아웃 기기 토큰 제거 |
| GET | `/notifications` | 앱 알림함 목록 |
| PATCH | `/notifications/{notification_id}/read` | 알림 읽음 처리 |
| POST | `/notifications/read-all` | 전체 알림 읽음 처리 |
| GET | `/notification-settings` | 알림 설정 조회 |
| PATCH | `/notification-settings` | 물주기, 일정, 진단 완료, 월간 리포트 알림 설정 |

## 15. 내부 비동기 작업

외부 모바일 API가 아니라 FastAPI, Supabase Queues, Cron, Worker 사이의 계약입니다.

| Queue 작업 | 생성 주체 | 처리 주체 |
|---|---|---|
| `DIAGNOSIS_RUN` | FastAPI | Worker |
| `CHAT_IMAGE_ANALYSIS` | FastAPI | Worker |
| `PUSH_NOTIFICATION_SEND` | FastAPI 또는 Cron | Worker |
| `MONTHLY_REPORT_BATCH_SUBMIT` | Cron | Worker |
| `MONTHLY_REPORT_BATCH_COLLECT` | Cron 또는 Worker | Worker |
| `STORAGE_OBJECT_DELETE` | FastAPI | Worker |

Queue 메시지는 `job_type`, `resource_id`, `attempt`, `trace_id`만 포함합니다.
원본 사진과 긴 프롬프트는 DB 또는 Storage에서 다시 읽습니다.

## 16. 프론트 연동 우선순위

1. Supabase Auth와 FastAPI JWT 검증
2. 식물 CRUD와 홈
3. 미디어 업로드
4. 다이어리와 관리 일정
5. 캘린더와 통계
6. 비동기 진단 상태
7. AI 상담 Tool Calling과 사용자 승인 액션
8. 월간 AI 리포트와 푸시 알림
