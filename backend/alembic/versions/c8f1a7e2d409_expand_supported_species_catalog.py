"""Add five supported plants with care knowledge and provisional sensor policies."""

import json
from datetime import date

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "c8f1a7e2d409"
down_revision = "b6e2d8a41f90"
branch_labels = None
depends_on = None

DATA_VERSION = "2026-10-10.v1"
SENSOR_VERSION = "2026-10-10.app-v1"
REVIEWED_AT = date(2026, 10, 10)
NCSU = "https://plants.ces.ncsu.edu/plants/"
RHS_SANSEVIERIA = "https://www.rhs.org.uk/plants/sansevieria/growing-guide"
UC_IPM = "https://ipm.ucanr.edu/home-and-landscape/houseplant-problems/"
SOIL = {"DRY": (15, 75), "TOP_DRY": (30, 85), "MOIST": (40, 90)}
LIGHT = {"LOW_BRIGHT": (8000, 60000), "INDIRECT": (20000, 90000), "SUN": (60000, None)}


def source(name: str, url: str, fields: list[str]) -> dict:
    return {"name": name, "url": url, "fields": fields, "accessed_on": REVIEWED_AT.isoformat()}


def sensor_policy(soil: str, light: str, *, enabled: bool = True) -> dict:
    return {
        "version": SENSOR_VERSION,
        "status": "PROVISIONAL",
        "enabled": enabled,
        "soil_unit": "relative_percent",
        "light_unit": "lux_hours",
        "soil_percent": dict(zip(("lower", "upper"), SOIL[soil], strict=True)),
        "light_lux_hours": dict(zip(("lower", "upper"), LIGHT[light], strict=True)),
        "basis": "APP_INITIAL_HEURISTIC_NOT_AGRONOMIC_STANDARD",
        "assumptions": [
            "Relative soil readings require device/substrate calibration (#118).",
            "Lux-hours are not PAR-based DLI; values are app feedback targets, not injury limits.",
            "Light is evaluated for a completed local day with >=80% ten-minute coverage.",
            "Trade-hybrid Euphorbia policy stays disabled until identity and dormancy are known.",
        ],
        "reference_urls": [
            "https://www.extension.umd.edu/resource/lighting-indoor-plants",
            "https://content.ces.ncsu.edu/calibrating-soil-water-measuring-devices",
        ],
        "references_supply_numeric_thresholds": False,
    }


def care_profile(
    *,
    context: str,
    light: str,
    moisture: str,
    soil: str,
    humidity: str,
    warm_days: int,
    cool_days: int,
    repot_days: int | None,
    notes: list[str],
    toxicity: dict,
    thresholds: dict,
    taxonomy: dict | None = None,
) -> dict:
    return {
        "growth_context": context,
        "light": light,
        "soil_moisture": moisture,
        "soil": soil,
        "humidity": humidity,
        "watering": {
            "warm_season_interval_days": warm_days,
            "cool_season_interval_days": cool_days,
            "schedule_value_is_derived": True,
            "instruction": "달력보다 흙의 건조 상태를 먼저 확인하고, 물을 준 뒤 받침의 물을 버립니다.",
        },
        "repotting": {
            "baseline_interval_days": repot_days,
            "schedule_value_is_derived": repot_days is not None,
            "signals": ["배수구 밖으로 뿌리가 나옴", "물이 지나치게 빨리 빠짐", "생장이 둔화됨"],
        },
        "care_notes": notes,
        "toxicity": toxicity,
        "sensor_thresholds": thresholds,
        **({"taxonomy": taxonomy} if taxonomy is not None else {}),
    }


def diagnosis_profile(
    ruleset: str, pests: list[str], diseases: list[str], checks: list[dict], cautions: list[str]
) -> dict:
    return {
        "ruleset": ruleset,
        "common_pests": pests,
        "common_diseases": diseases,
        "symptom_checks": checks,
        "cautions": cautions,
        "disclaimer": "사진과 관리 이력을 함께 검토해 가능한 원인을 제시하며 확정 진단으로 표현하지 않습니다.",
    }


