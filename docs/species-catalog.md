# 초기 식물 카탈로그

## 기준

- 초기 지원 범위는 23개 항목입니다.
- Pl@ntNet에서 조회한 내부 ID와 GBIF ID를 저장하고 POWO는 출처 링크로만 관리합니다.
- 사진 인식 후보는 `GBIF ID -> 학명` 순서로 카탈로그와 매칭합니다.
- `선인장`은 특정 종이 아닌 `Cactaceae` 과 수준 항목이므로 Pl@ntNet species ID와
  POWO ID를 저장하지 않습니다.
- 종별 관리 프로필, 진단 힌트와 출처는 `2026-07-29.v1` 버전으로 관리합니다.
- 물주기·분갈이 일수는 토양 수분 선호도를 일정으로 변환한 앱 초기값이며
  식물학적 절대값이 아닙니다.

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

분류 식별자는 [Pl@ntNet taxonomy API](https://my.plantnet.org/doc/api/taxonomy)와
[Pl@ntNet identification API](https://my.plantnet.org/doc/api/identify)의 응답 규격을
기준으로 관리합니다.

## 관리·진단 데이터

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
