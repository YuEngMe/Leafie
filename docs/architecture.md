# 시스템 아키텍처

## 1. 결정 사항

- Flutter 앱, FastAPI API, Python Worker를 한 저장소에서 관리합니다.
- 인증, PostgreSQL, Storage, Queue, Cron은 Supabase를 사용합니다.
- API와 Worker는 같은 Python 패키지를 사용하지만 별도 프로세스로 배포합니다.
- Docker는 필수가 아니며 배포 환경에서 필요할 때만 추가합니다.
- 식물명칭 사진 인식은 Pl@ntNet, 상태 진단은 교체 가능한 `DiagnosisProvider`를
  사용합니다.
- 실시간 AI 상담은 OpenAI Responses API와 Tool Calling을 사용합니다.
- OpenAI Batch API와 월간 AI 리포트는 현재 MVP에 포함하지 않습니다.

## 2. 전체 구조

```mermaid
flowchart LR
    APP["Flutter 앱"] --> AUTH["Supabase Auth"]
    APP --> API["FastAPI"]
    APP --> STORAGE["Supabase Storage"]
    API --> DB["Supabase PostgreSQL"]
    API --> QUEUE["Supabase Queue"]
    CRON["Supabase Cron"] --> DB
    CRON --> QUEUE
    WORKER["Python Worker"] --> QUEUE
    WORKER --> DB
    WORKER --> STORAGE
    WORKER --> PLANTNET["Pl@ntNet"]
    WORKER --> HEALTH["DiagnosisProvider"]
    API --> OPENAI["OpenAI Responses API"]
    WORKER --> OPENAI
    WORKER --> PUSH["FCM / APNs"]
```

FastAPI는 인증, 소유권, 입력 검증과 짧은 트랜잭션을 담당합니다. 외부 API 호출,
사진 분석, 푸시 발송과 파일 삭제처럼 오래 걸리는 작업은 Queue와 Worker가 담당합니다.

## 3. 인증

지원 방식:

- 인증 링크가 필요한 이메일·비밀번호
- Naver Custom OAuth2
- Kakao OAuth
- Apple OAuth

Google 로그인은 지원하지 않습니다. 이메일 가입의 닉네임은 Supabase 사용자 메타데이터
`leafie_nickname`으로 전달합니다. OAuth 최초 로그인은 프로필의
`profile_completed_at`이 null이면 앱에서 닉네임 입력 화면을 거칩니다.

비밀번호 찾기와 변경은 Supabase가 이메일 링크를 발송하고, 링크가 앱 딥링크로 돌아온
뒤 앱에서 새 비밀번호를 입력하는 방식입니다. FastAPI는 비밀번호를 받거나 저장하지
않습니다.

App Store 출시 전 확인 항목:

- Apple 로그인 실기기 검증
- Apple 비공개 릴레이 이메일 처리
- OAuth 딥링크와 취소·실패 화면
- 운영 SMTP와 인증·재설정 링크 만료
- 회원 탈퇴와 최근 재인증

## 4. 저장소와 이미지

- Storage 버킷 `leafie-media`는 비공개입니다.
- 앱은 FastAPI에서 Signed Upload URL을 받은 뒤 Storage에 직접 업로드합니다.
- 업로드 완료 후 FastAPI가 크기, 형식, 소유권과 용도를 검증합니다.
- 조회 시 짧게 만료되는 Signed Download URL을 발급합니다.
- EXIF 위치 정보는 제거합니다.
- 등록 인식 사진은 같은 `media_file_id`를 식물 대표 사진으로 재사용합니다.
- 다이어리 사진은 최대 한 장, 진단 사진은 정확히 한 장입니다.
- 지원 형식은 JPEG와 PNG이며 HEIC는 앱에서 JPEG로 변환합니다.

## 5. Queue와 Worker

