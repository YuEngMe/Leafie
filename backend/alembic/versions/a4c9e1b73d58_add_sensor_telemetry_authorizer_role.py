"""Add read-only DB role for the telemetry Lambda authorizer."""

from alembic import op

revision = "a4c9e1b73d58"
down_revision = "d2f6a83b9c10"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # telemetry Authorizer 전용 역할: deviceToken 해시 검증에 필요한 컬럼만 SELECT한다.
    op.execute(
        "DO $$ BEGIN CREATE ROLE sensor_authorizer LOGIN NOINHERIT; "
        "EXCEPTION WHEN duplicate_object THEN NULL; END $$"
    )
    op.execute("GRANT USAGE ON SCHEMA public TO sensor_authorizer")
    op.execute(
        "GRANT SELECT (id, status, sensor_token_hash) ON public.sensor_devices TO sensor_authorizer"
    )
    op.execute(
        "CREATE POLICY sensor_authorizer_select ON public.sensor_devices "
        "FOR SELECT TO sensor_authorizer USING (true)"
    )


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS sensor_authorizer_select ON public.sensor_devices")
    op.execute(
        "DO $$ BEGIN "
        "IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sensor_authorizer') THEN "
        "REVOKE ALL ON public.sensor_devices FROM sensor_authorizer; "
        "REVOKE USAGE ON SCHEMA public FROM sensor_authorizer; "
        "DROP ROLE sensor_authorizer; "
        "END IF; END $$"
    )
