# 지원 식물 카탈로그

## 기준

- `c8f1a7e2d409` 적용 후 지원 범위는 기존 23개와 신규 5개를 합한 28개 항목입니다.
- `늘어지는 줄기`와 정체가 확인되지 않은 `핑크파이`는 사용자 요청으로 제외합니다.
- Pl@ntNet에서 조회한 내부 ID와 GBIF ID를 저장하고 POWO는 출처 링크로만 관리합니다.
- 사진 인식 후보는 `GBIF ID -> 학명` 순서로 카탈로그와 매칭합니다.
- `선인장`은 특정 종이 아닌 `Cactaceae` 과 수준 항목이므로 Pl@ntNet species ID와
  POWO ID를 저장하지 않습니다.
- 기존 종별 관리 프로필은 `2026-07-29.v1`, 신규 5개는 `2026-10-10.v1`입니다.
- 괴마옥은 학명이 확정되지 않은 유통 교잡종 항목입니다. 분류 ID를 추정하지 않으며
  `care_profile.taxonomy.photo_matching_enabled=false`로 사진 후보 매칭에서 제외합니다.
  이름 검색·수동 등록은 지원합니다.
- 물주기와 분갈이 일수는 종별 관리 정보를 일정으로 변환한 앱 초기값이며 식물학적
  절대값이 아닙니다. 분갈이 일수는 사용자가 마지막 분갈이 날짜를 입력한 경우에만
  최초 반복 일정을 계산할 때 사용합니다. 날짜를 입력하지 않으면 최초 분갈이 일정을
  만들지 않습니다.

## 목록

| 종류 | 표시명 | 학명 | Pl@ntNet ID | GBIF ID | POWO 참고 ID |
|---|---|---|---:|---:|---|
| 관엽식물 | 몬스테라 | `Monstera deliciosa` | 1385965 | 2868241 | 87478-1 |
| 관엽식물 | 스킨답서스 | `Epipremnum aureum` | 1409602 | 2868323 | 87014-1 |
| 관엽식물 | 필로덴드론 | `Philodendron hederaceum` | 1404586 | 2871003 | 87797-1 |
| 관엽식물 | 아이비 | `Hedera helix` | 1363575 | 8351737 | 90723-1 |
| 관엽식물 | 금전수 | `Zamioculcas zamiifolia` | 1752284 | 2869014 | 89402-1 |
| 관엽식물 | 산세베리아 | `Dracaena trifasciata` | 1718844 | 11041822 | 77164235-1 |
| 관엽식물 | 고무나무 | `Ficus elastica` | 1403870 | 5361903 | 60458499-2 |
| 관엽식물 | 알로카시아 | `Alocasia × mortfontanensis` | 1843636 | 5532250 | 84211-1 |
| 꽃 | 장미 | `Rosa chinensis` | 1395231 | 3005039 | 732029-1 |
| 꽃 | 데이지 | `Bellis perennis` | 1357317 | 3117424 | 184409-1 |
| 꽃 | 해바라기 | `Helianthus annuus` | 1364145 | 9206251 | 119003-2 |
| 꽃 | 튤립 | `Tulipa gesneriana` | 1396919 | 5299675 | 542923-1 |
| 꽃 | 수국 | `Hydrangea macrophylla` | 1361819 | 2985994 | 791637-1 |
| 다육이/선인장 | 선인장 | `Cactaceae` | - | 2519 | - |
| 다육이/선인장 | 에케베리아 | `Echeveria elegans` | 1418517 | 8315197 | 86934-2 |
| 다육이/선인장 | 하월시아 | `Haworthiopsis attenuata` | 1754606 | 9388529 | 77138002-1 |
| 나무 | 올리브나무 | `Olea europaea` | 1359676 | 5415040 | 610675-1 |
| 허브 | 민트 | `Mentha spicata` | 1358788 | 2927175 | 451162-1 |
| 허브 | 바질 | `Ocimum basilicum` | 1361975 | 2927096 | 452874-1 |
| 열매 | 딸기 | `Fragaria × ananassa` | 1667445 | 3029912 | 30117681-2 |
| 열매 | 레몬 | `Citrus × limon` | 1403436 | 7647136 | 60454758-2 |
| 열매 | 블루베리 | `Vaccinium corymbosum` | 1396966 | 2882849 | 261823-2 |
| 열매 | 체리 | `Prunus avium` | 1360316 | 3020791 | 30093848-2 |
| 관엽식물 | 스파티필름 | `Spathiphyllum wallisii` | 1410054 | 2869680 | 89011-1 |
| 다육이/선인장 | 스투키 | `Dracaena stuckyi` | 1752362 | 11064950 | 77183329-1 |
| 열매 | 토마토 | `Solanum lycopersicum` | 1396325 | 2930137 | 316947-2 |
| 관엽식물 | 극락조 | `Strelitzia reginae` | 1387289 | 2763116 | 798194-1 |
| 다육이/선인장 | 괴마옥 | `Euphorbia hybrid` (유통명, 학명 미확정) | - | - | - |