```mermaid
sequenceDiagram
    actor U as 사용자
    participant A as Flutter
    participant API as FastAPI
    participant DB as PostgreSQL
    participant Q as Supabase Queue
    participant W as Worker
    participant K as Kindwise plant.id

    U->>A: 사진 진단 요청
    A->>API: plant_id, media_file_id
    API->>DB: diagnosis PENDING 생성
    API->>Q: diagnosis_id enqueue
    API-->>A: 202 Accepted
    W->>Q: 작업 수신
    W->>DB: PROCESSING 원자적 전환
    W->>W: 해상도·밝기·선명도 검사
    W->>K: health_assessment 사진 한 장
    K-->>W: 건강 상태·원인 확률·관리법
    W->>DB: 결과와 COMPLETED 저장
    W->>Q: 메시지 archive
```

Queue payload에는 `job_type`, `resource_id`, 추적 ID만 넣습니다. 원본 사진, 사용자
대화와 API Key는 넣지 않습니다. Worker는 DB에서 최신 상태를 다시 읽습니다.

Worker 작업:

- Pl@ntNet 식물명칭 사진 인식
- 사진 상태 진단
- 채팅 사진 처리
- 푸시 발송
- Storage 및 계정 삭제

실서비스에서는 Kindwise plant.id v3를 진단 Provider로 사용합니다. Fake Provider는
외부 호출 없이 상태 전이와 실패 처리를 검증하는 테스트에서만 사용합니다.

사진 진단은 Kindwise plant.id v3를 사용합니다. Worker는 JPEG·PNG·WebP를 디코딩해
긴 변을 최대 1600px로 축소하고 JPEG로 변환한 뒤 전송합니다. 로컬 품질 검사 실패나
Kindwise의 식물 미검출은 `NEEDS_RETAKE`, 인증·입력 오류는 `FAILED`, timeout·429·5xx는
재시도 대상으로 저장합니다. 진단 결과는 관찰 항목, 원인 최대 3개와 Provider 확률,
비화학적 관리·예방 항목으로 정규화합니다. 별도 LLM 호출로 확률을 만들지 않습니다.

작업은 리소스 ID를 멱등성 키로 사용합니다. 일시 오류는 지수 backoff로 재시도하고,
영구 오류나 최대 재시도 초과는 실패 코드를 저장한 뒤 메시지를 archive합니다.

## 6. 식물 등록

```text
애칭 입력
→ 지원 23종 검색 또는 사진 한 장 인식
→ 후보 확인
→ 함께한 시작일과 환경 입력
→ 마지막 물주기 정보로 최초 물주기 일정 계산
→ 알려진 마지막 분갈이 날짜는 완료 이력으로 저장
→ 성격 선택
→ 컬러·헤어·장식 선택
→ 식물, 일정, 첫 대화 세션을 트랜잭션으로 생성
```

사진 인식 후보는 Pl@ntNet 결과를 GBIF ID 우선, 학명 차순으로 내부 23종과 매칭합니다.
사진 인식에 사용한 사진은 대표 사진으로 재사용하고 검색 등록은 대표 사진 없이
등록합니다. 대분류 7개는 사용자가 선택하지 않고 선택한 종에서 파생합니다. 등록 중
임시저장은 Flutter 로컬 저장소에서 처리하며 서버 초안 테이블을 만들지 않습니다.
Flutter는 등록 흐름마다 `client_registration_id` UUID를 생성하고 성공 응답을 받을 때까지
유지합니다. FastAPI는 사용자 프로필 행 잠금, `(user_id, client_registration_id)` unique,
요청 해시를 함께 사용합니다. 같은 키와 같은 요청의 재전송은 최초 식물 ID와 생성 시각을
반환하고, 같은 키를 다른 요청에 재사용하면 `409`로 차단합니다. 따라서 모바일 네트워크
재시도와 동시 요청에서도 식물, 일정과 첫 대화 세션은 한 번만 생성됩니다.

## 7. 관리 일정

- 자동 반복은 물주기와 분갈이를 지원합니다.
- 식물 등록 시 `KNOWN` 분갈이는 입력 날짜, `NEVER`는 사용자가 입력한 `started_on`을
  기준으로 종별 분갈이 주기를 적용합니다. `UNKNOWN`은 최초 일정을 만들지 않습니다.