CATALOG = [
    {
        "species_reference_id": "catalog:spathiphyllum-wallisii",
        "display_name": "스파티필름",
        "scientific_name": "Spathiphyllum wallisii",
        "plantnet_species_id": "1410054",
        "gbif_id": 2869680,
        "family_name": "Araceae",
        "category": "FOLIAGE",
        "aliases": ["스파티필름", "스파티필룸", "스파트필름", "평화백합", "피스 릴리"],
        "default_watering_interval_days": 5,
        "default_repotting_interval_days": 730,
        "care_profile": care_profile(
            context="INDOOR_CONTAINER",
            light="LOW_LIGHT_TO_BRIGHT_INDIRECT",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="ORGANIC_RICH_WITH_GOOD_DRAINAGE",
            humidity="MODERATE_TO_HIGH",
            warm_days=5,
            cool_days=9,
            repot_days=730,
            notes=[
                "강한 직사광을 피하고 흙이 계속 물에 잠기지 않게 합니다.",
                "과도한 비료와 염류 축적도 잎 끝 갈변의 원인이 될 수 있습니다.",
                "스파티필름 통용명의 대표 종이며 모든 원예 교잡종을 뜻하지 않습니다.",
            ],
            toxicity={
                "status": "TOXIC",
                "targets": ["cats", "dogs", "humans"],
                "principle": "calcium oxalate crystals",
                "warning": "섭취 시 구강 자극과 삼킴 곤란이 생길 수 있어 어린이와 반려동물의 접근을 막습니다.",
            },
            thresholds=sensor_policy("MOIST", "LOW_BRIGHT"),
        ),
        "diagnosis_profile": diagnosis_profile(
            "TROPICAL_FOLIAGE",
            ["가루깍지벌레"],
            ["뿌리썩음"],
            [
                {
                    "symptom": "잎 끝 갈변 또는 처짐",
                    "possible_causes": ["물 부족", "과습", "직사광", "낮은 습도", "비료 염류"],
                    "check": ["흙 내부 수분", "뿌리 상태", "직사광 노출", "최근 비료"],
                }
            ],
            ["잎 처짐만으로 물 부족을 확정하지 않고 과습과 뿌리 손상도 확인합니다."],
        ),
        "source_references": [
            source(
                "Pl@ntNet taxonomy", "https://my.plantnet.org/doc/api/taxonomy", ["taxonomy_ids"]
            ),
            source(
                "Kew POWO",
                "https://powo.science.kew.org/taxon/urn:lsid:ipni.org:names:89011-1",
                ["accepted_name", "family"],
            ),
            source(
                "NC State Extension (Spathiphyllum genus)",
                NCSU + "spathiphyllum/",
                ["light", "soil", "watering", "toxicity", "common_problems"],
            ),
        ],
    },
    {
        "species_reference_id": "catalog:dracaena-stuckyi",
        "display_name": "스투키",
        "scientific_name": "Dracaena stuckyi",
        "plantnet_species_id": "1752362",
        "gbif_id": 11064950,
        "family_name": "Asparagaceae",
        "category": "SUCCULENT_CACTUS",
        "aliases": ["스투키", "스턱키", "Sansevieria stuckyi", "Acyntha stuckyi"],
        "default_watering_interval_days": 21,
        "default_repotting_interval_days": 1095,
        "care_profile": care_profile(
            context="INDOOR_CONTAINER",
            light="LOW_LIGHT_TO_BRIGHT_INDIRECT",
            moisture="ALLOW_MOST_SOIL_TO_DRY",
            soil="GRITTY_WITH_EXCELLENT_DRAINAGE",
            humidity="LOW_TO_MODERATE",
            warm_days=21,
            cool_days=35,
            repot_days=1095,
            notes=[
                "흙이 충분히 마른 뒤 물을 주고 겨울에는 급수를 줄입니다.",
                "배수구가 있는 화분을 사용하고 과도하게 큰 화분은 피합니다.",
                "유통 중 혼용되는 Dracaena angolensis와는 다른 종이며 동의어로 연결하지 않습니다.",
            ],
            toxicity={
                "status": "TOXIC",
                "targets": ["cats", "dogs", "humans"],
                "warning": "산세베리아류는 섭취하지 않고 수액의 피부 접촉을 피합니다.",
            },
            thresholds=sensor_policy("DRY", "LOW_BRIGHT"),
        ),
        "diagnosis_profile": diagnosis_profile(
            "DRY_STORAGE",
            ["가루깍지벌레"],
            ["뿌리썩음"],
            [
                {
                    "symptom": "잎 밑동 무름 또는 잎 주름",
                    "possible_causes": ["과습", "저온", "장기 건조", "뿌리 손상"],
                    "check": ["흙 전체 건조 여부", "밑동 단단함", "최근 최저 온도", "뿌리 상태"],
                }
            ],
            ["관리 정보는 산세베리아류 일반 지침을 적용한 초기값이며 개체별 상태를 확인합니다."],
        ),
        "source_references": [
            source(
                "Pl@ntNet taxonomy", "https://my.plantnet.org/doc/api/taxonomy", ["taxonomy_ids"]
            ),
            source(
                "Kew POWO",
                "https://powo.science.kew.org/taxon/urn:lsid:ipni.org:names:77183329-1",
                ["accepted_name", "synonyms", "family"],
            ),
            source(
                "RHS sansevieria group guidance",
                RHS_SANSEVIERIA,
                ["light", "soil", "watering", "repotting", "toxicity", "common_problems"],
            ),
        ],
    },
    {
        "species_reference_id": "catalog:solanum-lycopersicum",
        "display_name": "토마토",
        "scientific_name": "Solanum lycopersicum",
        "plantnet_species_id": "1396325",
        "gbif_id": 2930137,
        "family_name": "Solanaceae",
        "category": "FRUIT",
        "aliases": ["토마토", "방울토마토", "Lycopersicon esculentum", "Lycopersicon lycopersicum"],
        "default_watering_interval_days": 2,
        "default_repotting_interval_days": None,
        "care_profile": care_profile(
            context="SUNNY_INDOOR_OR_OUTDOOR_CONTAINER_ANNUAL",
            light="FULL_SUN",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="FERTILE_LOAM_WITH_GOOD_DRAINAGE",
            humidity="MODERATE_WITH_AIRFLOW",
            warm_days=2,
            cool_days=4,
            repot_days=None,
            notes=[
                "충분한 햇빛과 통풍을 확보하고 필요하면 지지대를 사용합니다.",
                "급격한 건습 반복을 피하고 잎보다 흙에 물을 줍니다.",
                "한해살이 화분 재배를 기준으로 반복 분갈이 일정은 생성하지 않습니다.",
            ],
            toxicity={
                "status": "TOXIC_PLANT_PARTS",
                "targets": ["cats", "dogs", "humans"],
                "warning": "식용 열매와 달리 잎과 줄기는 섭취하지 않습니다.",
            },
            thresholds=sensor_policy("MOIST", "SUN"),
        ),
        "diagnosis_profile": diagnosis_profile(
            "FRUIT",
            ["진딧물", "가루이", "응애", "나방 유충"],
            ["역병", "푸사리움 시들음", "세균성 병", "바이러스성 병"],
            [
                {
                    "symptom": "열매 갈라짐 또는 배꼽 부위 검게 변함",
                    "possible_causes": ["급격한 수분 변화", "칼슘 이동 장애", "뿌리 스트레스"],
                    "check": ["관수의 규칙성", "최근 건조와 과습", "열매 손상 위치", "뿌리 상태"],
                },
                {
                    "symptom": "잎 황변 또는 시듦",
                    "possible_causes": ["물 스트레스", "영양 불균형", "해충", "시들음병"],
                    "check": ["흙 수분", "잎 뒷면", "황변 시작 위치", "줄기와 뿌리 상태"],
                },
            ],
            ["배꼽썩음 증상은 생리장해일 수 있어 곰팡이병이나 비료 부족으로 단정하지 않습니다."],
        ),
        "source_references": [
            source(
                "Pl@ntNet taxonomy", "https://my.plantnet.org/doc/api/taxonomy", ["taxonomy_ids"]
            ),
            source(
                "NC State Extension",
                NCSU + "solanum-lycopersicum/",
                [
                    "accepted_name",
                    "synonyms",
                    "light",
                    "soil",
                    "watering",
                    "toxicity",
                    "common_problems",
                ],
            ),
        ],
    },
    {
        "species_reference_id": "catalog:strelitzia-reginae",
        "display_name": "극락조",
        "scientific_name": "Strelitzia reginae",
        "plantnet_species_id": "1387289",
        "gbif_id": 2763116,
        "family_name": "Strelitziaceae",
        "category": "FOLIAGE",
        "aliases": ["극락조", "극락조화", "극락조꽃", "Bird of paradise", "Strelitzia regalis"],
        "default_watering_interval_days": 7,
        "default_repotting_interval_days": 730,
        "care_profile": care_profile(
            context="SUNNY_INDOOR_OR_OUTDOOR_CONTAINER",
            light="FULL_SUN_TO_PART_SHADE",
            moisture="ALLOW_TOPSOIL_TO_DRY",
            soil="FERTILE_LOAM_WITH_GOOD_DRAINAGE",
            humidity="MODERATE_WITH_AIRFLOW",
            warm_days=7,
            cool_days=14,
            repot_days=730,
            notes=[
                "밝은 빛을 확보하고 봄·여름 생육기보다 겨울에는 건조하게 관리합니다.",
                "물고임을 피하고 잎 뒷면의 해충을 확인합니다.",
                "대표 종은 Strelitzia reginae이며 Strelitzia nicolai를 동의어로 취급하지 않습니다.",
            ],
            toxicity={
                "status": "TOXIC",
                "targets": ["cats", "dogs", "horses"],
                "warning": "반려동물이 식물체를 먹지 않게 합니다.",
            },
            thresholds=sensor_policy("TOP_DRY", "SUN"),
        ),
        "diagnosis_profile": diagnosis_profile(
            "TROPICAL_FOLIAGE",
            ["가루깍지벌레", "깍지벌레", "응애"],
            ["뿌리썩음", "잎 반점병"],
            [
                {
                    "symptom": "잎 황변 또는 갈색 반점",
                    "possible_causes": ["과습", "배수 불량", "잎 반점병", "해충"],
                    "check": ["화분 물고임", "뿌리 상태", "반점 가장자리", "잎 뒷면"],
                }
            ],
            ["유통명만으로 다른 Strelitzia 종의 개화·관리 조건을 동일하다고 단정하지 않습니다."],
        ),
        "source_references": [
            source(
                "Pl@ntNet taxonomy", "https://my.plantnet.org/doc/api/taxonomy", ["taxonomy_ids"]
            ),
            source(
                "NC State Extension",
                NCSU + "strelitzia-reginae/",
                [
                    "accepted_name",
                    "synonyms",
                    "light",
                    "soil",
                    "watering",
                    "toxicity",
                    "common_problems",
                ],
            ),
        ],
    },
    {
        "species_reference_id": "catalog:euphorbia-gwaemaok",
        "display_name": "괴마옥",
        "scientific_name": "Euphorbia hybrid",
        "plantnet_species_id": None,
        "gbif_id": None,
        "family_name": "Euphorbiaceae",
        "category": "SUCCULENT_CACTUS",
        "aliases": ["괴마옥", "파인애플 선인장", "소철기린"],
        "default_watering_interval_days": 14,
        "default_repotting_interval_days": 730,
        "care_profile": care_profile(
            context="BRIGHT_INDOOR_OR_SHELTERED_OUTDOOR_CONTAINER",
            light="BRIGHT_INDIRECT_TO_PART_SUN",
            moisture="DRY_BETWEEN_WATERINGS_REDUCE_WHEN_DORMANT",
            soil="GRITTY_WITH_EXCELLENT_DRAINAGE",
            humidity="LOW_TO_MODERATE_WITH_AIRFLOW",
            warm_days=14,
            cool_days=30,
            repot_days=730,
            notes=[
                "국내 괴마옥 유통명은 교잡종 이름이 혼용되어 학명과 교잡 부모를 확정하지 않습니다.",
                "흙이 마른 뒤 급수하고 저온·휴면기에는 달력보다 실제 생장과 건조 상태를 우선합니다.",
                "관련 다육성 Euphorbia의 일반 지침을 적용하며 개체별 관리 정보를 확인합니다.",
                "성장·휴면 단계 확인 전 센서 판정은 비활성입니다.",
            ],
            toxicity={
                "status": "TOXIC_IRRITANT_SAP",
                "targets": ["cats", "dogs", "humans"],
                "principle": "irritant milky latex",
                "warning": "흰 수액이 피부·눈에 닿지 않게 장갑을 사용하고 섭취하지 않습니다.",
            },
            thresholds=sensor_policy("DRY", "INDIRECT", enabled=False),
            taxonomy={
                "status": "TRADE_NAME_UNRESOLVED",
                "photo_matching_enabled": False,
                "note": "괴마옥 유통 교잡종이며 특정 야생종의 학명·분류 ID를 부여하지 않습니다.",
            },
        ),
        "diagnosis_profile": diagnosis_profile(
            "SUCCULENT",
            ["가루깍지벌레", "깍지벌레"],
            ["뿌리썩음", "줄기썩음"],
            [
                {
                    "symptom": "낙엽 또는 줄기 무름",
                    "possible_causes": ["휴면", "저온", "과습", "장기 건조", "뿌리 손상"],
                    "check": ["최근 생장 여부", "줄기 단단함", "흙 내부 수분", "뿌리 상태"],
                }
            ],
            [
                "낙엽만으로 물 부족이나 질병을 확정하지 않습니다.",
                "야생종 Euphorbia hypogaea의 진단으로 자동 연결하지 않습니다.",
            ],
        ),
        "source_references": [
            source(
                "경기도농업기술원 유통 조사",
                "https://nongup.gg.go.kr/wp-content/uploads/sites/2/2024/06/report_23_cact_10.pdf",
                ["trade_name", "genus"],
            ),
            source(
                "SANBI PlantZAfrica (related species, not hybrid identification)",
                "https://pza.sanbi.org/euphorbia-bupleurifolia",
                ["related_species_care", "dormancy", "toxicity"],
            ),
            source(
                "UC ANR succulent guidance",
                "https://ucanr.edu/node/124913/printable/print",
                ["succulent_care", "pests", "toxicity"],
            ),
        ],
    },
]


