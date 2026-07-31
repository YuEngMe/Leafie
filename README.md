# Leafie

반려식물의 관리 기록, 일정, 상태 변화와 사진 기반 AI 상태 분석을 제공하는 모바일 앱입니다.

## 문서

- [시스템 아키텍처](docs/architecture.md)
- [API 명세](docs/api-spec.md)
- [ERD 및 데이터 정책](docs/erd.md)
- [와이어프레임 1:1 매핑](docs/wireframe-mapping.md)
- [백엔드 기능별 작업 계획](docs/backend-work-plan.md)
- [브랜치·커밋·PR 규칙](CONTRIBUTING.md)

## 저장소 구조

```text
.
├── backend/                  # FastAPI API와 Python Worker
├── frontend/                # Flutter 애플리케이션
├── supabase/                 # DB migration, RLS, Queue, Cron
├── docs/                     # 아키텍처, API, ERD, 화면 매핑
├── CONTRIBUTING.md
└── README.md
```

## MVP 범위

- 인증 메일 기반 이메일 로그인과 Naver·Kakao·Apple 소셜 로그인
- 식물명칭 검색·사진 인식과 반려식물 등록
- 다이어리와 관리 일정 기록
- 물 권장량, 자동 반복 관리와 사용자 자유 할 일
- 월별 캘린더와 상태 통계
- 사진 1장을 이용한 비동기 식물 상태 분석
- 식물별 영구 채팅방, 새 채팅·대화 목록과 Tool Calling 기반 AI 상담
- 식물별 전체 진단 이력과 진단 상세
- 사용자 확인을 거치는 AI 일정 변경 제안
- 푸시 알림을 위한 기기 토큰과 전체 ON/OFF 설정

## 권장 기술 스택

- Frontend: Flutter
- API: FastAPI, Pydantic v2, SQLAlchemy 2.x
- Auth: Supabase Auth (Email/Password, Naver/Kakao/Apple OAuth)
- Database: Supabase PostgreSQL
- Storage: Supabase Storage
- Queue: Supabase Queues (`pgmq`)
- Scheduler: Supabase Cron (`pg_cron`)
- Migration: Alembic
- Background worker: 독립 Python Worker
- AI realtime: OpenAI Responses API + Tool Calling
- Deployment: 같은 저장소에서 FastAPI API와 Worker를 별도 프로세스로 실행

Docker는 필수가 아니며 배포 환경 통일이 필요해질 때 추가합니다. 구현 전
프론트엔드와 백엔드는 [API 명세](docs/api-spec.md)의 요청, 응답, Enum, 에러
코드를 먼저 합의합니다. 실제 구현 이후 FastAPI 계약은 OpenAPI를 기준으로 하고,
인증 화면은 Supabase Auth SDK 계약을 기준으로 관리합니다.
App Store 제출 전 Apple 로그인 정책 대응은 [시스템 아키텍처](docs/architecture.md)의
iOS 출시 게이트를 따릅니다.

백엔드 로컬 실행 방법은 [backend/README.md](backend/README.md), 브랜치와 PR
규칙은 [CONTRIBUTING.md](CONTRIBUTING.md)를 따릅니다.