- 최초 분갈이 예정일이 이미 과거이면 주기 단위로 더해 오늘 이후의 첫 예정일로
  이동합니다.
- 비료와 가지치기는 사용자 또는 AI 추천으로 만드는 일회성 일정입니다.
- 홈의 자유 할 일도 일회성 `CUSTOM` 이벤트입니다.
- 홈 메모는 완료할 수 없는 날짜별 메모이며 관리 이벤트와 분리합니다.
- 홈 메모는 사용자 시간대의 오늘만 작성·수정·삭제할 수 있고 본문은 `1~500자`입니다.

관리 완료에는 두 시각을 구분합니다.

- `performed_on`: 사용자가 실제로 관리한 날짜
- `recorded_at`: 서버가 완료 요청을 받은 시각

오늘 완료는 서버의 사용자 시간대 날짜를 `performed_on`으로 사용합니다. 체크를 잊은
경우 과거 날짜를 선택할 수 있지만 미래 날짜는 허용하지 않습니다. 다음 물주기와
분갈이 날짜는 `performed_on + interval_days`로 계산합니다.

반복 규칙은 `care_schedules`, 각 회차는 `care_events`로 관리합니다. enabled 반복 규칙은
미완료 `SCHEDULED` 이벤트를 정확히 하나 유지합니다. 완료 시 현재 이벤트, schedule의
`next_due_date`, 다음 `SCHEDULED` 이벤트를 한 트랜잭션에서 갱신합니다. 사용자가 만드는
일회성 일정은 오늘·미래만 허용하고 `client_event_id`와 요청 해시로 재전송을 멱등하게
처리합니다.

`TODAY`와 `OVERDUE`는 DB 상태로 반복 저장하지 않고 `due_date`와 사용자 시간대의
오늘을 비교해 계산합니다. 식물 등록 시 과거인 최초 분갈이 예정일만 주기 단위로
보정하며, 이후 반복 일정 갱신 방식은 관리 일정 기능에서 동일한 정책으로 구현합니다.

## 8. 홈·캘린더·다이어리

- `user_profiles.selected_plant_id`가 홈, 캘린더, 다이어리와 AI의 기본 식물입니다.
- 홈은 선택 식물의 오늘 일정만 보여줍니다.
- 상세 화면은 지연, 오늘, 미래 일정만 보여주며 완료 이력은 캘린더에서 봅니다.
- 홈 대사는 성격, 오늘 컨디션과 일정 상태에 맞는 고정 문구 중 하나를 선택합니다.
- 다이어리는 식물별 하루 한 개이며 `1~2,000자` 글과 다섯 컨디션 점수 중 하나가
  필수이고 사진은 최대 한 장입니다.
- 컨디션 점수는 `0`, `25`, `50`, `75`, `100`만 저장하며 단계는 중복 저장하지 않습니다.
- 과거와 오늘 다이어리를 작성·수정·삭제할 수 있고 미래 작성은 불가합니다.
- 수정 요청에서 사진 필드 생략은 유지, null은 제거, 새 UUID는 교체를 의미합니다.
- 다이어리 사진 UUID는 한 다이어리에서만 사용합니다. 제거·교체·다이어리 삭제 시
  미디어를 soft delete하고 같은 DB 트랜잭션에서 Storage 삭제 작업을 Queue에 넣습니다.
- 월별 컨디션은 해당 월 점수 평균을 SQL로 계산하고 반올림한 정수와 5단계를 반환합니다.

컨디션 5단계:

```text
0=1, 25=2, 50=3, 75=4, 100=5
```

월평균 단계 경계는 `12.5`, `37.5`, `62.5`, `87.5`이며 경계값은 높은 단계에
포함합니다. 기록이 없는 달의 평균 점수와 단계는 null입니다.

## 9. AI 채팅과 Tool Calling

