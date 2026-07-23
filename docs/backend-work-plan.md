# 백엔드 기능별 작업 계획

이 문서는 [API 명세](api-spec.md), [ERD](erd.md), [시스템 아키텍처](architecture.md)의
전체 구현 범위를 기능 브랜치로 나눈 작업 기준입니다.

## 역할

| 담당 | 주 책임 |
|---|---|
| 백엔드 A | 사용자·식물·다이어리·관리 일정·홈·캘린더 |
| 백엔드 B | Storage·Queue·Worker·진단·AI·Batch·알림 |
| 공동 | 공통 기반, migration 리뷰, API 계약, 통합 테스트, 배포 |

담당은 코드 소유권을 의미합니다. 모든 PR은 다른 백엔드 담당자가 리뷰합니다.

## 기능 브랜치

| 순서 | 브랜치 | 담당 | 구현 범위 | 선행 작업 |
|---:|---|---|---|---|
| 1 | `backend/feat-project-foundation` | 공동 | 설정, DB session, JWT 검증, 공통 에러, pagination, 소유권 검사, 테스트 fixture, 로깅 | 없음 |
| 2 | `backend/feat-auth-profile` | A | `/users/me`, 프로필 수정, 선택 식물, 사용자 통계, 계정 탈퇴 예약 | 1 |
| 3 | `backend/feat-media-storage` | B | Signed Upload URL, 업로드 완료 검증, Signed Download URL, 파일 삭제 작업 | 1 |
| 4 | `backend/feat-queue-worker` | B | Supabase Queues adapter, Worker loop, visibility timeout, 재시도, 멱등성 | 1 |
| 5 | `backend/feat-species-identification` | B | 식물명칭 검색, 사진 인식 작업, 후보 조회와 선택 검증 | 3, 4 |
| 6 | `backend/feat-plant-character` | A | 식물 CRUD, 캐릭터·성격, 환경, 캐릭터 옵션 | 1, 2, 5 |
| 7 | `backend/feat-diary-condition` | A | 날짜별 다이어리 CRUD, 사진 한 장, 컨디션 점수, 월간 통계 | 3, 6 |
| 8 | `backend/feat-care-schedule` | A | 물주기·분갈이 반복 규칙, 관리 이벤트, 완료·지연, 일회성 일정 | 6 |
| 9 | `backend/feat-home-calendar` | A | 홈 집계, 식물 전환 데이터, 월간 캘린더, agenda, 기간 통계 | 7, 8 |
| 10 | `backend/feat-diagnosis` | B | 사진 1장 진단 생성·조회·재시도·취소·삭제, 비동기 분석 | 3, 4, 6 |
| 11 | `backend/feat-ai-chat` | B | 식물 고정 대화방, 메시지, 검색, 사진 첨부 비동기 처리 | 3, 4, 6 |
| 12 | `backend/feat-ai-tool-calling` | B | 읽기 Tool registry, Tool 실행 loop, 감사 로그, `AI_ACTIONS` 승인·취소 | 8, 10, 11 |
| 13 | `backend/feat-monthly-batch` | B | OpenAI Batch 제출·수집, 월간 AI 리포트 목록·상세 | 4, 7, 8 |
| 14 | `backend/feat-notifications` | B | 기기 토큰, 알림함, 읽음 처리, 알림 설정, FCM/APNs 발송 | 2, 4, 8, 10, 13 |

모든 브랜치는 생성 시점의 `main`에서 시작합니다. 선행 작업이 merge되면 작업
브랜치에서 최신 `main`을 반영한 뒤 구현을 계속합니다.

## 브랜치별 완료 조건

### `backend/feat-project-foundation`

- Supabase JWT의 서명·만료·issuer·audience 검증
- SQLAlchemy async session과 transaction 경계
- 표준 에러 응답과 request ID
- 공통 pagination schema
- 사용자와 식물 소유권 검사 dependency
- pytest, Ruff 실행 환경

### `backend/feat-auth-profile`

- Supabase `auth.users`와 `USER_PROFILES` 연결
- 사용자 프로필 조회·수정
- 선택 식물 소유권 검증
- 가입일 기준 식집사 일수 계산
- 계정 삭제 Queue 작업과 재인증 검사

### `backend/feat-media-storage`

- 목적별 Storage 경로와 MIME·크기 제한
- 비공개 버킷 Signed URL
- 업로드 완료 후 object 검증
- 다른 사용자 파일 참조 차단
- soft delete와 실제 Storage 삭제 분리

### `backend/feat-plant-character`

