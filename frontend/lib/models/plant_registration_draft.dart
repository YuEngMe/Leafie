import 'dart:math';

import 'package:yeso_plant/models/plant_species_candidate.dart';

/// 식물 등록 마법사(PLANT-01 → PLANT-06 → CHAR-01~04)가 모으는 값.
///
/// `POST /plants`는 애칭·종·환경·성격을 한 요청으로 받으므로, 마지막 화면까지
/// 이 객체 하나를 들고 다니다가 완성되면 한 번에 전송한다.
class PlantRegistrationDraft {
  PlantRegistrationDraft({
    required this.name,
    required this.species,
    String? clientRegistrationId,
    DateTime? startedOn,
    this.speciesIdentificationId,
    this.primaryMediaFileId,
  }) : clientRegistrationId = clientRegistrationId ?? _uuidV4(),
       startedOn = startedOn ?? DateTime.now();

  // PLANT-01에서 확정 — 이 둘 없이는 다음 단계로 갈 수 없어 final로 고정
  final String name;
  final PlantSpeciesCandidate species;

  /// 네트워크 재시도에서도 같은 값을 써야 서버가 식물을 중복 생성하지 않는다.
  final String clientRegistrationId;

  /// 등록 흐름을 시작한 날짜. 재시도 중 자정이 지나도 요청 내용은 바뀌지 않는다.
  final DateTime startedOn;

  /// 사진 인식 등록일 때만 채워지는 서버 식별자와 원본 사진이다.
  final String? speciesIdentificationId;
  final String? primaryMediaFileId;

  // PLANT-06에서 채움. 함께한 시작일(started_on)은 여기 없음 —
  // 사용자가 입력하지 않고, 등록 제출 시점을 서버가 그대로 1일차로 기록한다.
  String? placeName;
  String? potType;
  String? placement;
  DateTime? lastWateredOn;
  DateTime? lastRepottedOn;

  // CHAR-01에서 채움. 값은 api-spec.md의 PersonalityType enum 그대로.
  String? personalityType;

  // CHAR-02에서 컬러와 헤어를 선택. 장식은 아직 선택 UI 없음.
  String? bodyColorId;
  String? headItem;
  String? accessory;

  PlantRegistrationSnapshot? _submissionSnapshot;

  /// 첫 제출 시점의 값을 고정한다. 서버 응답을 받지 못해 재시도하더라도
  /// 같은 UUID와 같은 본문을 보내야 멱등성 충돌이나 중복 생성을 피할 수 있다.
  PlantRegistrationSnapshot freezeForSubmission() =>
      _submissionSnapshot ??= PlantRegistrationSnapshot.fromDraft(this);

  PlantRegistrationSnapshot? get submissionSnapshot => _submissionSnapshot;
}

class PlantRegistrationSnapshot {
  const PlantRegistrationSnapshot({
    required this.clientRegistrationId,
    required this.name,
    required this.speciesReferenceId,
    required this.startedOn,
    required this.placeName,
    required this.potType,
    required this.placement,
    required this.lastWateredOn,
    required this.lastRepottedOn,
    required this.personalityType,
    required this.bodyColorId,
    required this.headItem,
    required this.accessory,
    required this.speciesIdentificationId,
    required this.primaryMediaFileId,
  });

  factory PlantRegistrationSnapshot.fromDraft(PlantRegistrationDraft draft) =>
      PlantRegistrationSnapshot(
        clientRegistrationId: draft.clientRegistrationId,
        name: draft.name,
        speciesReferenceId: draft.species.referenceId,
        startedOn: draft.startedOn,
        placeName: draft.placeName!,
        potType: draft.potType,
        placement: draft.placement,
        lastWateredOn: draft.lastWateredOn!,
        lastRepottedOn: draft.lastRepottedOn,
        personalityType: draft.personalityType!,
        bodyColorId: draft.bodyColorId!,
        headItem: draft.headItem,
        accessory: draft.accessory,
        speciesIdentificationId: draft.speciesIdentificationId,
        primaryMediaFileId: draft.primaryMediaFileId,
      );

  final String clientRegistrationId;
  final String name;
  final String speciesReferenceId;
  final DateTime startedOn;
  final String placeName;
  final String? potType;
  final String? placement;
  final DateTime lastWateredOn;
  final DateTime? lastRepottedOn;
  final String personalityType;
  final String bodyColorId;
  final String? headItem;
  final String? accessory;
  final String? speciesIdentificationId;
  final String? primaryMediaFileId;
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