식물별 영구 채팅방은 제품 개념이고 DB에서는 `ai_conversations.plant_id`로 직접
표현합니다. `새 채팅`은 같은 식물에 새 대화 세션을 만듭니다. 모델 입력은 해당
세션의 최근 메시지와 누적 요약으로 제한합니다. AI 채팅은 식물 캐릭터의 성격과
무관하게 `AI 식물박사 똑똑이`의 일관된 말투를 사용합니다. 성격별 말투는 홈 대사와
푸시 알림 문구에만 적용합니다.

읽기 Tool 예시:

- 식물 기본 정보
- 종별 관리 가이드
- 환경
- 오늘 및 예정 일정
- 최근 관리 이력
- 최근 다이어리 컨디션
- 최근 진단

`user_id`와 `plant_id`는 모델 인자를 신뢰하지 않고 서버가 주입합니다. Tool 인자는
Pydantic으로 검증하며 호출 결과는 최소 감사 정보만 저장합니다.

AI가 비료나 가지치기 일정을 제안하면 `AI_ACTIONS`를 생성합니다. 사용자 승인 전에는
업무 데이터를 변경하지 않습니다. 물주기 반복 주기는 AI가 변경하지 않습니다.

## 10. 사진 진단

진단 입력:

- 사진 정확히 한 장
- 식물 종과 환경
- 최근 물주기·분갈이 이력
- 내부 종별 관리·진단 가이드

일반 채팅 전체는 진단 모델 입력으로 사용하지 않습니다. 대화 ID는 진단을 시작한
화면으로 돌아가기 위한 연결 정보입니다.

진단 단계:

1. 식물 존재, 흐림, 밝기와 증상 부위 노출 검사
2. `DiagnosisProvider` 호출
3. Provider 응답을 내부 schema로 표준화
4. 내부 관리 규칙으로 추천 관리 생성
5. LLM이 한국어 설명만 생성
6. 채팅 결과 카드, 진단 이력과 푸시 알림 생성

진단표는 사진, 진단 일자, 상태 문구, 관찰 증상, 원인 TOP 3와 추천 관리만 표시합니다.
건강점수, 단일 AI 신뢰도와 진단 점수 그래프는 만들지 않습니다. 원인 확률은 전문
Provider가 반환한 값만 사용합니다.

`DiagnosisProvider`와 사진 품질 검사기는 교체 가능한 계약으로 분리합니다. 표준 결과는
관찰 증상, 전체 상태, 원인 최대 3개와 Provider 메타데이터만 포함하며 추천 관리는
내부 규칙이 생성합니다. Fake 구현은 테스트에서 Worker의 완료, 재촬영, 영구 실패와
재시도 상태 전이만 검증합니다.

## 11. 알림

- FCM/APNs 앱 푸시만 지원합니다.
- 이메일과 SMS 관리 알림은 보내지 않습니다.
- 전체 푸시 ON/OFF는 `user_profiles.push_enabled` 한 값으로 관리합니다.
- 앱 내 알림함은 모든 식물의 발송 이력과 읽음 상태를 보여줍니다.
- 기기별 토큰은 `device_tokens`에서 관리하고 로그아웃 또는 권한 철회 시 폐기합니다.

## 12. 배포와 운영

배포 프로세스:

```text
API: uvicorn app.main:app
Worker: python -m app.worker
```

필수 운영 항목:

- API와 Worker의 health check
- 요청·작업 추적 ID
- 외부 Provider 지연 시간, 오류율과 비용
- Queue 적체량과 재시도 횟수
- DB 백업과 Alembic migration
- 비밀값 환경변수 관리
- 사용자별 rate limit

## 13. 역할

- 백엔드 A: Auth, 사용자, 식물·캐릭터, 다이어리, 관리 일정, 홈·캘린더
- 백엔드 B: Storage, Queue·Worker, 식물 인식, 진단, AI 채팅, Tool Calling, 푸시 발송
- 공통: ERD, API 계약, migration, RLS, CI와 배포 설정
