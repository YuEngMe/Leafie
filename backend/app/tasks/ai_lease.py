import math
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from app.tasks.base import TaskDeferred


def defer_if_active(row) -> None:
    now = datetime.now(UTC)
    if row.status == "PROCESSING" and row.lease_until and row.lease_until > now:
        raise TaskDeferred(math.ceil((row.lease_until - now).total_seconds()))


def claim(row, *, lease_seconds: int, max_attempts: int, failure_code: str) -> UUID | None:
    # Call only while holding the resource's row lock.
    if row.status not in {"PENDING", "PROCESSING"}:
        return None
    defer_if_active(row)
    if row.attempt_count >= max_attempts:
        row.status = "FAILED"
        row.failure_code = row.failure_code or failure_code
        row.completed_at = datetime.now(UTC)
        row.lease_token = row.lease_until = None
        return None
    row.status = "PROCESSING"
    row.lease_token = uuid4()
    row.lease_until = datetime.now(UTC) + timedelta(seconds=lease_seconds)
    row.attempt_count += 1
    row.completed_at = None
    row.failure_code = None
    return row.lease_token


def owns(row, token: UUID) -> bool:
    if row is not None and row.status == "PROCESSING" and row.lease_token != token:
        # A stale handler must not archive the replacement worker's recovery message.
        delay = (row.lease_until - datetime.now(UTC)).total_seconds() if row.lease_until else 1
        raise TaskDeferred(max(1, math.ceil(delay)))
    return row is not None and row.status == "PROCESSING" and row.lease_token == token