def rows() -> list[dict]:
    return [
        {
            **item,
            "source_references": [
                *item["source_references"],
                source(
                    "UC Statewide IPM Program", UC_IPM, ["symptom_differential", "safe_management"]
                ),
            ],
            "data_version": DATA_VERSION,
            "reviewed_at": REVIEWED_AT,
            "active": True,
        }
        for item in CATALOG
    ]


def guide_table() -> sa.TableClause:
    return sa.table(
        "species_care_guides",
        sa.column("species_reference_id", sa.String),
        sa.column("display_name", sa.String),
        sa.column("scientific_name", sa.String),
        sa.column("plantnet_species_id", sa.String),
        sa.column("gbif_id", sa.BigInteger),
        sa.column("family_name", sa.String),
        sa.column("category", sa.String),
        sa.column("aliases", postgresql.JSONB),
        sa.column("default_watering_interval_days", sa.Integer),
        sa.column("default_repotting_interval_days", sa.Integer),
        sa.column("care_profile", postgresql.JSONB),
        sa.column("diagnosis_profile", postgresql.JSONB),
        sa.column("source_references", postgresql.JSONB),
        sa.column("data_version", sa.String),
        sa.column("reviewed_at", sa.Date),
        sa.column("active", sa.Boolean),
    )


def upgrade() -> None:
    values = [
        {
            **item,
            **{
                key: sa.cast(
                    op.inline_literal(json.dumps(item[key], ensure_ascii=False)), postgresql.JSONB
                )
                for key in ("aliases", "care_profile", "diagnosis_profile", "source_references")
            },
        }
        for item in rows()
    ]
    # Fail on conflicts rather than overwriting a pre-existing/custom guide.
    op.get_bind().execute(postgresql.insert(guide_table()).values(values))


def downgrade() -> None:
    table = guide_table()
    # RESTRICT foreign keys abort rollback if a registered plant uses a new guide.
    op.get_bind().execute(
        table.delete().where(
            table.c.species_reference_id.in_([item["species_reference_id"] for item in CATALOG])
        )
    )
