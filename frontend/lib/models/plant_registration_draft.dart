import 'package:yeso_plant/screens/plant_species_search_screen.dart';

/// 식물 등록 마법사(PLANT-01 → PLANT-06 → CHAR-01~04)가 모으는 값.
///
/// `POST /plants`는 애칭·종·환경·성격을 한 요청으로 받으므로, 마지막 화면까지
/// 이 객체 하나를 들고 다니다가 완성되면 한 번에 전송한다.
class PlantRegistrationDraft {
  PlantRegistrationDraft({required this.name, required this.species});

  // PLANT-01에서 확정 — 이 둘 없이는 다음 단계로 갈 수 없어 final로 고정
  final String name;
  final PlantSpeciesCandidate species;

  // PLANT-06에서 채움. 함께한 시작일(started_on)은 여기 없음 —
  // 사용자가 입력하지 않고, 등록 제출 시점을 서버가 그대로 1일차로 기록한다.
  String? placeName;
  String? potType;
  String? placement;
  DateTime? lastWateredOn;
  DateTime? lastRepottedOn;

  // CHAR-01에서 채움. 값은 api-spec.md의 PersonalityType enum 그대로.
  String? personalityType;

  // CHAR-02에서 채움 — 컬러만 구현. 헤어·장식 ID는 디자이너 에셋 납품 전이라 미확정.
  String? bodyColorId;
  String? headItem;
  String? accessory;
}
