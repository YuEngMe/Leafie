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

- **PR 미개설** — `main`보다 41커밋 앞서 있다. 배선이 끝나면 PR #38을 닫고
  이 브랜치에서 하나로 연다.