## 대표 종과 별칭

와이어프레임의 일부 명칭은 하나의 종이 아니라 넓은 통용명입니다. 초기 버전에서는
검색과 관리 자동화를 일관되게 만들기 위해 대표 종을 고정합니다.

| 통용명 | 대표 종 | 주요 검색 별칭 |
|---|---|---|
| 장미 | `Rosa chinensis` | 장미, 월계화 |
| 민트 | `Mentha spicata` | 민트, 스피어민트 |
| 선인장 | `Cactaceae` | 선인장, 칵투스 |
| 산세베리아 | `Dracaena trifasciata` | `Sansevieria trifasciata`, 스네이크 플랜트 |
| 알로카시아 | `Alocasia × mortfontanensis` | `Alocasia × amazonica`, 알로카시아 아마조니카 |
| 하월시아 | `Haworthiopsis attenuata` | `Haworthia attenuata`, 호월시아 |
| 레몬 | `Citrus × limon` | `Citrus limon`, 레몬나무 |
| 스파티필름 | `Spathiphyllum wallisii` | 스파티필룸, 스파트필름, 평화백합, 피스 릴리 |
| 스투키 | `Dracaena stuckyi` | `Sansevieria stuckyi`, 스턱키 |
| 토마토 | `Solanum lycopersicum` | 방울토마토, `Lycopersicon esculentum`, `Lycopersicon lycopersicum` |
| 극락조 | `Strelitzia reginae` | 극락조화, 극락조꽃, `Strelitzia regalis` |
| 괴마옥 | `Euphorbia hybrid` (학명 미확정) | 파인애플 선인장, 소철기린 |

`Dracaena angolensis`/`Sansevieria cylindrica`는 스투키 대표 종과 다른 종이므로 별칭으로
합치지 않습니다. `Strelitzia nicolai`도 극락조 대표 종의 동의어로 저장하지 않습니다.
괴마옥에 야생종 `Euphorbia hypogaea`나 추정 교잡 부모의 GBIF/Pl@ntNet ID를 붙이지 않습니다.
정확한 종이 확인되면 별도 데이터 검토로 추가합니다.

