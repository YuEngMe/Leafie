import importlib.util
from pathlib import Path
from types import ModuleType


def load_migration(module_name: str, filename: str) -> ModuleType:
    migration_path = Path(__file__).parents[1] / "alembic" / "versions" / filename
    spec = importlib.util.spec_from_file_location(module_name, migration_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_every_initial_species_has_a_versioned_care_profile() -> None:
    catalog = load_migration(
        "species_catalog_migration",
        "9c49cb212775_seed_initial_species_catalog.py",
    ).CATALOG
    profiles = load_migration(
        "species_care_migration",
        "1f2e7c9a6b31_add_species_care_knowledge.py",
    ).PROFILES

    assert len(profiles) == 23
    assert len(set(profiles)) == 23
    assert set(profiles) == {item["species_reference_id"] for item in catalog}
    for reference_id, item in profiles.items():
        assert reference_id.startswith("catalog:")
        assert item["watering"] > 0
        assert item["repotting"] is None or item["repotting"] > 0
        assert item["care"]["watering"]["schedule_value_is_derived"] is True
        assert item["care"]["toxicity"]["status"]
        assert item["diagnosis"]["symptom_checks"]
        assert item["diagnosis"]["disclaimer"]
        assert item["sources"]
        assert all(source["url"].startswith("https://") for source in item["sources"])


def test_species_care_profiles_do_not_claim_definitive_photo_diagnosis() -> None:
    profiles = load_migration(
        "species_care_migration",
        "1f2e7c9a6b31_add_species_care_knowledge.py",
    ).PROFILES

    for item in profiles.values():
        disclaimer = item["diagnosis"]["disclaimer"]
        assert "가능한 원인" in disclaimer
        assert "확정 진단" in disclaimer
