# TODOLIST

미뤄 둔 일을 한곳에 모은다. "지금 TODO 뭐 있지?" 하면 이 파일을 본다.

코드 안의 `TODO(1-E)` / `TODO(design)` 주석과 짝을 이룬다 — 주석은 고칠
자리를, 이 파일은 왜 미뤘고 무엇이 풀려야 시작할 수 있는지를 적는다.

---

## 백엔드 연동 대기 (`dio` 미도입)

### 식물 종 검색이 더미 6종이다 ⚠️ 등록 불가

`lib/screens/plant_species_search_screen.dart:26-63`

바질 · 몬스테라 · 스킨답서스 · 방울토마토 · 백담청잎장 · 베르가못 여섯 개가
하드코딩돼 있다. **이 목록 밖의 식물을 키우는 사용자는 등록을 끝낼 수 없다** —
검색해도 "검색 결과가 없어요"만 뜬다.

`referenceId`(`catalog:ocimum-basilicum` 같은 값)는 지어낸 것이고,
`POST /plants`의 `species_reference_id`로 그대로 흘러간다.

**필요한 것:** `GET /plant-species/search?query=`
**고칠 자리:** 같은 파일 `_search()` 함수 내부만 교체하면 된다.

### 나머지 API 자리

| 화면 | 필요한 API |
|---|---|
| `plant_register_complete_screen.dart` | `POST /plants` — 지금은 `user_metadata`에 임시 저장 |
| `plant_photo_identify_screen.dart` | 사진 AI 인식 — 지금은 시안 값(바위채송화)을 그대로 돌려줌 |
| `edit_profile_screen.dart` | `PATCH /users/me` (닉네임) |
| `oauth_nickname_screen.dart` | `PATCH /users/me` (닉네임) |
| `my_page_screen.dart` | `GET /users/me` — 알림 토글 초기값, 변경 저장 |
| `withdraw_screen.dart` | `DELETE /users/me` — 지금은 로그아웃만 |

식물 등록과 닉네임은 `user_metadata`에 임시로 넣어 두어 흐름은 지금도
끝까지 돈다. 서버가 붙으면 그 자리만 갈아끼운다.

---

## 팀 확인 대기

### 소셜 신규 가입자를 구분할 방법이 없다

`lib/main.dart:89`

카카오·네이버로 **처음** 가입한 사용자는 닉네임이 없어 닉네임 설정 화면으로
보내야 하는데, 프론트가 "신규 가입 vs 재로그인"을 구분할 수단이 없다.
`GET /users/me`에 `profile_completed` 같은 플래그가 없다 (2026-08-11 문의).

지금은 전부 홈으로 보낸다 → 소셜 신규 가입자는 마이페이지에서 "식집사님"으로
보인다.

---

## 디자이너 확인 대기

| 항목 | 자리 | 내용 |
|---|---|---|
| 빈 칸 눈 아이콘 | `login_credentials_form.dart:146` | 로그인(2395:31)은 빈 칸에도 눈을 그리는데 회원가입(2395:40)은 값이 있을 때만. 어느 쪽이 맞는지 |
| 처방 카드 장식 | `diagnosis_components.dart:81` | 카드 상단 빨간 탭, 십자, 원형 글리프가 시안에 비어 있음 |
| 막대 폭 불일치 (진단) | `diagnosis_components.dart:366` | 76% 라벨에 85% 폭 |
| 막대 폭 불일치 (홈) | `home_components.dart:101` | '현재조도 10%'인데 막대는 17.7% |
| 화분·위치 입력 | `plant_register_environment_screen.dart` | 시안에 선택 UI가 없어 값을 비워 보낸다 |
| 인증코드 칸 | `change_password_screen.dart` | 시안에 없어 임시로 넣음. 자리를 잡아 주면 좌표 맞춤 |
| 사진 인식 거절 후 | `plant_photo_identify_screen.dart` | '아니에요'를 누른 뒤 화면이 시안에 없어 검색으로 되돌림 |
| 애플 로그인 | 로그인 화면 | 시안 소셜 버튼 세 번째 검정 원. 애플이면 로고 에셋 필요 |
| 약관 4개가 같은 이름 | `onboarding_overlays.dart:179` | `(필수) 서비스 약관` × 4, 꺾쇠를 눌러도 안 열림 |

---

## 화면이 없는 컴포넌트

만들어 두고 아직 화면에 못 붙인 것들. 시안 노드를 받으면 붙일 수 있다.

- **진단** — `DiagnosisEmptyState`, `DiagnosisRecordTile`, `PrescriptionCard`, `PrescriptionCause` (450줄)
- **홈 게이지** — `EnvironmentGauge`, `PlantRequestBubble` (251줄)
- **사진 검색** — `PlantResultCard`, `PlantResultConfirmButtons`, `CameraViewfinderOverlay`
- **다이어리** — 시안만 봤고 컴포넌트도 아직 없음

하단 네비바의 기록 · 달력 탭은 아직 눌러도 아무 일도 없다.

---

## 기타

- **PR 미개설** — `main`보다 20커밋 앞서 있다. 배선이 끝나면 PR #38을 닫고
  이 브랜치에서 하나로 연다.