- 확정된 식물 종류 7개
- 검색 또는 사진 인식에서 선택한 식물명칭 필수
- 선택 출처와 사진 인식 후보의 서버 검증
- 캐릭터 외형과 성격 6개
- 환경과 초기 물주기·분갈이 정보
- 식물 삭제 시 연결 데이터 처리

### `backend/feat-diary-condition`

- 식물별 하루 다이어리 1개 unique
- 글과 컨디션 필수, 사진은 선택 한 장
- 컨디션 단계의 서버 점수 변환
- 작성하지 않은 날을 제외한 월평균
- 오늘 다이어리 유무와 컨디션 조회

### `backend/feat-care-schedule`

- 물주기·분갈이만 자동 반복
- 완료 API의 서버 현재 시각 저장
- 실제 완료일 기준 다음 일정 생성
- 미완료 일정 `OVERDUE` 유지
- 진단 기반 비료·가지치기 일회성 일정

### `backend/feat-home-calendar`

- 선택 식물의 캐릭터 방 집계
- 기록된 컨디션과 빈 아이콘 상태 구분
- 오늘 할 일과 지연 일정을 한 번에 반환
- 월간 캘린더와 주간 agenda
- 날짜별 컨디션 점수 추이

### `backend/feat-queue-worker`

- Queue 메시지 enqueue, read, archive
- visibility timeout과 최대 재시도
- `job_type`, `resource_id`, `trace_id` 계약
- 중복 처리 방지를 위한 멱등성 검사
- 실패 코드와 작업 로그

### `backend/feat-species-identification`

- 이름 검색과 사진 인식이 동일한 후보 응답 계약 사용
- 사진 인식용 `READY` 미디어와 사용자 소유권 검증
- 사진 인식 작업의 Queue 상태 전이와 실패 처리
- 신뢰도 순 후보 제공, 결과 자동 확정 금지
- 검색 또는 완료된 인식 후보를 선택했는지 식물 등록 시 검증

### `backend/feat-diagnosis`

- 진단 사진 정확히 한 장
- `PENDING`부터 종료 상태까지 전이 검증
- 낮은 품질 사진의 재촬영 응답
- 최근 식물·환경·관리 기록을 분석 입력에 포함
- 결과와 모델·프롬프트 버전 저장

### `backend/feat-ai-chat`

- 대화방당 식물 하나 고정
- 대화 목록 검색과 식물 필터
- 텍스트 메시지 실시간 응답
- 사진 메시지 Queue 기반 비동기 처리
- 대화·메시지 소유권 검사

### `backend/feat-ai-tool-calling`

- 읽기 도구 8개 구현과 Pydantic 인자 검증
- `user_id`, `plant_id` 서버 주입
- Tool Call 감사 로그
- 비료·가지치기 일정 제안 카드
- 사용자 승인 전 데이터 변경 금지

### `backend/feat-monthly-batch`

- 식물·월별 JSONL 생성
- OpenAI Batch 제출과 상태 수집
- `custom_id` 기반 결과 매핑
- 식물·연·월 리포트 중복 방지
- 실시간 채팅·진단에서 Batch 사용 금지

### `backend/feat-notifications`

- FCM/APNs 기기 토큰 등록·폐기
- 물주기·분갈이와 지연 알림
- 진단·사진 채팅·월간 리포트 완료 알림
- 알림함과 읽음 상태
- 사용자 설정과 quiet hours

## API 범위 확인

| API 명세 영역 | 담당 브랜치 |
|---|---|
| Supabase Auth·JWT | `backend/feat-project-foundation` |
| 사용자 | `backend/feat-auth-profile` |
| 미디어 | `backend/feat-media-storage` |
| 식물명칭 검색·사진 인식 | `backend/feat-species-identification` |
| 식물·캐릭터·환경 | `backend/feat-plant-character` |
| 홈 | `backend/feat-home-calendar` |
| 다이어리·컨디션 | `backend/feat-diary-condition` |
| 관리 일정 | `backend/feat-care-schedule` |
| 캘린더·통계 | `backend/feat-home-calendar` |
| 사진 진단 | `backend/feat-diagnosis` |
| AI 대화 | `backend/feat-ai-chat` |
| Tool Calling·AI Action | `backend/feat-ai-tool-calling` |
| 월간 리포트·Batch | `backend/feat-monthly-batch` |
| 알림·기기 토큰 | `backend/feat-notifications` |
| Queue·Worker 내부 작업 | `backend/feat-queue-worker` |

이 표의 모든 영역이 구현되고 각 브랜치 완료 조건을 통과하면 현재 백엔드 명세의
기능 범위가 모두 충족됩니다.
