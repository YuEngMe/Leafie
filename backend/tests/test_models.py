from sqlalchemy import UniqueConstraint

import app.models  # noqa: F401
from app.db.base import Base

EXPECTED_APP_TABLES = {
    "ai_actions",
    "ai_conversations",
    "ai_messages",
    "ai_tool_calls",
    "care_events",
    "care_schedules",
    "device_tokens",
    "diagnoses",
    "media_files",
    "notifications",
    "plant_daily_memos",
    "plant_diaries",
    "plants",
    "species_care_guides",
    "species_identifications",
    "user_profiles",
}


def test_metadata_contains_all_documented_application_tables() -> None:
    app_tables = {table.name for table in Base.metadata.tables.values() if table.schema != "auth"}

    assert app_tables == EXPECTED_APP_TABLES


def test_auth_users_is_reference_only_metadata() -> None:
    auth_users = Base.metadata.tables["auth.users"]

    assert auth_users.info["skip_autogenerate"] is True
    assert {column.name for column in auth_users.columns} == {"id"}


def test_one_diary_per_plant_and_day() -> None:
    diary = Base.metadata.tables["plant_diaries"]
    unique_columns = {
        tuple(column.name for column in constraint.columns)
        for constraint in diary.constraints
        if constraint.__class__.__name__ == "UniqueConstraint"
    }

    assert ("plant_id", "diary_date") in unique_columns


def test_plant_registration_id_is_unique_per_user() -> None:
    plants = Base.metadata.tables["plants"]
    unique_columns = {
        tuple(column.name for column in constraint.columns)
        for constraint in plants.constraints
        if constraint.__class__.__name__ == "UniqueConstraint"
    }

    assert ("user_id", "client_registration_id") in unique_columns
    assert plants.columns["client_registration_id"].nullable is False
    assert plants.columns["registration_request_hash"].nullable is False


def test_conversations_belong_directly_to_a_plant() -> None:
    conversations = Base.metadata.tables["ai_conversations"]

    assert "plant_id" in conversations.columns
    assert "chat_id" not in conversations.columns


def test_diagnosis_accepts_only_one_image() -> None:
    diagnoses = Base.metadata.tables["diagnoses"]
    unique_columns = {
        tuple(column.name for column in constraint.columns)
        for constraint in diagnoses.constraints
        if isinstance(constraint, UniqueConstraint)
    }

    assert diagnoses.columns["media_file_id"].nullable is False
    assert ("media_file_id",) in unique_columns


def test_user_owned_tables_reference_supabase_auth_users() -> None:
    user_owned_tables = {
        "ai_actions",
        "device_tokens",
        "media_files",
        "notifications",
        "plants",
        "species_identifications",
        "user_profiles",
    }

    for table_name in user_owned_tables:
        table = Base.metadata.tables[table_name]
        targets = {foreign_key.target_fullname for foreign_key in table.foreign_keys}
        assert "auth.users.id" in targets
