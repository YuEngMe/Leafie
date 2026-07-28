"""add species care knowledge

Revision ID: 1f2e7c9a6b31
Revises: 9c49cb212775
Create Date: 2026-07-29 04:30:00.000000
"""

import json
from collections.abc import Sequence
from datetime import date

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "1f2e7c9a6b31"
down_revision: str | Sequence[str] | None = "9c49cb212775"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

DATA_VERSION = "2026-07-29.v1"
REVIEWED_AT = date(2026, 7, 29)
UC_IPM_URL = "https://ipm.ucanr.edu/home-and-landscape/houseplant-problems/"
NCSU_BASE_URL = "https://plants.ces.ncsu.edu/plants"


def source(name: str, url: str, fields: list[str]) -> dict:
    return {"name": name, "url": url, "fields": fields, "accessed_on": "2026-07-29"}


def ncsu(slug: str) -> dict:
    return source(
        "NC State Extension Gardener Plant Toolbox",
        f"{NCSU_BASE_URL}/{slug}/",
        ["light", "soil", "common_problems", "toxicity"],
    )


def profile(
    *,
    context: str,
    light: str,
    moisture: str,
    soil: str,
    warm_days: int,
    cool_days: int,
    repot_days: int | None,
    humidity: str,
    notes: list[str],
    toxicity: dict,
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
    }


def diagnosis(
    *,
    ruleset: str,
    pests: list[str],
    diseases: list[str],
    cautions: list[str] | None = None,
) -> dict:
    checks = {
        "TROPICAL_FOLIAGE": [
            {
                "symptom": "잎 황변",
                "possible_causes": ["과습", "물 부족", "광량 부족", "뿌리 손상"],
                "check": ["최근 물주기", "흙 내부 수분", "배수 상태", "황변이 시작된 잎 위치"],
            },
            {
                "symptom": "잎 끝 갈변",
                "possible_causes": ["건조", "낮은 습도", "비료 염류", "찬바람"],
                "check": ["실내 습도", "관수 간격", "최근 비료 사용", "냉난방기 위치"],
            },
        ],
        "DRY_STORAGE": [
            {
                "symptom": "잎 황변 또는 무름",
                "possible_causes": ["과습", "배수 불량", "뿌리썩음"],
                "check": ["흙이 마르는 데 걸리는 시간", "줄기·뿌리 무름", "화분 배수구"],
            },
            {
                "symptom": "잎 주름 또는 처짐",
                "possible_causes": ["장기 건조", "뿌리 손상"],
                "check": ["흙 전체 건조 여부", "뿌리 색과 단단함"],
            },
        ],
        "SUCCULENT": [
            {
                "symptom": "잎 또는 줄기 무름",
                "possible_causes": ["과습", "저온 상태의 관수", "뿌리썩음"],
                "check": ["흙 완전 건조 여부", "무른 부위", "배수성"],
            },
            {
                "symptom": "웃자람",
                "possible_causes": ["광량 부족"],
                "check": ["빛의 방향", "하루 직사광 또는 강한 간접광 시간"],
            },
        ],
        "FLOWERING": [
            {
                "symptom": "꽃이 피지 않음",
                "possible_causes": ["광량 부족", "생육 시기 불일치", "질소 과다", "전정 시기 문제"],
                "check": ["직사광 시간", "계절", "최근 비료", "최근 전정"],
            },
            {
                "symptom": "잎 반점 또는 변색",
                "possible_causes": ["곰팡이성 병", "세균성 병", "해충", "잎이 젖은 상태 지속"],
                "check": ["반점 가장자리", "잎 뒷면 해충", "통풍", "잎에 물을 준 여부"],
            },
        ],
        "BULB": [
            {
                "symptom": "구근 또는 줄기 무름",
                "possible_causes": ["과습", "배수 불량", "구근 부패"],
                "check": ["구근 단단함", "곰팡이", "흙의 물고임"],
            },
            {
                "symptom": "개화하지 않음",
                "possible_causes": ["휴면 조건 부족", "광량 부족", "구근 영양 부족"],
                "check": ["저온 처리", "식재 시기", "잎이 마르기 전 제거했는지"],
            },
        ],
        "HERB": [
            {
                "symptom": "잎 시듦",
                "possible_causes": ["물 부족", "고온", "뿌리 과밀", "과습"],
                "check": ["흙 수분", "한낮 온도", "뿌리 밀도"],
            },
            {
                "symptom": "잎 반점 또는 흰 가루",
                "possible_causes": ["곰팡이성 병", "통풍 부족", "잎 젖음"],
                "check": ["반점 형태", "잎 뒷면", "통풍", "관수 위치"],
            },
        ],
        "FRUIT": [
            {
                "symptom": "꽃이나 열매가 적음",
                "possible_causes": ["광량 부족", "수분 불량", "영양 불균형", "계절 부적합"],
                "check": ["직사광 시간", "개화 시기", "수분 매개", "최근 비료"],
            },
            {
                "symptom": "잎 황변",
                "possible_causes": ["물 스트레스", "토양 pH 부적합", "영양 결핍", "뿌리 손상"],
                "check": ["흙 수분", "토양 pH", "새잎과 묵은잎 중 시작 위치", "뿌리 상태"],
            },
        ],
    }
    return {
        "ruleset": ruleset,
        "common_pests": pests,
        "common_diseases": diseases,
        "symptom_checks": checks[ruleset],
        "cautions": cautions or [],
        "disclaimer": "사진과 관리 이력을 함께 검토해 가능한 원인을 제시하며 확정 진단으로 표현하지 않습니다.",
    }