분류 식별자는 [Pl@ntNet taxonomy API](https://my.plantnet.org/doc/api/taxonomy)와
[Pl@ntNet identification API](https://my.plantnet.org/doc/api/identify)의 응답 규격을
기준으로 관리합니다.

## 관리·진단 데이터

센서 비교용 초기 정책은 `care_profile.sensor_thresholds`에 저장합니다. #120 담당은 JH-9568이며
[종별 센서 정책](species-sensor-thresholds.md)에 수치·단위·소비 연결을 정의합니다.
28개 카탈로그에 PROVISIONAL 정책을 저장하며 튤립·괴마옥은 성장/휴면 단계 미확정으로
비활성입니다. 기존 23개 정책은 덮어쓰지 않습니다.
수치가 검증된 원예 최적값이라는 뜻은 아니며 실제 기기·배지 보정은 #118에서 담당합니다.
아래 광량/수분 조건이 곧바로 lux·h 또는 상대 토양 수분 % 구간을 뜻하지는 않습니다.

각 카탈로그 항목에는 다음 정보가 함께 저장됩니다.

- 생육 환경과 실내·실외 화분 적합성
- 광량 등급, 토양 수분과 배수 조건, 습도 등급
- 계절별 물주기 초기 간격과 분갈이 초기 간격
- 관리 주의사항과 반려동물·사람 독성
- 흔한 해충과 질병
- 증상별 가능한 원인과 추가 확인 항목
- 출처 URL, 조회일, 데이터 버전과 검토일

진단 힌트는 확정 진단 문장이 아닙니다. 예를 들어 잎 황변은 과습 외에도 물 부족,
광량 부족, 토양 pH, 영양 문제, 뿌리 손상으로 발생할 수 있으므로 사진과 최근
물주기·환경·관리 이력을 함께 확인합니다.

관리 정보는 주로 [NC State Extension Plant Toolbox](https://plants.ces.ncsu.edu/),
[농촌진흥청 농사로](https://www.nongsaro.go.kr/portal/ps/psz/psza/contentMain.ps?menuId=PS00376),
[RHS](https://www.rhs.org.uk/plants/types/houseplants),
[UC IPM](https://ipm.ucanr.edu/home-and-landscape/houseplant-problems/),
[ASPCA 독성 데이터](https://www.aspca.org/pet-care/animal-poison-control/toxic-and-non-toxic-plants)를
사용합니다. 각 종에 실제로 사용한 상세 URL은 `source_references`에 저장합니다.

## 2026-10-10 추가 정보와 적용

| 식물 | 관리 자료의 범위 | 앱 물주기 초기값 (따뜻한/서늘한 계절, 일) | 분갈이 초기값 (일) |
|---|---|---:|---:|
| 스파티필름 | [NC State의 Spathiphyllum 속 관리](https://plants.ces.ncsu.edu/plants/spathiphyllum/) | 5 / 9 | 730 |
| 스투키 | [RHS 산세베리아류 관리](https://www.rhs.org.uk/plants/sansevieria/growing-guide) | 21 / 35 | 1095 |
| 토마토 | [NC State 종별 관리](https://plants.ces.ncsu.edu/plants/solanum-lycopersicum/) | 2 / 4 | 없음 |
| 극락조 | [NC State 종별 관리](https://plants.ces.ncsu.edu/plants/strelitzia-reginae/) | 7 / 14 | 730 |
| 괴마옥 | [경기도농업기술원 유통명/속 조사](https://nongup.gg.go.kr/wp-content/uploads/sites/2/2024/06/report_23_cact_10.pdf), [UC ANR 다육식물 일반 관리](https://ucanr.edu/node/124913/printable/print), [SANBI의 관련 종 생장·휴면 관리](https://pza.sanbi.org/euphorbia-bupleurifolia) | 14 / 30 | 730 |

일수는 위 출처에서 보장한 고정 주기가 아니라 앱 일정 생성용 추정값입니다. 흙과 뿌리 상태,
화분·배지·환경·성장 단계를 우선합니다. 스투키는 속 집단, 괴마옥은 관련 다육성 식물의 지침을
사용한 범위를 `source_references.fields`에 기록하며 종별 실측 결과로 표현하지 않습니다.
휴면 중 괴마옥의 30일 값은 급수 명령이 아니며 실제 건조·생장 확인 없이 물을 주지 않습니다.
토마토는 한해살이 화분 재배를 기본으로 반복 분갈이 간격을 설정하지 않습니다.
근거 없는 권장 물양(ml)과 환경별 개화 월은 생성하지 않습니다.

새 migration은 기존 행을 갱신하지 않고 5개 행만 추가합니다. 충돌 시 임의 upsert하지 않고
실패합니다. 등록된 식물이 새 항목을 참조하면 FK `RESTRICT`가 downgrade를 막습니다.
검색·등록 기본 일정·진단 참고·센서 판정은 기존 소비 경로를 사용합니다. 4개 확인된 대표 종은
사진 인식 ID/학명으로 매칭하고, 괴마옥은 사진 통용명 fallback에서도 제외합니다.
PR 코드 반영과 공유 DB 적용은 별개이며 DB에는 `alembic upgrade head` 후 보입니다.

검증: 격리 PostgreSQL 17에서 전체 611 tests passed, 0 skipped. 신규 행 저장·검색·사진 매칭,
기존 행 보존, 중복 insert 충돌 및 등록 식물이 참조 중인 항목의 downgrade 차단을 확인했습니다.
Ruff·diff whitespace·Alembic 단일 head 검증도 통과했습니다. 공유 DB에는 아직 적용하지 않았습니다.
