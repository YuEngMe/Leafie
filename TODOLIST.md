# TODOLIST

미뤄 둔 일을 한곳에 모은다. "지금 TODO 뭐 있지?" 하면 이 파일을 본다.

코드 안의 `TODO(design)` 주석과 짝을 이룬다 — 주석은 고칠
자리를, 이 파일은 왜 미뤘고 무엇이 풀려야 시작할 수 있는지를 적는다.

---

## 백엔드 연동 상태

다음 기능은 `LeafieApiClient`를 통해 실제 API에 연결했다.

| 기능 | 연결 API |
|---|---|
| 식물 검색·등록 | `GET /species`, `POST /plants` |
| 사진 식물 인식 | 미디어 업로드, `POST/GET /species/identifications` |
| 홈·캘린더·진단 | `/home`, `/calendar`, `/care-events`, `/diagnoses` |
| 다이어리 | 월 조회와 날짜별 `GET/PUT/DELETE /diaries` |
| 프로필 | `GET/PATCH/DELETE /users/me`, 알림 설정 |
| 알림 센터 | 목록·개별 읽음·전체 읽음, 기기 등록·해제 API |
| 식물 관리 | 목록·선택 전환·이름·색상 수정·삭제 API |

알림 센터 화면과 홈 unread 배지는 연결했다. 기기 등록 API도 구현했지만 실제
FCM 토큰 획득·등록은 FCM 자격 증명 설정 후 연결해야 한다. 실기기용 배포 API
주소 설정도 남아 있다.

---

## 팀 확인 대기

### 비밀번호 재설정 메일 문구가 영어다

로그인 전(`password_reset_screen.dart`)과 마이페이지
(`change_password_screen.dart`)가 같은 `resetPasswordForEmail`을 쓰므로
메일도 **Reset password** 템플릿 하나로 모인다.

대시보드 → Authentication → Email Templates → **Reset password**에서 한국어로
바꾸면 두 화면에 함께 적용된다. 회원가입은 Confirm signup이라는 별개
템플릿이라 영향받지 않는다.


## 팀 확인 대기 (2026-09-07 감사에서 추가)

| 항목 | 자리 | 내용 |
|---|---|---|
| 홈 3말풍선 상태 트리거 | `home_screen.dart` `HomeScene.happy` | 시안 6프레임(2346:479 등)의 "히히/신난다/좋은 하루야!"는 그렸으나 언제 띄우는지 시안·API에 없다. 선인장+분홍꽃 캐릭터 PNG도 필요 |
| 회원가입 '완료' 버튼 | `signup_screen.dart` | 2395:46은 인증이 끝나면 발송 버튼이 '완료'가 되는데, 앱은 가입 마지막에 signUp이 메일을 보내는 흐름이라 그 전에 인증 완료 상태가 없다. 흐름을 바꿀지 결정 필요 |
| 인앱 카메라 3화면 | `plant_species_search_screen.dart` | 2318:2609/2741/2788은 앱 안 카메라 UI인데 image_picker(OS 카메라)로 가기로 했었다. 유지할지 확인 |

### 백엔드에 넘긴 버그 (2026-09-09)

| 항목 | 자리 | 내용 |
|---|---|---|
| 방금 발급된 토큰 401 | `backend/app/core/security.py` | `jwt.decode()`에 시계 오차 leeway가 없어 서버 시계가 Supabase보다 몇 초 느리면 `iat`가 미래라며 거부한다. 로그인 직후 `GET /users/me`가 401이 되면 앱은 닉네임 화면 판단 없이 홈으로 간다. `leeway=30` 한 줄과 `test_rejects_expired_token` 여유 조정을 요청했다 |

### 백엔드 API 공백 (2026-09-07 화면 재구성에서 드러남)

| 항목 | 자리 | 내용 |
|---|---|---|
| 캐릭터 정보수정 3필드 | `plant_edit_info_screen.dart` | 장소(별명)·마지막 물 준 날·분갈이 한 날(2555:661)은 UI만 있고 저장 API가 없다. 화면 안 상태로만 남는다 |
| 성격 수정 | `plant_detail_screen.dart` `PlantPersonalityScreen` | `personality_type` PATCH가 없어 '수정하기'를 잠가 뒀다 |
| 헤어 탭 아이템 | `plant_edit_appearance_screen.dart` | `hair_id` 값 목록과 아이템 PNG 5장(2568:1857~1861)이 없다 |
| 식물별 캐릭터 그림 | 알림 타일·내 캐릭터 격자·상세 | `personalityType`/`colorId`별 에셋이 없어 `PlantCharacterArt` 하나로 그린다 |
| 가지치기 일정 | `calendar_new_event_sheet.dart` | 시안 시트는 분갈이·비료뿐이라 PRUNING 생성 경로가 닫혔다. 필요하면 시안 확인 |

