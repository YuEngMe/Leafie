# Leafie

반려식물의 관리 기록, 일정, 사진 진단과 식물이 보내는 편지를 제공하는 iOS 앱입니다.

## 문서

아래 문서는 편지 기반 개편의 기준 계약입니다. 센서 도메인은 별도 담당자가 구현하며,
공통 백엔드는 해당 결과를 소비하는 경계만 정의합니다.

- [시스템 아키텍처](docs/architecture.md)
- [제품 전환 기준과 미확정 정책](docs/product-transition.md)
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
- 날씨·제목·사진을 포함한 식물별 다이어리
- 물주기·분갈이 자동 반복과 일회성 비료 일정
- 월별·주별 캘린더와 과거 일정 완료
- 사진 1장을 이용한 비동기 식물 상태 분석
- 다이어리마다 5~15분 뒤 도착하는 식물의 편지와 우편함
- 식물별 전체 진단 이력과 진단 상세
- 푸시 알림을 위한 Firebase Installation ID와 전체 ON/OFF 설정
- 시간대별 방 배경, 식물 성격 대사와 센서 결과 연동 경계

## 권장 기술 스택

- Frontend: Flutter
- API: FastAPI, Pydantic v2, SQLAlchemy 2.x
- Auth: Supabase Auth (Email/Password, Kakao/Apple OAuth, Naver Custom OAuth2)
- Database: Supabase PostgreSQL
- Storage: Supabase Storage
- Queue: Supabase Queues (`pgmq`)
- Scheduler: Supabase Cron (`pg_cron`)
- Migration: Alembic
- Background worker: 독립 Python Worker
- AI generation: OpenAI Responses API 기반 비동기 편지 생성
- Deployment: 같은 저장소에서 FastAPI API와 Worker를 별도 프로세스로 실행

Docker는 필수가 아니며 배포 환경 통일이 필요해질 때 추가합니다. 구현 전
프론트엔드와 백엔드는 [API 명세](docs/api-spec.md)의 요청, 응답, Enum, 에러
코드를 먼저 합의합니다. 실제 구현 이후 FastAPI 계약은 OpenAPI를 기준으로 하고,
인증 화면은 Supabase Auth SDK 계약을 기준으로 관리합니다.
App Store 제출 전 Apple 로그인 정책 대응은 [시스템 아키텍처](docs/architecture.md)의
iOS 출시 게이트를 따릅니다.

백엔드 로컬 실행 방법은 [backend/README.md](backend/README.md), 브랜치와 PR
규칙은 [CONTRIBUTING.md](CONTRIBUTING.md)를 따릅니다.
