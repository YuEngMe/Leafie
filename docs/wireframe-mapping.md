# 와이어프레임 1:1 매핑

기준은 2026-07-23에 전달된 와이어프레임 12개 화면군과 이후 확정한 규칙입니다.
`API`는 [API 명세](api-spec.md), `DB`는 [ERD](erd.md)를 가리킵니다.

## 화면별 매핑

| 화면 | 확정 UI 및 동작 | API | DB 또는 계산 | 상태 |
|---|---|---|---|---|
| 스플래시·앱 소개 | 로고, 소개, 시작하기 | 없음 | 로컬 화면 | 일치 |
| 로그인 | 이메일·비밀번호 로그인 또는 카카오 로그인, 이메일 계정은 인증 완료 필수 | Supabase Auth SDK `signInWithPassword`, `signInWithOAuth(kakao)` | `auth.users`, `auth.identities` | 카카오 로그인 버튼과 오류 상태 추가 필요 |
| 이메일 인증 | 가입 후 인증 완료 전 Supabase 세션 발급과 로그인 차단 | Supabase Auth `signUp`, `resend` | `auth.users.email_confirmed_at` | 문서 있음, 화면 누락 |
| 카카오 OAuth 복귀 | 카카오 동의 후 앱 deep link 복귀, 세션 확인, 이메일 미제공·취소·실패 처리 | Supabase Auth SDK | `auth.users`, `auth.identities` | 화면 흐름 추가 필요 |
| 식물 등록 | 식물명칭 필수, 이름 검색 또는 사진 인식 후보 중 하나 선택, 7개 종류 중 선택, 애칭 필수, 함께한 시작일 | `/plant-species/search`, `/plant-species/identifications`, `POST /plants` | `SPECIES_IDENTIFICATIONS`, `PLANTS` | 일치 |
| 캐릭터 만들기 | 색·머리·장식 선택, 6개 성격 중 하나 | `/character-options`, `PATCH /plants/{id}/character` | `PLANT_CHARACTERS` | 일치 |
| 환경 등록 | 장소 별명, 화분, 위치, 마지막 물주기, 마지막 분갈이 | `POST /plants`, `PATCH /plants/{id}/environment` | `PLANT_ENVIRONMENTS`, `CARE_SCHEDULES`, `CARE_EVENTS` | 일치 |
| 홈·캐릭터 방 | 식물 전환, D+일, 캐릭터 대사, 오늘 다이어리의 읽기 전용 컨디션 아이콘, 알림 수 | `GET /home`, `/users/me/selected-plant` | 선택 식물, 오늘 다이어리, 관리 이벤트 집계 | 일치 |
| 내 캐릭터 전체보기 | 소유 식물 목록, 식물 추가, 캐릭터 방 이동 | `GET /plants`, `POST /plants` | `PLANTS`, `PLANT_CHARACTERS` | 일치 |
| 캐릭터·식물 수정 | 식물 정보 수정과 꾸미기를 별도 진입 | `PATCH /plants/{id}`, `/character`, `/environment` | 각 식물 하위 테이블 | 문서 일치, 화면 흐름 구분 필요 |
| 컨디션 아이콘 | 기록된 아이콘은 동작 없음. 오늘 다이어리가 없을 때만 빈 아이콘을 누르면 작성 화면으로 이동 | `GET /home` | `PLANT_DIARIES.condition_level` | 일치 |
| 캘린더 월간 | 선택 식물, 월 이동, 물주기·분갈이·비료·컨디션·가지치기 필터, 날짜 상세 | `GET /plants/{id}/calendar` | 컨디션·관리 이벤트·다이어리 집계 | 일치 |
| 캘린더 할 일 | 이번 주 할 일, 다음 관리 일정, 완료 체크 | `/plants/{id}/agenda`, `/care-events/{id}/complete` | `CARE_SCHEDULES`, `CARE_EVENTS` | 일치 |
| 관리 자동화 | 물주기·분갈이만 반복, 미완료는 지연 유지, 완료 요청의 서버 시각 기준으로 다음 일정 생성 | 관리 일정 API | Scheduler와 관리 테이블 | 일치 |
| 다이어리 달력 | 식물별 작성 날짜 표시, 월별 다이어리 컨디션 평균과 아이콘 | 다이어리 목록, `/diary-stats` | 다이어리 존재 여부와 컨디션 평균 | 일치 |
| 다이어리 작성·상세 | 식물별 하루 한 개, 글·5단계 컨디션 필수, 사진 한 장 선택 | `PUT /plants/{id}/diaries/{date}` | `PLANT_DIARIES` | 일치 |
| AI 대화 | 한 대화에 식물 한 개 태그, 사진 한 장 첨부, Tool Calling으로 식물·관리 기록 조회 | `/ai-chats`, `/ai-chats/{id}/messages` | `AI_CHATS`, `AI_MESSAGES`, `AI_TOOL_CALLS` | 일치 |
| AI 변경 제안 | 진단 기반 비료·가지치기 일회성 일정만 사용자 확인 후 추가 | `/ai-actions/{id}/confirm`, `/cancel` | `AI_ACTIONS` | 확인 UI 추가 필요 |
| AI 진단 | AI 채팅에서 현재 식물의 사진 한 장으로 비동기 진단, 품질 검사·전문 진단 API·관리 규칙·LLM 설명, 분석 중·재촬영·실패·완료 상태 | `POST /plants/{id}/diagnoses`, `/diagnoses/{id}` | `DIAGNOSES`, `DIAGNOSIS_IMAGES`, `AI_MESSAGES` | 구조 확정, 디자인 미정 |
| 진단표 메인 | 현재 식물의 최근 진단 요약과 전체 진단 기록을 최신순 목록으로 표시, 기록 선택 시 상세 이동 | `GET /plants/{id}/diagnoses` | `DIAGNOSES`, `DIAGNOSIS_IMAGES` | 구조 확정, 디자인 미정 |
| 진단 상세 | 원본 사진, 종합 상태, 요약, 관찰 증상, 의심 원인 TOP 3와 원인별 확률, 즉시 조치, 피해야 할 행동, 예방법, 재진단 권장일, 관련 채팅 이동 | `GET /diagnoses/{id}` | `DIAGNOSES`, `DIAGNOSIS_IMAGES`, `AI_MESSAGES` | 구조 확정, 디자인 미정 |
| 월간 AI 리포트 | 지난달 컨디션·관리 요약과 다음 달 권장 사항 | `/plants/{id}/monthly-reports`, `/monthly-reports/{id}` | OpenAI Batch, `MONTHLY_REPORTS` | 화면 추가 필요 |
| 대화 목록 | 제목·날짜·검색·새 채팅 | `GET /ai-chats?query=`, `POST /ai-chats` | `AI_CHATS` | MVP에서 설정 버튼 제거 |
| 마이페이지 | 프로필 사진, 닉네임, 한 줄 소개, 이메일, 식집사 일수 | `/users/me` | `USER_PROFILES`, `auth.users` 가입일 | 일치 |
| 계정·알림 설정 | 정보 수정, 이메일 확인, 비밀번호 변경, 로그아웃, 탈퇴, 알림 설정 | FastAPI 사용자 API + Supabase Auth SDK | `USER_PROFILES`, Supabase Auth, 알림 설정 | 일치 |
| 알림함 | 앱 내 알림 목록과 읽음 처리 | `/notifications*` | `NOTIFICATIONS` | 문서 있음, 화면 누락 |

