import app.models  # noqa: F401
from app.db.base import Base

EXPECTED_APP_TABLES = {
    "ai_actions",
    "ai_batch_items",
    "ai_batch_jobs",
    "ai_chats",
    "ai_conversations",
    "ai_messages",
    "ai_tool_calls",
    "care_events",
    "care_schedules",
    "device_tokens",
    "diagnoses",
    "diagnosis_images",
    "media_files",
    "monthly_reports",
    "notification_settings",
    "notifications",
    "plant_characters",
    "plant_diaries",
    "plant_environments",
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


def test_one_permanent_chat_per_plant() -> None:
    chats = Base.metadata.tables["ai_chats"]
    unique_columns = {
        tuple(column.name for column in constraint.columns)
        for constraint in chats.constraints
        if constraint.__class__.__name__ == "UniqueConstraint"
    }

    assert ("plant_id",) in unique_columns


def test_diagnosis_accepts_only_one_image() -> None:
    diagnosis_images = Base.metadata.tables["diagnosis_images"]

    assert [column.name for column in diagnosis_images.primary_key.columns] == ["diagnosis_id"]


def test_user_owned_tables_reference_supabase_auth_users() -> None:
    user_owned_tables = {
        "ai_actions",
        "ai_chats",
        "device_tokens",
        "media_files",
        "notification_settings",
        "notifications",
        "plants",
        "species_identifications",
        "user_profiles",
    }

    for table_name in user_owned_tables:
        table = Base.metadata.tables[table_name]
        targets = {foreign_key.target_fullname for foreign_key in table.foreign_keys}
        assert "auth.users.id" in targets
