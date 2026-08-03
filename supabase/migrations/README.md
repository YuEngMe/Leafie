# Migrations

이 디렉터리는 Supabase CLI SQL migration 자리입니다.

**현재 Leafie MVP의 DB 스키마·RLS·시드·Cron 정의는 Alembic이 단일 기준입니다.**

```text
backend/alembic/versions/
```

스키마를 바꿀 때는 여기에 SQL을 추가하지 말고:

```bash
cd backend
alembic revision --autogenerate -m "변경 내용"
alembic upgrade head
```

Dashboard 전용 설정 변경이 있으면 동일 내용을 Alembic revision 또는
`supabase/README.md`에 기록합니다.