TOXIC_OXALATE = {
    "status": "TOXIC",
    "targets": ["cats", "dogs", "humans"],
    "principle": "calcium oxalate crystals",
    "warning": "섭취 시 구강 자극, 침 흘림, 구토 또는 삼킴 곤란이 생길 수 있습니다.",
}
NON_TOXIC = {
    "status": "NO_SPECIFIC_WARNING_FOUND",
    "targets": [],
    "warning": "식용 부위가 아닌 식물 조직은 섭취하지 않도록 합니다.",
}


PROFILES = {
    "catalog:monstera-deliciosa": {
        "watering": 7,
        "repotting": 365,
        "care": profile(
            context="INDOOR",
            light="BRIGHT_INDIRECT_OR_PART_SHADE",
            moisture="KEEP_LIGHTLY_MOIST_WITH_PARTIAL_DRYING",
            soil="ORGANIC_RICH_LOAM_WITH_GOOD_DRAINAGE",
            warm_days=7,
            cool_days=10,
            repot_days=365,
            humidity="MODERATE_TO_HIGH",
            notes=["강한 직사광을 피합니다.", "공중뿌리는 지지대에 유도할 수 있습니다."],
            toxicity=TOXIC_OXALATE,
        ),
        "diagnosis": diagnosis(
            ruleset="TROPICAL_FOLIAGE",
            pests=["깍지벌레", "응애"],
            diseases=["과습성 뿌리썩음", "잎 반점"],
        ),
        "sources": [
            ncsu("monstera-deliciosa"),
            source(
                "농촌진흥청 농사로",
                "https://www.nongsaro.go.kr/portal/ps/psz/psza/contentSub.ps?cntntsNo=16449&menuId=PS00376",
                ["seasonal_watering", "light_lux", "growth_form"],
            ),
        ],
    },
    "catalog:epipremnum-aureum": {
        "watering": 7,
        "repotting": 365,
        "care": profile(
            context="INDOOR",
            light="LOW_TO_BRIGHT_INDIRECT",
            moisture="ALLOW_TOP_LAYER_TO_DRY",
            soil="ORGANIC_RICH_WITH_GOOD_DRAINAGE",
            warm_days=7,
            cool_days=10,
            repot_days=365,
            humidity="MODERATE",
            notes=["빛이 너무 약하면 무늬가 흐려질 수 있습니다.", "흙이 계속 젖어 있지 않게 합니다."],
            toxicity=TOXIC_OXALATE,
        ),
        "diagnosis": diagnosis(
            ruleset="TROPICAL_FOLIAGE",
            pests=["깍지벌레", "가루깍지벌레"],
            diseases=["과습성 뿌리썩음", "잎 가장자리 흑변"],
        ),
        "sources": [ncsu("epipremnum-aureum")],
    },
    "catalog:philodendron-hederaceum": {
        "watering": 7,
        "repotting": 365,
        "care": profile(
            context="INDOOR",
            light="LOW_TO_BRIGHT_INDIRECT",
            moisture="KEEP_LIGHTLY_MOIST_WITH_PARTIAL_DRYING",
            soil="MOIST_WITH_GOOD_DRAINAGE",
            warm_days=7,
            cool_days=10,
            repot_days=365,
            humidity="MODERATE_TO_HIGH",
            notes=["강한 직사광을 피합니다.", "과습 상태가 오래 지속되지 않게 합니다."],
            toxicity=TOXIC_OXALATE,
        ),
        "diagnosis": diagnosis(
            ruleset="TROPICAL_FOLIAGE",
            pests=["진딧물", "응애", "가루깍지벌레", "깍지벌레"],
            diseases=["잎 반점", "과습성 뿌리썩음"],
        ),
        "sources": [ncsu("philodendron-hederaceum")],
    },
    "catalog:hedera-helix": {
        "watering": 5,
        "repotting": 365,
        "care": profile(
            context="INDOOR_OR_OUTDOOR_CONTAINER",
            light="BRIGHT_INDIRECT_TO_PART_SUN",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="MOIST_WITH_GOOD_DRAINAGE",
            warm_days=5,
            cool_days=8,
            repot_days=365,
            humidity="MODERATE",
            notes=["실내에서는 통풍을 확보합니다.", "실외 식재 시 지역의 침입종 지침을 확인합니다."],
            toxicity={
                "status": "TOXIC",
                "targets": ["cats", "dogs", "humans"],
                "principle": "triterpenoid saponins and polyacetylene compounds",
                "warning": "섭취 및 수액 접촉을 피합니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="TROPICAL_FOLIAGE",
            pests=["진딧물", "가루깍지벌레", "응애", "깍지벌레"],
            diseases=["잎 반점", "세균성 잎 반점", "줄기썩음", "흰가루병"],
        ),
        "sources": [ncsu("hedera-helix")],
    },
    "catalog:zamioculcas-zamiifolia": {
        "watering": 14,
        "repotting": 730,
        "care": profile(
            context="INDOOR",
            light="LOW_TO_BRIGHT_INDIRECT",
            moisture="ALLOW_MOST_OF_SOIL_TO_DRY",
            soil="ORGANIC_AND_SANDY_WITH_GOOD_DRAINAGE",
            warm_days=14,
            cool_days=21,
            repot_days=730,
            humidity="LOW_TO_MODERATE",
            notes=["뿌리줄기에 수분을 저장하므로 잦은 관수를 피합니다."],
            toxicity=TOXIC_OXALATE,
        ),
        "diagnosis": diagnosis(
            ruleset="DRY_STORAGE",
            pests=["깍지벌레"],
            diseases=["과습성 뿌리줄기 썩음"],
        ),
        "sources": [ncsu("zamioculcas-zamiifolia")],
    },
    "catalog:dracaena-trifasciata": {
        "watering": 14,
        "repotting": 730,
        "care": profile(
            context="INDOOR",
            light="LOW_TO_PART_SUN",
            moisture="ALLOW_MOST_OF_SOIL_TO_DRY",
            soil="LOAM_AND_SAND_WITH_GOOD_DRAINAGE",
            warm_days=14,
            cool_days=21,
            repot_days=730,
            humidity="LOW_TO_MODERATE",
            notes=["잎 중앙에 물이 고이지 않게 합니다.", "겨울에는 관수 간격을 늘립니다."],
            toxicity={
                "status": "TOXIC",
                "targets": ["cats", "dogs"],
                "principle": "saponins",
                "warning": "섭취 시 구토, 설사, 침 흘림 등이 나타날 수 있습니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="DRY_STORAGE",
            pests=["가루깍지벌레", "응애"],
            diseases=["과습성 뿌리썩음"],
        ),
        "sources": [ncsu("dracaena-trifasciata")],
    },
    "catalog:ficus-elastica": {
        "watering": 7,
        "repotting": 365,
        "care": profile(
            context="INDOOR",
            light="BRIGHT_INDIRECT_OR_PART_SHADE",
            moisture="ALLOW_TOP_LAYER_TO_DRY",
            soil="LOAM_WITH_GOOD_DRAINAGE",
            warm_days=7,
            cool_days=10,
            repot_days=365,
            humidity="MODERATE",
            notes=["급격한 온도 변화와 찬바람을 피합니다.", "수액이 피부에 닿지 않게 합니다."],
            toxicity={
                "status": "TOXIC",
                "targets": ["cats", "dogs"],
                "principle": "ficin and furanocoumarins",
                "warning": "유백색 수액은 피부를 자극할 수 있습니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="TROPICAL_FOLIAGE",
            pests=["가루깍지벌레", "깍지벌레", "응애"],
            diseases=["과습성 낙엽", "뿌리썩음"],
            cautions=["아랫잎 일부가 노화로 노래져 떨어지는 것은 정상일 수 있습니다."],
        ),
        "sources": [ncsu("ficus-elastica"), ncsu("ficus")],
    },
    "catalog:alocasia-mortfontanensis": {
        "watering": 5,
        "repotting": 365,
        "care": profile(
            context="INDOOR",
            light="BRIGHT_INDIRECT_OR_PART_SHADE",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="HUMUS_RICH_LOAM_WITH_GOOD_DRAINAGE",
            warm_days=5,
            cool_days=9,
            repot_days=365,
            humidity="HIGH",
            notes=["따뜻하고 습한 환경을 선호합니다.", "겨울에는 관수를 줄입니다."],
            toxicity=TOXIC_OXALATE,
        ),
        "diagnosis": diagnosis(
            ruleset="TROPICAL_FOLIAGE",
            pests=["응애", "진딧물", "가루깍지벌레"],
            diseases=["과습성 뿌리썩음", "잎 반점"],
        ),
        "sources": [ncsu("alocasia")],
    },
    "catalog:rosa-chinensis": {
        "watering": 3,
        "repotting": 365,
        "care": profile(
            context="OUTDOOR_CONTAINER",
            light="FULL_SUN_TO_PART_SUN",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="ORGANIC_RICH_NEUTRAL_WITH_GOOD_DRAINAGE",
            warm_days=3,
            cool_days=7,
            repot_days=365,
            humidity="MODERATE_WITH_AIRFLOW",
            notes=["잎보다 흙에 물을 줍니다.", "개화를 위해 충분한 햇빛과 통풍을 확보합니다."],
            toxicity={
                **NON_TOXIC,
                "warning": "가시에 찔리지 않도록 주의하고 식용 품종이 아닌 꽃은 먹지 않습니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="FLOWERING",
            pests=["진딧물", "총채벌레", "응애", "깍지벌레"],
            diseases=["검은무늬병", "흰가루병", "녹병", "장미 로제트병"],
        ),
        "sources": [ncsu("rosa-chinensis")],
    },
    "catalog:bellis-perennis": {
        "watering": 3,
        "repotting": 365,
        "care": profile(
            context="OUTDOOR_CONTAINER",
            light="FULL_SUN_TO_PART_SHADE",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="MOIST_WITH_GOOD_DRAINAGE",
            warm_days=3,
            cool_days=6,
            repot_days=365,
            humidity="MODERATE",
            notes=["더운 시기에는 오후 그늘이 도움이 됩니다.", "시든 꽃을 제거합니다."],
            toxicity={
                "status": "CAUTION",
                "targets": ["humans"],
                "principle": "saponins, oxalates and tannins",
                "warning": "식용 목적으로 섭취하지 않습니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="FLOWERING",
            pests=["유럽후추나방", "뿌리혹선충"],
            diseases=["녹병"],
        ),
        "sources": [ncsu("bellis-perennis")],
    },
    "catalog:helianthus-annuus": {
        "watering": 2,
        "repotting": None,
        "care": profile(
            context="OUTDOOR_CONTAINER_ANNUAL",
            light="FULL_SUN",
            moisture="KEEP_MOIST_DURING_ACTIVE_GROWTH",
            soil="LOAM_WITH_GOOD_DRAINAGE",
            warm_days=2,
            cool_days=4,
            repot_days=None,
            humidity="MODERATE_WITH_AIRFLOW",
            notes=["하루 6시간 이상의 직사광을 확보합니다.", "키가 큰 품종은 지지대가 필요할 수 있습니다."],
            toxicity=NON_TOXIC,
        ),
        "diagnosis": diagnosis(
            ruleset="FLOWERING",
            pests=["애벌레", "민달팽이", "달팽이", "딱정벌레"],
            diseases=["흰가루병", "잎 반점", "녹병"],
        ),
        "sources": [ncsu("helianthus-annuus")],
    },
    "catalog:tulipa-gesneriana": {
        "watering": 4,
        "repotting": None,
        "care": profile(
            context="OUTDOOR_CONTAINER_BULB",
            light="FULL_SUN",
            moisture="KEEP_MOIST_DURING_GROWTH_THEN_DRY_DORMANCY",
            soil="NUTRIENT_RICH_FREE_DRAINING",
            warm_days=4,
            cool_days=7,
            repot_days=None,
            humidity="MODERATE_WITH_AIRFLOW",
            notes=["생육기에는 마르지 않게 하고 휴면기에는 건조하게 관리합니다.", "구근은 물고임에 약합니다."],
            toxicity={
                "status": "TOXIC",
                "targets": ["cats", "dogs", "horses", "humans"],
                "principle": "tulipalin A and B",
                "warning": "특히 구근의 독성 농도가 높으며 섭취와 반복적인 피부 접촉을 피합니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="BULB",
            pests=["진딧물", "민달팽이"],
            diseases=["구근 부패", "튤립 파이어", "회색곰팡이병", "바이러스성 줄무늬"],
        ),
        "sources": [
            source(
                "Royal Horticultural Society",
                "https://www.rhs.org.uk/plants/tulip/growing-guide",
                ["light", "soil", "watering", "dormancy", "common_problems"],
            ),
            source(
                "ASPCA Animal Poison Control",
                "https://www.aspca.org/pet-care/aspca-poison-control/toxic-and-non-toxic-plants/tulip",
                ["pet_toxicity"],
            ),
        ],
    },
    "catalog:hydrangea-macrophylla": {
        "watering": 2,
        "repotting": 365,
        "care": profile(
            context="OUTDOOR_CONTAINER",
            light="DAPPLED_LIGHT_OR_PART_SHADE",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="ORGANIC_RICH_MOIST_WITH_GOOD_DRAINAGE",
            warm_days=2,
            cool_days=5,
            repot_days=365,
            humidity="MODERATE",
            notes=["한낮의 강한 직사광을 피합니다.", "꽃 색은 토양 pH와 품종의 영향을 받습니다."],
            toxicity={
                "status": "TOXIC",
                "targets": ["cats", "dogs", "humans"],
                "principle": "cyanogenic glycosides",
                "warning": "다량 섭취 시 위장 증상이 나타날 수 있습니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="FLOWERING",
            pests=["진딧물", "응애"],
            diseases=["잎 반점", "세균성 시들음", "흰가루병"],
        ),
        "sources": [ncsu("hydrangea-macrophylla")],
    },
    "catalog:cactaceae": {
        "watering": 21,
        "repotting": 730,
        "care": profile(
            context="INDOOR_GENERIC_CACTUS",
            light="FULL_SUN_OR_VERY_BRIGHT_LIGHT",
            moisture="ALLOW_SOIL_TO_DRY_COMPLETELY",
            soil="CACTUS_MIX_WITH_GRIT_AND_EXCELLENT_DRAINAGE",
            warm_days=21,
            cool_days=35,
            repot_days=730,
            humidity="LOW",
            notes=["과 수준의 일반 가이드이며 종에 따라 예외가 큽니다.", "겨울 휴면기에는 관수를 크게 줄입니다."],
            toxicity={
                **NON_TOXIC,
                "warning": "가시와 미세가시로 인한 피부·눈 손상에 주의합니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="SUCCULENT",
            pests=["깍지벌레", "가루깍지벌레"],
            diseases=["과습성 뿌리썩음", "줄기썩음"],
            cautions=["선인장 항목은 과 수준이므로 정확한 종 확인 후 관리법을 보정해야 합니다."],
        ),
        "sources": [ncsu("mammillaria"), ncsu("opuntia")],
    },
    "catalog:echeveria-elegans": {
        "watering": 14,
        "repotting": 730,
        "care": profile(
            context="INDOOR_OR_OUTDOOR_CONTAINER",
            light="FULL_SUN_TO_PART_SHADE",
            moisture="ALLOW_SOIL_TO_DRY_COMPLETELY",
            soil="SANDY_OR_ROCKY_WITH_EXCELLENT_DRAINAGE",
            warm_days=14,
            cool_days=21,
            repot_days=730,
            humidity="LOW",
            notes=["로제트 중심에 물이 고이지 않게 합니다.", "광량 부족 시 웃자랄 수 있습니다."],
            toxicity=NON_TOXIC,
        ),
        "diagnosis": diagnosis(
            ruleset="SUCCULENT",
            pests=["가루깍지벌레", "진딧물", "바구미"],
            diseases=["과습성 뿌리썩음"],
        ),
        "sources": [ncsu("echeveria-elegans")],
    },
    "catalog:haworthiopsis-attenuata": {
        "watering": 14,
        "repotting": 730,
        "care": profile(
            context="INDOOR",
            light="BRIGHT_INDIRECT_OR_PART_SHADE",
            moisture="ALLOW_SOIL_TO_DRY_COMPLETELY",
            soil="SANDY_OR_ROCKY_WITH_EXCELLENT_DRAINAGE",
            warm_days=14,
            cool_days=21,
            repot_days=730,
            humidity="LOW",
            notes=["강한 한낮 직사광은 잎을 태울 수 있습니다.", "잎 사이에 물이 고이지 않게 합니다."],
            toxicity=NON_TOXIC,
        ),
        "diagnosis": diagnosis(
            ruleset="SUCCULENT",
            pests=["깍지벌레", "가루깍지벌레"],
            diseases=["과습성 뿌리썩음"],
        ),
        "sources": [ncsu("haworthiopsis-attenuata")],
    },
    "catalog:olea-europaea": {
        "watering": 7,
        "repotting": 730,
        "care": profile(
            context="OUTDOOR_OR_SUNNY_INDOOR_CONTAINER",
            light="FULL_SUN",
            moisture="ALLOW_TOP_LAYER_TO_DRY",
            soil="LOAM_OR_SAND_WITH_GOOD_DRAINAGE",
            warm_days=7,
            cool_days=12,
            repot_days=730,
            humidity="LOW_TO_MODERATE",
            notes=["실내에서는 가장 햇빛이 긴 위치에 둡니다.", "통풍과 배수를 확보합니다."],
            toxicity=NON_TOXIC,
        ),
        "diagnosis": diagnosis(
            ruleset="FRUIT",
            pests=["깍지벌레"],
            diseases=["올리브혹병", "버티실리움 시들음", "뿌리썩음"],
        ),
        "sources": [ncsu("olea-europaea")],
    },
    "catalog:mentha-spicata": {
        "watering": 3,
        "repotting": 365,
        "care": profile(
            context="OUTDOOR_OR_SUNNY_INDOOR_CONTAINER",
            light="FULL_SUN_TO_PART_SHADE",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="ORGANIC_RICH_MOIST_WITH_GOOD_DRAINAGE",
            warm_days=3,
            cool_days=6,
            repot_days=365,
            humidity="MODERATE",
            notes=["번식력이 강하므로 단독 화분이 관리하기 쉽습니다.", "통풍을 확보합니다."],
            toxicity={
                "status": "CAUTION",
                "targets": ["cats", "dogs"],
                "principle": "essential oils",
                "warning": "반려동물이 많은 양을 섭취하지 않게 합니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="HERB",
            pests=["진딧물", "응애"],
            diseases=["녹병", "잎 반점"],
        ),
        "sources": [ncsu("mentha-spicata")],
    },
    "catalog:ocimum-basilicum": {
        "watering": 3,
        "repotting": None,
        "care": profile(
            context="SUNNY_INDOOR_OR_OUTDOOR_CONTAINER_ANNUAL",
            light="FULL_SUN_TO_PART_SHADE",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="MOIST_WITH_GOOD_DRAINAGE",
            warm_days=3,
            cool_days=5,
            repot_days=None,
            humidity="MODERATE_WITH_AIRFLOW",
            notes=["추위에 약하므로 따뜻한 생육기에 관리합니다.", "잎보다 흙에 물을 줍니다."],
            toxicity=NON_TOXIC,
        ),
        "diagnosis": diagnosis(
            ruleset="HERB",
            pests=["진딧물", "풍뎅이류"],
            diseases=["푸사리움 시들음", "바질 노균병"],
        ),
        "sources": [ncsu("ocimum-basilicum")],
    },
    "catalog:fragaria-ananassa": {
        "watering": 2,
        "repotting": 365,
        "care": profile(
            context="OUTDOOR_OR_SUNNY_CONTAINER",
            light="FULL_SUN_TO_PART_SHADE",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="ORGANIC_RICH_LOAM_WITH_GOOD_DRAINAGE",
            warm_days=2,
            cool_days=5,
            repot_days=365,
            humidity="MODERATE_WITH_AIRFLOW",
            notes=["열매와 잎이 오래 젖지 않도록 흙에 물을 줍니다.", "개화기에는 수분 환경을 확인합니다."],
            toxicity=NON_TOXIC,
        ),
        "diagnosis": diagnosis(
            ruleset="FRUIT",
            pests=["진딧물", "응애", "총채벌레"],
            diseases=["잿빛곰팡이병", "흰가루병", "탄저병", "뿌리썩음"],
        ),
        "sources": [ncsu("fragaria-x-ananassa")],
    },
    "catalog:citrus-limon": {
        "watering": 5,
        "repotting": 730,
        "care": profile(
            context="SUNNY_INDOOR_OR_OUTDOOR_CONTAINER",
            light="FULL_SUN",
            moisture="KEEP_MOIST_WITH_PARTIAL_DRYING",
            soil="LOAM_OR_SAND_WITH_GOOD_DRAINAGE",
            warm_days=5,
            cool_days=9,
            repot_days=730,
            humidity="MODERATE",
            notes=["충분한 직사광과 통풍을 확보합니다.", "물받이에 물이 고이지 않게 합니다."],
            toxicity={
                "status": "TOXIC_PLANT_PARTS",
                "targets": ["cats", "dogs"],
                "principle": "essential oils and psoralens",
                "warning": "과육 외 껍질과 식물체를 반려동물이 섭취하지 않게 합니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="FRUIT",
            pests=["가루깍지벌레", "응애", "깍지벌레", "진딧물"],
            diseases=["감귤 궤양병", "그을음병", "탄저병", "회색곰팡이병", "레몬 더뎅이병"],
        ),
        "sources": [ncsu("citrus-x-limon")],
    },
    "catalog:vaccinium-corymbosum": {
        "watering": 3,
        "repotting": 730,
        "care": profile(
            context="OUTDOOR_CONTAINER",
            light="FULL_SUN_TO_PART_SHADE",
            moisture="KEEP_EVENLY_MOIST_NOT_SOGGY",
            soil="ACIDIC_MOIST_WITH_GOOD_DRAINAGE",
            warm_days=3,
            cool_days=6,
            repot_days=730,
            humidity="MODERATE",
            notes=["산성 토양을 유지합니다.", "토양 pH가 높으면 잎이 누렇게 될 수 있습니다."],
            toxicity=NON_TOXIC,
        ),
        "diagnosis": diagnosis(
            ruleset="FRUIT",
            pests=["초파리류"],
            diseases=["줄기마름병", "뿌리썩음", "탄저병", "가지 궤양병", "흰가루병", "잿빛곰팡이병"],
            cautions=["높은 토양 pH로 인한 철 결핍성 황화를 먼저 확인합니다."],
        ),
        "sources": [ncsu("vaccinium-corymbosum")],
    },
    "catalog:prunus-avium": {
        "watering": 5,
        "repotting": 730,
        "care": profile(
            context="OUTDOOR_CONTAINER_OR_GROUND",
            light="FULL_SUN",
            moisture="KEEP_MOIST_WITH_PARTIAL_DRYING",
            soil="FERTILE_WITH_GOOD_DRAINAGE",
            warm_days=5,
            cool_days=10,
            repot_days=730,
            humidity="MODERATE_WITH_AIRFLOW",
            notes=["실내 장기 재배보다 실외 환경이 적합합니다.", "결실에는 품종에 맞는 수분 조건이 필요합니다."],
            toxicity={
                "status": "TOXIC_PLANT_PARTS",
                "targets": ["cats", "dogs", "horses", "humans"],
                "principle": "cyanogenic glycosides",
                "warning": "과육을 제외한 씨, 잎, 줄기 등은 섭취하지 않습니다.",
            },
        ),
        "diagnosis": diagnosis(
            ruleset="FRUIT",
            pests=["진딧물", "과실파리", "잎벌", "깍지벌레"],
            diseases=["세균성 궤양병", "갈색무늬병", "갈색썩음병", "흑색혹병", "흰가루병", "뿌리썩음"],
        ),
        "sources": [ncsu("prunus-avium")],
    },
}


def _jsonb(value: object) -> sa.ColumnElement:
    return sa.cast(
        op.inline_literal(json.dumps(value, ensure_ascii=False)),
        postgresql.JSONB,
    )


def upgrade() -> None:
    op.add_column(
        "species_care_guides",
        sa.Column("default_watering_interval_days", sa.Integer(), nullable=True),
    )
    op.add_column(
        "species_care_guides",
        sa.Column("default_repotting_interval_days", sa.Integer(), nullable=True),
    )
    op.add_column(
        "species_care_guides",
        sa.Column(
            "care_profile",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "species_care_guides",
        sa.Column(
            "diagnosis_profile",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "species_care_guides",
        sa.Column(
            "source_references",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "species_care_guides", sa.Column("care_data_version", sa.String(32), nullable=True)
    )
    op.add_column(
        "species_care_guides", sa.Column("care_data_reviewed_at", sa.Date(), nullable=True)
    )
    op.create_check_constraint(
        "default_watering_interval_days",
        "species_care_guides",
        "default_watering_interval_days IS NULL OR default_watering_interval_days > 0",
    )
    op.create_check_constraint(
        "default_repotting_interval_days",
        "species_care_guides",
        "default_repotting_interval_days IS NULL OR default_repotting_interval_days > 0",
    )

    guide_table = sa.table(
        "species_care_guides",
        sa.column("species_reference_id", sa.String),
        sa.column("default_watering_interval_days", sa.Integer),
        sa.column("default_repotting_interval_days", sa.Integer),
        sa.column("care_profile", postgresql.JSONB),
        sa.column("diagnosis_profile", postgresql.JSONB),
        sa.column("source_references", postgresql.JSONB),
        sa.column("care_data_version", sa.String),
        sa.column("care_data_reviewed_at", sa.Date),
    )
    for reference_id, item in PROFILES.items():
        op.get_bind().execute(
            guide_table.update()
            .where(guide_table.c.species_reference_id == op.inline_literal(reference_id))
            .values(
                default_watering_interval_days=item["watering"],
                default_repotting_interval_days=item["repotting"],
                care_profile=_jsonb(item["care"]),
                diagnosis_profile=_jsonb(item["diagnosis"]),
                source_references=_jsonb(
                    [
                        *item["sources"],
                        source(
                            "UC Statewide IPM Program",
                            UC_IPM_URL,
                            ["symptom_differential", "safe_management"],
                        ),
                    ]
                ),
                care_data_version=DATA_VERSION,
                care_data_reviewed_at=REVIEWED_AT,
            )
        )


def downgrade() -> None:
    op.drop_constraint(
        "ck_species_care_guides_default_repotting_interval_days",
        "species_care_guides",
        type_="check",
    )
    op.drop_constraint(
        "ck_species_care_guides_default_watering_interval_days",
        "species_care_guides",
        type_="check",
    )
    op.drop_column("species_care_guides", "care_data_reviewed_at")
    op.drop_column("species_care_guides", "care_data_version")
    op.drop_column("species_care_guides", "source_references")
    op.drop_column("species_care_guides", "diagnosis_profile")
    op.drop_column("species_care_guides", "care_profile")
    op.drop_column("species_care_guides", "default_repotting_interval_days")
    op.drop_column("species_care_guides", "default_watering_interval_days")