## 편지 API 연동 후 정리

### 실제 편지 API 연결 후 개발용 미리보기 제거 (2026-09-10)

- [x] `PlantLetterRepository`/`LetterApi` 및 홈 연결: 식물별 목록·상세·읽음·삭제 API.
- [ ] 실제 편지로 NEW 분기, 당겨오기 → 열기 → 펼치기, 읽음 저장·재시도 확인.
- [ ] 위 검증 완료 후 ‘편지 모션 미리보기’ 버튼·격리된 샘플 편지·미리보기 전용 테스트 제거. 실제 편지 모션과 회귀 테스트는 유지.

현재 API 라우트와 앱 연결이 있고, 편지 생성 기능이 활성화된 경우 다이어리
생성·수정 경로에서 `reserve_letter`를 호출한다. 다만 worker의
`UnconfiguredLetterSensorSummary`가 `LETTER_SENSOR_NOT_CONFIGURED`를 발생시켜
실제 편지 생성·수신 E2E는 미검증 상태다. 따라서 미리보기는
`kDebugMode`에서 계속 표시하며 서버에 저장하지 않는다.
수정 위치: `frontend/lib/screens/mailbox_screen.dart`, `frontend/test/mailbox_test.dart`.
상세: [우편함 구현 문서](frontend/docs/mailbox.md).

## 디자이너 확인 대기

| 항목 | 자리 | 내용 |
|---|---|---|
| 빈 칸 눈 아이콘 | `login_credentials_form.dart:146` | 로그인(2395:31)은 빈 칸에도 눈을 그리는데 회원가입(2395:40)은 값이 있을 때만. 어느 쪽이 맞는지 |
| 처방 카드 장식 | `diagnosis_components.dart:81` | 카드 상단 빨간 탭, 십자, 원형 글리프가 시안에 비어 있음 |
| 막대 폭 불일치 (진단) | `diagnosis_components.dart:366` | 76% 라벨에 85% 폭 |
| 홈 환경 센서 API | `home_screen.dart` | Figma 예시 수치(습도 43%, 조도 10%)는 제거함. 실제 센서 API가 정해지면 게이지를 다시 연결 |
| 화분·위치 입력 | `plant_register_environment_screen.dart` | 시안에 선택 UI가 없어 값을 비워 보낸다 |
| 사진 인식 거절 후 | `plant_photo_identify_screen.dart` | '아니에요'를 누른 뒤 화면이 시안에 없어 검색으로 되돌림 |
| 애플 로그인 | 로그인 화면 | 시안 소셜 버튼 세 번째 검정 원. 애플이면 로고 에셋 필요 |
| 약관 4개가 같은 이름 | `onboarding_overlays.dart:179` | `(필수) 서비스 약관` × 4, 꺾쇠를 눌러도 안 열림 |

---

## 디자이너 에셋 대기

시안에는 있는데 그릴 그림이 없어 미룬 것들. 노드가 아니라 **에셋 파일**이
필요하다.

### 성격 캐릭터 6종 표정

`lib/screens/plant_register_personality_screen.dart`

시안(`3369:20` 3행)은 성격마다 캐릭터 표정이 다르다. 지금은
`PlantCharacterArt` 하나를 여섯 번 재사용해 전부 같은 얼굴이다.

| 성격 | 시안 표정 |
|---|---|
| 활발한 (OUTGOING) | 웃음 |
| 시크한 (CHIC) | 찡그림 |
| 귀여운 (CUTE) | 윙크 |
| 소심한 (INTROVERTED) | 놀람 |
| 짝사랑 (CRUSH) | 볼터치 |
| 충청도 (CHUNGCHEONG) | 실눈 |

이름·태그·대사는 2026-09-07에 시안 글자 그대로 맞췄다.

**필요한 것:** 표정별 PNG 6장
**고칠 자리:** `PlantCharacterArt`에 성격을 넘겨 에셋을 고르게 하면 된다.

### 꾸미기 아이템 탭

`lib/screens/plant_register_appearance_screen.dart`

시안 두 번째 꾸미기 화면은 **식물 아이템**(선인장·하트 화분 등)을 캐릭터
머리에 올린다. 코드의 두 번째 탭은 '헤어'이고 "헤어 꾸미기는 준비 중이에요"
문구만 있다.

**필요한 것:** 아이템 PNG와 캐릭터 위 합성 규칙(위치·크기)
**함께 확인:** 탭 이름이 '헤어'가 맞는지, 아니면 '아이템'인지

---

## 기타

- **PR #56 열림** (2026-09-11) — `frontend/feat-plant-registration` → `main`, 50커밋.
  디자이너 수정분은 같은 브랜치에 이어 올린다.
