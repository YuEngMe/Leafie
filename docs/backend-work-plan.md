# 백엔드 작업 계획

## 1. 역할

| 담당 | 범위 |
|---|---|
| 백엔드 A | Auth·프로필, 식물·캐릭터, 다이어리, 관리 일정, 홈·캘린더 |
| 백엔드 B | Storage, Queue·Worker, 식물 사진 인식, 진단, AI 채팅, Tool Calling, 푸시 발송 |
| 공통 | API 계약, ERD, migration·RLS, CI, 배포와 통합 테스트 |

공통 기반은 숙련 담당자가 먼저 정리하되 기능 코드는 각 담당자가 소유합니다. 공통
변경은 반드시 다른 백엔드 담당자의 PR 리뷰를 받습니다.

## 2. 작업 순서

| 순서 | 브랜치 | 담당 | 완료 조건 |
|---:|---|---|---|
| 1 | `backend/feat-project-foundation` | 공통 | FastAPI, 설정, DB 세션, 오류·로깅, health |
| 2 | `backend/feat-auth-profile` | A | Supabase JWT, 프로필, 닉네임, 선택 식물, 탈퇴 |
| 3 | `backend/feat-media-storage` | B | Signed upload/download, 소유권, 비공개 버킷 |
| 4 | `backend/feat-queue-worker` | B | Queue 소비, 재시도, heartbeat, 멱등성 |
| 5 | `backend/feat-species-identification` | B | 23종 검색, Pl@ntNet 인식, 후보 확정 |
| 6 | `backend/feat-plant-registration` | A | 최종 등록 트랜잭션, 환경·성격·외형, 최초 일정 |
| 7 | `backend/feat-diary-condition` | A | 날짜별 다이어리, 사진 한 장, 0~100 점수, 월 평균 |
| 8 | `backend/feat-care-schedule` | A | 반복 일정, 소급 완료, 일회성 일정, 홈 메모 |
| 9 | `backend/feat-home-calendar` | A | 홈 통합 조회, 일정 범위 조회, 식물 전환·삭제 |
| 10 | `backend/feat-diagnosis` | B | 사진 한 장 진단, Provider 표준화, 이력·상세 |
| 11 | `backend/feat-ai-chat` | B | 식물별 대화 세션, 메시지·사진·요약·검색 |
| 12 | `backend/feat-ai-tool-calling` | B | 읽기 Tool, 감사 로그, 일정 제안 승인·취소 |
| 13 | `backend/feat-notifications` | 공통 | 알림함, 읽음, 전체 푸시 설정, 기기 토큰 |
| 14 | `backend/feat-push-delivery` | B | FCM/APNs Worker와 실패 토큰 폐기 |
| 15 | `backend/test-release-flow` | 공통 | 핵심 E2E, 부하·비용·장애·보안 점검 |

OpenAI Batch API와 월간 AI 리포트 브랜치는 현재 MVP에서 만들지 않습니다.

## 3. 기능별 완료 조건

### Auth·프로필

- 인증 전 이메일 로그인 차단
- Email, Naver, Kakao, Apple identity 검증
- OAuth 신규 사용자의 닉네임 완료 상태
- 닉네임만 수정 가능
- 전체 푸시 ON/OFF
- 최근 재인증 후 비동기 계정 삭제

### 미디어·Worker

- JPEG·PNG와 용도별 크기 제한
- 업로드 완료 전 리소스 연결 차단
- Queue에는 리소스 ID만 저장
- 원자적 상태 선점, visibility heartbeat, 지수 backoff
- 영구 오류와 재시도 소진 분리
- 중복 메시지에서 외부 API 재호출 방지

### 식물 검색·등록

- 내부 23종 이름·별칭 검색
- GBIF ID 우선, 학명 차순 인식 후보 매칭
- 지원하지 않는 후보 제외
- `맞아요`, `다시 검색`, 후보 소진 처리
- 등록 인식 사진을 대표 사진으로 재사용
- 식물·일정·첫 대화 세션을 한 트랜잭션에서 생성

### 다이어리·홈·캘린더

- 식물별 하루 다이어리와 홈 메모 각각 한 개
- 다이어리 본문·0~100 점수 필수, 사진 최대 한 장
- 오늘·과거 작성, 미래 차단, 수정만 허용
- 월 평균은 SQL 집계, 기록 없음은 null
- 홈은 오늘 일정만, 상세는 지연·오늘·미래 일정
- 월·주 범위 조회와 다중 필터

### 관리 자동화

- 물주기·분갈이만 반복
- `performed_on`과 서버 `recorded_at` 분리
- 과거 수행일 허용, 미래 수행일 차단
- 실제 수행일을 기준으로 다음 일정 생성
- 중복 완료 요청 멱등 처리
- 비료·가지치기·자유 할 일은 일회성

### 진단

- 사진 정확히 한 장
- `PENDING`, `PROCESSING`, `COMPLETED`, `NEEDS_RETAKE`, `FAILED`, `CANCELLED`
- 식물 존재·흐림·밝기·증상 부위 품질 검사
- `DiagnosisProvider` 응답을 내부 schema로 표준화
- 관찰 증상, Provider 원인 TOP 3와 추천 관리
- 건강점수와 LLM 생성 확률 금지
- 식물별 최신순 이력과 상세
- Provider·모델·프롬프트·규칙 버전과 비용 기록

### AI 채팅·Tool Calling

- `ai_conversations.plant_id`로 식물별 대화 세션 관리
- 새 채팅, 목록·검색·soft delete
- 텍스트 스트리밍과 사진 비동기 처리
- 최근 메시지와 누적 요약 기반 컨텍스트
- Tool 인자 schema 검증과 서버 식물·사용자 ID 주입
- 읽기 Tool은 즉시 실행
- 비료·가지치기 변경은 사용자 승인 후 실행

### 알림

- 물주기·분갈이·지연·진단 완료 알림
- 모든 식물 알림함과 읽음 처리
- 사용자 전체 푸시 ON/OFF
- 활성 기기 토큰 unique
- 무효 토큰 폐기와 발송 재시도

## 4. 테스트 기준

각 기능 PR은 정상 경로와 함께 다음을 검증합니다.

- 인증 실패와 이메일 미인증
- 다른 사용자의 리소스 접근
- 중복 요청과 잘못된 상태 전이
- 외부 API 일시·영구 실패
- Queue 재전달과 재시도 소진
- 미래 날짜와 날짜 경계
- Storage 업로드 미완료·삭제 실패

공통 PR 병합 전 실행:

```bash
cd backend
ruff check .
pytest
alembic upgrade head
```

## 5. 브랜치와 PR

- 기능 브랜치는 최신 `main`에서 생성합니다.
- 커밋 메시지는 `feat: 한국어 설명`, `fix: 한국어 설명` 형식을 사용합니다.
- 한 PR에는 한 기능 또는 하나의 공통 계약 변경만 포함합니다.
- DB 변경은 ORM, Alembic, ERD와 API 문서를 같은 PR에서 갱신합니다.
- PR 본문에 테스트 결과와 migration 적용 여부를 기록합니다.
