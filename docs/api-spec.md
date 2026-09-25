# API 명세 v2

최신 화면과 제품 결정을 기준으로 한 목표 계약입니다. 실제 배포 계약은 구현 완료 후
FastAPI OpenAPI를 기준으로 검증합니다. 센서 API와 센서 데이터 필드는 이 문서 범위가
아닙니다.

세부 제안과 미확정 정책은 [전환 기준](product-transition.md)을 우선 확인합니다.

## 1. 공통 규칙

- Base URL: `/api/v1`
- 보호 API: `Authorization: Bearer <Supabase access token>` 필수
- UUID와 날짜는 각각 UUID 문자열, `YYYY-MM-DD`를 사용합니다.
- 시각은 UTC ISO 8601로 반환하고 사용자 날짜 계산은 프로필 `timezone`을 사용합니다.
- 목록은 cursor pagination을 사용합니다.
- 생성·완료 요청의 재전송은 client UUID 또는 리소스 상태로 멱등하게 처리합니다.
- 다른 사용자의 리소스는 존재 여부를 감추기 위해 `404`를 반환합니다.

오류 형식:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "요청값을 확인해 주세요.",
    "details": {}
  }
}
```

주요 상태 코드는 `200`, `201`, `202`, `204`, `400`, `401`, `404`, `409`, `422`,
`429`, `503`입니다.

## 2. Enum

```text
PersonalityType = OUTGOING | CHIC | CUTE | CRUSH | INTROVERTED | CHUNGCHEONG
SpeciesSelectionMethod = SEARCH | PHOTO
DiaryWeather = SUNNY | PARTLY_CLOUDY | CLOUDY | RAINY | SNOWY
CareType = WATERING | REPOTTING | FERTILIZING
CareEventStatus = SCHEDULED | COMPLETED
AsyncStatus = PENDING | PROCESSING | COMPLETED | FAILED
DiagnosisStatus = PENDING | PROCESSING | COMPLETED | NEEDS_RETAKE | FAILED | CANCELLED
DiagnosisCondition = HEALTHY | UNHEALTHY | UNCERTAIN
LetterStatus = PENDING | PROCESSING | COMPLETED | FAILED
MediaPurpose = PLANT_PROFILE | SPECIES_IDENTIFICATION | DIARY | DIAGNOSIS
```

`TODAY`와 `OVERDUE`는 저장 상태가 아니라 `due_date`와 사용자 시간대로 계산한 표시값입니다.

## 3. 인증

인증 요청은 Flutter의 Supabase Auth SDK가 직접 처리합니다.

- 이메일 회원가입: 이메일, 비밀번호와 `leafie_nickname` metadata를 전달하고 인증 링크를
  발송합니다. 비밀번호 확인과 필수 약관 동의는 호출 전에 앱에서 검증합니다.
- 로그인: 이메일·비밀번호 또는 Naver·Kakao·Apple OAuth를 사용합니다.
- OAuth는 이메일 제공이 필수입니다. 최초 로그인에서 `/users/me`의
  `profile_completed=false`이면 닉네임 입력 화면으로 갑니다.
- 비밀번호 찾기: 이메일 재설정 링크가 앱 딥링크로 돌아온 뒤 앱에서 새 비밀번호를 설정합니다.
- 비밀번호와 확인값은 FastAPI에 보내지 않습니다.

## 4. 사용자·마이페이지

### `GET /users/me`

```json
{
  "user_id": "uuid",
  "email": "user@example.com",
  "nickname": "초록이",
  "profile_completed": true,
  "selected_plant_id": "uuid",
  "timezone": "Asia/Seoul",
  "notifications_enabled": true,
  "can_change_password": true,
  "gardener_days": 128
}
```

`gardener_days`는 사용자의 가장 오래된 식물 `started_on` 기준이며 식물이 없으면 `0`입니다.
소셜 전용 계정은 `can_change_password=false`입니다. 프로필 사진과 한 줄 소개는 반환하지
않습니다.

### `PATCH /users/me`

```json
{ "nickname": "잎새" }
```

### `PATCH /users/me/selected-plant`

```json
{ "plant_id": "uuid-or-null" }
```

### `PATCH /users/me/notification-settings`

```json
{ "notifications_enabled": true }
```

### `DELETE /users/me`

최근 재인증을 확인한 뒤 계정을 비활성화하고 `202 Accepted`를 반환합니다. 연관 데이터와
Storage 파일은 멱등 Worker가 삭제합니다.

## 5. 미디어

### `POST /media/presign`

```json
{
  "purpose": "DIARY",
  "content_type": "image/jpeg",
  "size_bytes": 542312
}
```

응답은 `media_file_id`, `upload_url`, 필요한 헤더와 만료 시각을 반환합니다.

### `POST /media/{media_file_id}/complete`

업로드 객체의 크기, 형식, 소유권을 검증합니다.

### `GET /media/{media_file_id}/download-url`

만료 시간이 짧은 비공개 다운로드 URL을 반환합니다.

### `DELETE /media/{media_file_id}`

미사용 파일만 삭제할 수 있으며 Storage 삭제는 비동기로 처리합니다.

## 6. 지원 식물과 사진 인식

### `GET /species?query=바질&limit=20&cursor=`

지원하는 정확한 23종에서 이름과 학명으로 검색합니다.

```json
{
  "items": [
    {
      "species_reference_id": "basil",
      "display_name": "바질",
      "scientific_name": "Ocimum basilicum",
      "family_name": "꿀풀과",
      "category": "HERB",
      "flowering_period": "6~9월"
    }
  ],
  "next_cursor": null
}
```

`category`는 표시용 파생값이며 사용자가 7개 대분류를 고르지 않습니다.

### `POST /species/identifications`

```json
{ "media_file_id": "uuid" }
```

`202 Accepted`와 `identification_id`, `status=PENDING`을 반환합니다.

### `GET /species/identifications/{identification_id}`

완료 시 내부 23종과 매칭된 후보를 confidence 내림차순으로 반환합니다. 앱은 `아니에요`를
누를 때 다음 후보를 보여주고 후보가 끝나면 검색 화면으로 이동합니다. 선택된 인식 사진의
`media_file_id`는 식물 대표 사진으로 재사용합니다.

## 7. 식물 등록·조회·수정

### `POST /plants`

```json
{
  "client_registration_id": "uuid",
  "nickname": "새싹이",
  "species_reference_id": "basil",
  "species_selection_method": "PHOTO",
  "species_identification_id": "uuid-or-null",
  "primary_media_file_id": "uuid-or-null",
  "place_name": "내 방 창가",
  "started_on": "2026-07-01",
  "last_watered_on": null,
  "last_repotted_on": null,
  "personality_type": "INTROVERTED",
  "body_id": "body_circle",
  "color_id": "color_green",
  "hair_id": "hair_sprout",
  "expression_id": "expression_default"
}
```

- 검색 등록은 `species_identification_id`와 대표 사진이 null일 수 있습니다.
- 마지막 물 준 날과 분갈이 날짜는 선택값입니다.
- 같은 사용자와 `client_registration_id`의 동일 요청은 최초 결과를 반환하고 다른 요청은
  `409 IDEMPOTENCY_KEY_REUSED`를 반환합니다.
- 성공 시 식물, 물주기 반복 일정, 알려진 경우 분갈이 반복 일정을 한 번만 생성합니다.
- `last_watered_on`과 `last_repotted_on`은 식물 행의 수정 필드가 아니라 최초 완료 이력과
  다음 예정일 계산에 사용합니다. 마지막 물 준 날이 null이면 완료 이력을 만들지 않고 API 요청
  처리일을 기준으로 최초 물주기 일정을 계산합니다. 분갈이 날짜가 null이면 분갈이 이력과 일정을
  만들지 않습니다.
- 장식, 화분, 위치 분류, 컨디션과 대화 세션은 생성하지 않습니다.

### `GET /plants`

```json
{
  "items": [
    {
      "id": "uuid",
      "nickname": "새싹이",
      "species_reference_id": "basil",
      "species_display_name": "바질",
      "personality_type": "INTROVERTED",
      "body_id": "body_circle",
      "color_id": "color_green",
      "hair_id": "hair_sprout",
      "expression_id": "expression_default",
      "primary_photo_url": "signed-url-or-null",
      "started_on": "2026-07-01"
    }
  ]
}
```

### `GET /plants/{plant_id}`

등록 정보, 종 정보, 외형, 대표 사진과 식물 시작일을 반환합니다.

### `PATCH /plants/{plant_id}`

```json
{
  "nickname": "새잎이",
  "place_name": "거실 창가",
  "personality_type": "CHIC"
}
```

종과 시작일은 변경하지 않습니다. 성격은 6종 중 하나로 변경할 수 있으며, 실제 값이
바뀐 경우에만 변경 이력을 저장합니다. 기존 편지 내용은 바꾸지 않고 이후 생성되는
홈 대사·편지 등에는 새 성격을 사용합니다.

### `PATCH /plants/{plant_id}/appearance`

```json
{
  "body_id": "body_square",
  "color_id": "color_blue",
  "hair_id": "hair_monstera",
  "expression_id": "expression_happy"
}
```

`body_id`는 `body_circle`, `body_thumb`, `body_square` 중 하나이며 등록 후에도
컬러·머리·표정과 함께 독립적으로 변경할 수 있습니다. 성격은 별도 필드입니다.

`expression_id`는 아래 4개만 허용합니다. 바디와 독립적으로 선택하므로 프론트는
바디 3종과 표정 4종을 조합해 표시합니다.

```text
expression_default
expression_happy
expression_neutral
expression_sad
```

`color_id`는 아래 10개만 허용합니다.

```text
color_red
color_orange
color_yellow
color_light_green
color_green
color_sky
color_blue
color_purple
color_pink
color_white
```

`hair_id`는 아래 9개만 허용합니다. 이전 임시 ID와 `NONE`은 신규 등록·수정에
사용하지 않습니다.

```text
hair_sunflower
hair_cherry_tomato
hair_hydrangea
hair_pointed_succulent
hair_monstera
hair_flower_cactus
hair_rosette_succulent
hair_sprout
hair_daisy
```

### `DELETE /plants/{plant_id}`

확인 팝업을 거친 뒤 호출합니다. 삭제가 끝나면 다음 선택 식물 ID 또는 null을 반환합니다.

## 8. 홈

### `GET /home?plant_id={optional}`

```json
{
  "plant": {
    "id": "uuid",
    "nickname": "새싹이",
    "started_on": "2026-07-01",
    "days_together": 33,
    "personality_type": "INTROVERTED",
    "body_id": "body_square",
    "color_id": "color_blue",
    "hair_id": "hair_monstera",
    "expression_id": "expression_happy",
    "primary_photo_url": "signed-url-or-null"
  },
  "room": {
    "background_phase": "DAY",
    "dialogue_key": "NORMAL",
    "dialogue": "와줬네… 사실 조금 기다렸어."
  },
  "today_events": [
    {
      "id": "uuid",
      "care_type": "WATERING",
      "due_date": "2026-08-02",
      "view_status": "TODAY",
      "source": "AUTO_SCHEDULE",
      "completable": true
    }
  ],
  "unread_letter_count": 1,
  "unread_notification_count": 2
}
```

함께한 날짜는 시작 당일을 1일로 계산합니다. `background_phase`는 사용자 시간대 기준
06:00~17:59에 `DAY`, 그 밖에는 `NIGHT`입니다. 홈 대사는 여섯 성격과 11개 상황별 고정
문구를 사용합니다. 발동 조건·우선순위·유지 시간과 센서 연동이 확정되기 전에는
`dialogue_key=NORMAL`과 해당 성격의 평소 대사를 반환합니다.

`today_events`는 선택 식물의 오늘 물주기·분갈이·비료 일정입니다. 해 아이콘 교감은 앱
애니메이션이며 API 호출이 없습니다. 센서 장치·토양 수분·일별 누적 조도 게이지는 센서
담당 API에서 별도로 조회하고 홈은 센서 원시값이나 임계값을 계산하지 않습니다. 센서 계약
연결 전 가짜 상태를 반환하지 않습니다. 식물이 없으면 `plant`, `room`은 null이며
`today_events`는 빈 배열입니다. 읽지 않은 편지와 알림 개수는 선택 식물이 아니라 사용자의
전체 식물을 기준으로 계산합니다.

## 9. 관리 일정과 캘린더

### `GET /plants/{plant_id}/agenda?scope=active`

지연·오늘·미래의 미완료 일정만 반환합니다.

### `POST /plants/{plant_id}/care-events`

사용자가 분갈이 또는 비료 일정을 추가합니다. 비료는 일회성입니다. 미완료 분갈이가
있으면 새 회차를 만들지 않고 기존 일정의 예정일과 반복 규칙의 `next_due_date`를 함께
변경합니다. 미완료 분갈이가 없고 해당 종에 권장 분갈이 간격이 있으면 반복 규칙과 첫
일정을 만들며, 권장 간격이 없으면 일회성 일정으로 만듭니다.

```json
{
  "client_event_id": "uuid",
  "care_type": "REPOTTING",
  "due_date": "2026-08-10"
}
```

`client_event_id`는 앱이 생성한 UUID입니다. 같은 ID와 같은 요청을 재전송하면 기존 결과를
반환하고, 같은 ID의 내용을 바꾸어 재사용하면 `409 CLIENT_EVENT_ID_REUSED`를 반환합니다.
예정일은 사용자 시간대 기준 오늘 또는 미래만 허용합니다. 최초 생성은 `201`, 멱등 재전송과
기존 분갈이 일정의 날짜 변경은 `200`입니다.

### `POST /care-events/{event_id}/complete`

```json
{ "performed_on": "2026-08-01" }
```

미래 완료는 거부합니다. 물주기·분갈이 반복 일정은 완료일 기준으로 다음 회차를 한 번
생성합니다. 과거 날짜를 선택해 놓친 완료를 기록할 수 있습니다.

### `GET /plants/{plant_id}/calendar?from=2026-07-01&to=2026-07-31`

```json
{
  "items": [
    {
      "event_id": "uuid",
      "care_type": "WATERING",
      "due_date": "2026-07-15",
      "status": "COMPLETED",
      "display_status": "COMPLETED",
      "performed_on": "2026-07-15"
    }
  ]
}
```

월·주 화면은 같은 API를 사용합니다. 반환 종류는 물주기, 분갈이, 비료뿐입니다.

## 10. 다이어리

### `GET /plants/{plant_id}/diaries?year=2026&month=7`

달력 표시용 작성 날짜와 상세 요약을 반환합니다. 컨디션 통계는 반환하지 않습니다.
각 항목은 `id`, `diary_date`, `weather`, `title`, `has_photo`를 반환합니다. 전환 이전
다이어리의 `weather`와 `title`은 `null`일 수 있습니다.

### `PUT /plants/{plant_id}/diaries/{date}`

```json
{
  "weather": "SUNNY",
  "title": "새잎이 난 날",
  "content": "아침에 새잎을 발견했다.",
  "media_file_id": "uuid-or-null"
}
```

`weather`는 `SUNNY`, `PARTLY_CLOUDY`, `CLOUDY`, `RAINY`, `SNOWY` 중 하나이며
`title`은 공백을 제외하고 1~100자, `content`는 1~2,000자입니다. 신규 생성과 수정
요청에는 세 필드를 모두 보냅니다. 전환 이전 다이어리를 수정할 때도 제목과 날씨가
필요합니다.

- 식물별·날짜별 한 건을 생성하거나 수정합니다.
- 미래 날짜는 허용하지 않습니다.
- 생성 시 같은 트랜잭션에서 편지 한 건을 예약하고 `scheduled_at`을 현재 시각의 5~15분
  뒤로 한 번 정합니다. 이는 공개 목표 시각이며 생성 작업은 커밋 직후 실행합니다.
- 이미 다이어리에 편지가 있으면 수정 요청은 편지를 새로 만들지 않습니다.
- Worker가 입력 스냅샷을 읽기 전 수정은 반영되지만, 이후 수정은 진행 중인 요청을
  재시작하지 않습니다. 완료 편지는 불변이며 전환 이전 다이어리에 소급 생성하지 않습니다.

응답:

```json
{
  "diary": {
    "id": "uuid",
    "diary_date": "2026-07-20",
    "weather": "SUNNY",
    "title": "새잎이 난 날",
    "content": "아침에 새잎을 발견했다.",
    "photo_url": "signed-url-or-null"
  },
  "letter": {
    "id": "uuid",
    "status": "PENDING",
    "scheduled_at": "2026-07-20T07:12:00Z"
  }
}
```

### `GET /plants/{plant_id}/diaries/{date}`

해당 날짜의 다이어리를 반환합니다. 전환 이전 다이어리의 제목·날씨는 `null`일 수 있습니다.

### `DELETE /plants/{plant_id}/diaries/{date}`

해당 날짜의 다이어리를 삭제하며 성공과 반복 삭제 모두 204를 반환합니다. 연결 사진은
비동기 Storage 정리 대상으로 전환하고, 이미 연결된 편지는 FK cascade로 함께 삭제합니다.
삭제 뒤 도착한 편지 Worker 작업은 편지를 생성하거나 공개하지 않습니다.

## 11. 우편함과 편지

클라이언트가 편지를 직접 생성하거나 재생성하는 API는 제공하지 않습니다.

### `GET /letters?plant_id={optional}&cursor=&unread_only=false&limit=20`

기본값은 사용자가 소유한 모든 식물의 우편함이며 `plant_id`로 한 식물만 필터링할 수
있습니다.

```json
{
  "items": [
    {
      "id": "uuid",
      "plant_id": "uuid",
      "plant_nickname": "새싹이",
      "diary_id": "uuid",
      "diary_date": "2026-07-20",
      "status": "COMPLETED",
      "preview": "오늘 네가 새잎을 발견해 줘서...",
      "generated_at": "2026-07-20T07:12:00Z",
      "published_at": "2026-07-20T07:12:00Z",
      "is_read": false
    }
  ],
  "next_cursor": null
}
```

### `GET /letters/{letter_id}`

식물 정보, 다이어리 날짜, 편지 본문과 생성 시각을 반환합니다.
조회만으로 읽음 처리하지 않습니다. `published_at`, `read_at`도 반환합니다.

### `GET /letters/unread-count?plant_id={optional}`

공개된 본인 편지의 미확인 개수를 `{"unread_count": 0}` 형식으로 반환합니다.
홈 응답은 같은 기준을 사용하며 생성 완료되었어도 아직 공개 전이면 제외합니다.

### `POST /letters/{letter_id}/read`

`read_at`을 최초 한 번 기록하며 재호출해도 성공합니다.

### `DELETE /letters/{letter_id}`

우편함에서 편지만 soft delete합니다. 연결된 다이어리는 유지하고 재생성하지 않습니다.
본인의 이미 soft delete된 편지는 반복 요청에도 204입니다. 다른 사용자/비공개/존재하지 않는
편지는 404입니다. 해당 편지 알림도 제거하며 이미 전달된 푸시의 대상 상세는 404가 됩니다.

## 12. 사진 진단

### `POST /plants/{plant_id}/diagnoses`

```json
{ "media_file_id": "uuid" }
```

`202 Accepted`와 `diagnosis_id`, `status=PENDING`을 반환합니다.

### `GET /plants/{plant_id}/diagnoses?cursor=`

오늘 진단과 지난 진단을 최신순으로 반환합니다.

### `GET /diagnoses/{diagnosis_id}`

```json
{
  "id": "uuid",
  "status": "COMPLETED",
  "photo_url": "signed-url",
  "overall_condition": "UNHEALTHY",
  "condition_label": "조금 관리가 필요해요",
  "observations": ["건강 이상 가능성"],
  "possible_causes": [
    { "name": "수분 부족", "confidence": 0.76 }
  ],
  "recommended_care": ["물을 충분히 주세요.", "밝은 곳으로 옮겨 주세요."]
}
```

진단은 채팅이나 편지와 연결하지 않습니다.

현재 Kindwise 연동의 `observations`는 건강 판정 요약이며, 사진에서 개별 증상을
추출한 목록이 아닙니다. 원인 후보는 `possible_causes`에만 표시합니다.
- `HEALTHY`: `observations=["뚜렷한 이상 징후 없음"]`, 원인 후보는 빈 목록이며
  추천 관리는 `현재 관리 방법을 유지하고 정기적으로 상태를 확인해 주세요.`입니다.
  공급자가 질병 후보나 처치를 함께 반환해도 건강 판정에는 적용하지 않습니다.
- `UNHEALTHY`: `observations=["건강 이상 가능성"]`과 원인 후보, 추천 관리를 반환합니다.
- `UNCERTAIN`: 유해 원인 후보를 구분하지 못한 경우
  `observations=["사진만으로 판별 어려움"]`을 반환합니다.

프론트는 기존 필드와 배열 타입을 그대로 사용합니다. 별도 건강 점수나 상세 증상
추출 기능은 제공하지 않으며, 이 정책은 새로 처리되는 진단부터 적용합니다.

진단 분리 구현(#43): 생성 요청은 `media_file_id`만 받습니다. 기존 `conversation_id`를
계속 보내면 추가 필드 검증으로 거부합니다. 상세 응답에는 `related_conversation_id`가
없습니다. 같은 사진을 다른 식물의 진단에 재사용하면 `409 DIAGNOSIS_MEDIA_ALREADY_USED`를
반환하며 기존 진단을 재시작하지 않습니다. 같은 식물·사진 재전송의 멱등성은 유지합니다.

### `POST /diagnoses/{diagnosis_id}/retry`

재시도 가능한 실패 상태에서만 새 작업을 enqueue합니다.

### `POST /diagnoses/{diagnosis_id}/cancel`

처리 전 상태만 취소합니다.

## 13. 알림과 푸시 기기

### `GET /notifications?cursor=&unread_only=false&limit=20`

오늘과 이전 알림을 최신순으로 반환합니다. 각 항목은 `type`, 제목, 본문, `read_at`,
`target_type`, `target_id`, `created_at`을 포함합니다. 편지 도착 알림은 해당 편지 상세로
이동합니다. 센서 알림은 센서 도메인이 발생시키되 같은 알림 구조를 사용합니다.

### `POST /notifications/{notification_id}/read`

### `POST /notifications/read-all`

읽음 처리는 멱등합니다.

### `POST /devices`

```json
{
  "installation_id": "firebase-installation-id",
  "platform": "IOS"
}
```

### `DELETE /devices/{device_id}`

`devices`는 푸시 수신용 앱 설치 정보이며 식물 센서 장치가 아닙니다.

## 14. 내부 비동기 작업

외부에 노출하지 않는 작업 종류:

```text
SPECIES_IDENTIFICATION_RUN
DIAGNOSIS_RUN
LETTER_GENERATION_RUN
LETTER_PUBLISH
PUSH_NOTIFICATION_SEND
STORAGE_OBJECT_DELETE
ACCOUNT_DELETE
PLANT_DELETE
CARE_NOTIFICATION_COLLECT
```

`LETTER_GENERATION_RUN` 규칙:

1. 저장 커밋 직후 `PENDING` 편지를 원자적으로 `PROCESSING`으로 선점합니다.
2. 처리 직전 최신 다이어리, 식물, 성격과 센서 담당자의 날짜별 요약을 읽습니다.
3. 완전한 OpenAI 응답만 저장하고 `COMPLETED`로 전환하며 공개 작업을 원자적으로 예약합니다.
   `scheduled_at` 전에는 완료되어도 목록·상세·읽음·미확인 개수에서 숨깁니다.
4. 예약 시각 이후 공개합니다. 생성 지연 시 완료 후 공개합니다. `published_at` 기록,
   도착 알림과 `PUSH_NOTIFICATION_SEND` 등록은 원자적으로 수행합니다.
5. 인증·요청 오류, 거절·빈 본문·불완전 응답은 `FAILED`, timeout·429·5xx는 제한 재시도합니다.
6. 중복 전달이나 Worker 재시작에도 `diary_id` unique와 상태 조건으로 두 번째 편지를
   만들지 않습니다.

생성/공개 Worker, 우편함과 다이어리 최초 저장 호출은 구현되어 있으며
`LETTER_PUBLISH`가 공개를 담당합니다. 실제 센서 조회가 연결될 때까지
`LETTER_GENERATION_ENABLED`는 비활성화합니다.
[편지 연동 가이드](letter-integration.md)의 연결·배포 순서를 따릅니다.

센서 요약이 언제나 제공된다는 제품 전제를 따르되, 구체 데이터 형식과 산출 방식은 센서
담당 계약에서 정의합니다.
