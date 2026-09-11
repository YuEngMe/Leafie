import 'package:yeso_plant/services/leafie_api_client.dart';

abstract interface class PlantManagementRepository {
  Future<List<ManagedPlant>> listPlants();

  Future<String?> selectPlant(String? plantId);

  Future<ManagedPlant> updateNickname(String plantId, String nickname);

  Future<ManagedPlant> updateAppearance(
    String plantId, {
    String? colorId,
    String? hairId,
    String? accessoryId,
  });

  Future<void> deletePlant(String plantId);
}

class PlantManagementApi implements PlantManagementRepository {
  PlantManagementApi({LeafieApiClient? client})
    : _client = client ?? LeafieApiClient();

  final LeafieApiClient _client;

  @override
  Future<List<ManagedPlant>> listPlants() async {
    final response = await _client.get('/plants');
    final plants = response['plants'];
    if (plants is! List) throw _invalidResponse();
    try {
      return List.unmodifiable(
        plants.map((item) {
          if (item is! Map<String, dynamic>) throw const FormatException();
          return ManagedPlant.fromListJson(item);
        }),
      );
    } on FormatException {
      throw _invalidResponse();
    }
  }

  @override
  Future<String?> selectPlant(String? plantId) async {
    final response = await _client.patch(
      '/users/me/selected-plant',
      body: {'selected_plant_id': plantId},
    );
    final selected = response['selected_plant_id'];
    if (selected != null && selected is! String) throw _invalidResponse();
    return selected as String?;
  }

  @override
  Future<ManagedPlant> updateNickname(String plantId, String nickname) async {
    final normalized = nickname.trim();
    if (normalized.isEmpty) {
      throw const LeafieApiException(
        code: 'INVALID_NICKNAME',
        message: '식물 이름을 입력해주세요.',
        statusCode: 400,
      );
    }
    final response = await _client.patch(
      '/plants/$plantId',
      body: {'nickname': normalized},
    );
    return _parseDetail(response);
  }

  @override
  Future<ManagedPlant> updateAppearance(
    String plantId, {
    String? colorId,
    String? hairId,
    String? accessoryId,
  }) async {
    final body = <String, Object?>{
      'color_id': ?colorId,
      'hair_id': ?hairId,
      'accessory_id': ?accessoryId,
    };
    if (body.isEmpty) {
      throw const LeafieApiException(
        code: 'APPEARANCE_CHANGE_REQUIRED',
        message: '변경할 외형을 선택해주세요.',
        statusCode: 400,
      );
    }
    final response = await _client.patch(
      '/plants/$plantId/appearance',
      body: body,
    );
    return _parseDetail(response);
  }

  @override
  Future<void> deletePlant(String plantId) =>
      _client.delete('/plants/$plantId');

  ManagedPlant _parseDetail(Map<String, dynamic> response) {
    try {
      return ManagedPlant.fromDetailJson(response);
    } on FormatException {
      throw _invalidResponse();
    }
  }

  LeafieApiException _invalidResponse() => const LeafieApiException(
    code: 'INVALID_RESPONSE',
    message: '식물 정보를 확인할 수 없습니다.',
    statusCode: 502,
  );
}

class ManagedPlant {
  const ManagedPlant({
    required this.id,
    required this.nickname,
    required this.speciesReferenceId,
    required this.speciesDisplayName,
    required this.primaryPhotoUrl,
    required this.personalityType,
    required this.colorId,
    required this.hairId,
    required this.accessoryId,
    required this.daysTogether,
    required this.isSelected,
  });

  factory ManagedPlant.fromListJson(Map<String, dynamic> json) =>
      ManagedPlant._fromJson(json, requireSelection: true);

  factory ManagedPlant.fromDetailJson(Map<String, dynamic> json) =>
      ManagedPlant._fromJson(json, requireSelection: false);

  factory ManagedPlant._fromJson(
    Map<String, dynamic> json, {
    required bool requireSelection,
  }) {
    final id = json['id'];
    final nickname = json['nickname'];
    final speciesReferenceId = json['species_reference_id'];
    final speciesDisplayName = json['species_display_name'];
    final primaryPhotoUrl = json['primary_photo_url'];
    final personalityType = json['personality_type'];
    final colorId = json['color_id'];
    final hairId = json['hair_id'];
    final accessoryId = json['accessory_id'];
    final daysTogether = json['days_together'];
    final isSelected = json['is_selected'];
    if (id is! String ||
        id.isEmpty ||
        nickname is! String ||
        nickname.isEmpty ||
        speciesReferenceId is! String ||
        speciesReferenceId.isEmpty ||
        speciesDisplayName is! String ||
        speciesDisplayName.isEmpty ||
        (primaryPhotoUrl != null && primaryPhotoUrl is! String) ||
        personalityType is! String ||
        personalityType.isEmpty ||
        colorId is! String ||
        colorId.isEmpty ||
        hairId is! String ||
        hairId.isEmpty ||
        accessoryId is! String ||
        accessoryId.isEmpty ||
        daysTogether is! int ||
        daysTogether < 0 ||
        (requireSelection && isSelected is! bool)) {
      throw const FormatException('Invalid plant payload');
    }
    return ManagedPlant(
      id: id,
      nickname: nickname,
      speciesReferenceId: speciesReferenceId,
      speciesDisplayName: speciesDisplayName,
      primaryPhotoUrl: primaryPhotoUrl as String?,
      personalityType: personalityType,
      colorId: colorId,
      hairId: hairId,
      accessoryId: accessoryId,
      daysTogether: daysTogether,
      isSelected: isSelected is bool && isSelected,
    );
  }

  final String id;
  final String nickname;
  final String speciesReferenceId;
  final String speciesDisplayName;
  final String? primaryPhotoUrl;
  final String personalityType;
  final String colorId;
  final String hairId;
  final String accessoryId;
  final int daysTogether;
  final bool isSelected;

  ManagedPlant copyWith({
    String? nickname,
    String? colorId,
    String? hairId,
    String? accessoryId,
    bool? isSelected,
  }) => ManagedPlant(
    id: id,
    nickname: nickname ?? this.nickname,
    speciesReferenceId: speciesReferenceId,
    speciesDisplayName: speciesDisplayName,
    primaryPhotoUrl: primaryPhotoUrl,
    personalityType: personalityType,
    colorId: colorId ?? this.colorId,
    hairId: hairId ?? this.hairId,
    accessoryId: accessoryId ?? this.accessoryId,
    daysTogether: daysTogether,
    isSelected: isSelected ?? this.isSelected,
  );
}
