# Supabase

Supabase 프로젝트의 Auth, Storage, Queue, Cron 운영 메모를 둡니다.

## Schema source of truth

애플리케이션 테이블, RLS 활성화, 시드 데이터, Queue·Cron SQL의 **단일 기준은
`backend/alembic/versions/`** 입니다. 스키마 변경은 Alembic revision으로 추가하고
`alembic upgrade head`로 적용합니다.

```bash
cd backend
alembic heads          # 단일 head 확인
alembic upgrade head   # 공유/로컬 DB 적용
```

`supabase/migrations/`는 Supabase CLI SQL migration용 자리입니다. 현재 MVP 스키마는
Alembic으로 관리하므로 여기에 중복 SQL을 두지 않습니다. Dashboard에서만 바꾼
설정이 있으면 같은 내용을 Alembic 또는 이 문서에 남깁니다.

## Auth

- 이메일·비밀번호 (인증 링크 필수)
- Kakao OAuth, Apple OAuth
- Naver Custom OAuth2
- Google 로그인은 지원하지 않습니다

## Storage

- 비공개 버킷 `leafie-media`
- 용도: 식물 인식, 대표 사진, 다이어리, 진단, 채팅 이미지
- 앱은 FastAPI Signed URL로 업로드·다운로드합니다

## Queue · Cron

- Queue 이름 기본값: `leafie_jobs` (`SUPABASE_QUEUE_NAME`)
- `pg_cron` 작업 `leafie-care-notification-collector`가 매시
  `CARE_NOTIFICATION_COLLECT`를 enqueue합니다 (Alembic revision `c4f9a2d8e710`)