## 식물 컨텍스트 규칙

1. 캐릭터 방으로 들어가면 해당 식물을 `selected_plant_id`로 저장합니다.
2. 홈·캘린더·다이어리의 최초 표시 대상은 선택 식물입니다.
3. 각 조회와 수정 요청에는 선택 상태와 별개로 `plant_id`를 명시합니다.
4. 새 AI 대화의 기본 태그는 선택 식물이지만 사용자가 생성 전에 바꿀 수 있습니다.
5. 대화 생성 후 `plant_id`는 변경할 수 없고, 다른 식물을 상담하려면 새 대화를 만듭니다.

## 컨디션 점수 규칙

| 단계 | 저장 점수 | 평균 점수 아이콘 구간 |
|---|---:|---|
| `VERY_BAD` | 10 | 0~19 |
| `BAD` | 30 | 20~39 |
| `NORMAL` | 50 | 40~59 |
| `GOOD` | 70 | 60~79 |
| `VERY_GOOD` | 90 | 80~100 |

월별 통계는 그 달에 작성된 다이어리 컨디션 점수의 산술 평균입니다. 다이어리를
쓰지 않은 날은 0점으로 넣지 않고 제외하며, 한 달 전체에 다이어리가 없으면
평균과 아이콘을 표시하지 않습니다.

## 와이어프레임에서 수정할 점

1. 로그인 화면의 `아이디`와 `아이디 찾기`를 `이메일`과 `비밀번호 재설정`으로 바꾸고 카카오 로그인 버튼을 추가합니다.
2. 홈 화면 하단 탭은 `달력`이 아니라 `홈`이 선택된 상태여야 합니다.
3. 환경 등록의 `마지막 물 준 날`과 `분갈이 언제` 입력값에 식물 이름이 들어간 예시를 실제 날짜로 바꿉니다.
4. `정보 수정`은 식물·환경 수정으로, `꾸미기`는 캐릭터 외형·성격 수정으로 화면을 분리합니다.
5. 진단표의 막대그래프와 `건강점수 67점`을 제거하고 최근 진단과 날짜별 진단 기록 목록으로 교체합니다.
6. 캘린더의 `컨디션` 필터는 진단 결과가 아니라 사용자가 매일 기록한 컨디션을 표시합니다.
7. 대화 목록의 `설정` 버튼은 정의된 기능이 없으므로 MVP에서는 제거합니다.

## 추가로 필요한 화면

- 회원가입, 이메일 인증, 비밀번호 재설정, 카카오 OAuth 복귀·취소·오류
- App Store 제출 전 Sign in with Apple 및 이메일 비공개 계정 처리
- 다이어리 작성·수정 폼과 중복 작성 시 기존 기록 편집 처리
- 관리 주기 추가·수정
- 진단 사진 촬영, 업로드, 분석 중, 재촬영, 실패, 결과 상세
- AI 변경 제안 확인·취소
- 월간 AI 케어 리포트 목록·상세
- 알림함
- 식물·다이어리·대화·계정 삭제 확인
- 주요 화면의 빈 상태, 로딩, 네트워크 오류 상태

## AI 진단 이력 와이어프레임 구조 참고안

![AI 진단 이력 및 상세 화면 구조 참고](assets/ai-diagnosis-history-wireframe-reference.png)

- 왼쪽은 현재 식물의 최근 진단과 전체 진단 기록을 보여주는 메인 화면입니다.
- 오른쪽은 선택한 진단의 사진, 상태, 증상, 원인별 확률과 조치를 보여주는 상세 화면입니다.
- 단일 AI 신뢰도와 식물 건강점수는 표시하지 않으며 제공자가 반환한 원인별 확률만 표시합니다.
- 이 이미지는 화면 구성과 정보 우선순위를 확인하기 위한 참고 자료입니다.
- 색상, 폰트, 아이콘, 간격, 컴포넌트 형태와 캐릭터 표현은 최종 디자인이 아닙니다.
