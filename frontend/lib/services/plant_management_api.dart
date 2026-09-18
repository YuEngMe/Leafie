import 'package:yeso_plant/services/leafie_api_client.dart';

abstract interface class PlantManagementRepository {
  Future<List<ManagedPlant>> listPlants();

  Future<ManagedPlant> getPlant(String plantId);

  Future<String?> selectPlant(String? plantId);

  Future<ManagedPlant> updatePlant(
    String plantId, {
    String? nickname,
    String? placeName,
    String? personalityType,
  });

  Future<ManagedPlant> updateAppearance(
    String plantId, {
    String? colorId,
    String? hairId,
  });

  Future<void> deletePlant(String plantId);
}

class PlantManagementApi implements PlantManagementRepository {
  PlantManagementApi({LeafieApiClient? client})
    : _client = client ?? LeafieApiClient();

  final LeafieApiClient _client;

  @override
  Future<ManagedPlant> getPlant(String plantId) async {
    final response = await _client.get('/plants/$plantId');
    return _parseDetail(response);
  }

  @override
  Future<List<ManagedPlant>> listPlants() async {
    final response = await _client.get('/plants');
    final profile = await _client.get('/users/me');
    final items = response['items'];
    final selectedPlantId = profile['selected_plant_id'];
    if (items is! List ||
        !profile.containsKey('selected_plant_id') ||
        (selectedPlantId != null &&
            (selectedPlantId is! String || selectedPlantId.isEmpty))) {
      throw _invalidResponse();
    }
    try {
      return List.unmodifiable(
        items.map((item) {
          if (item is! Map<String, dynamic>) throw const FormatException();
          final plant = ManagedPlant.fromListJson(item);
          return plant.copyWith(isSelected: plant.id == selectedPlantId);
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
    if (!response.containsKey('selected_plant_id') ||
        (selected != null && (selected is! String || selected.isEmpty))) {
      throw _invalidResponse();
    }
    return selected as String?;
  }

  @override
  Future<ManagedPlant> updatePlant(
    String plantId, {
    String? nickname,
    String? placeName,
    String? personalityType,
  }) async {
    final normalizedNickname = nickname?.trim();
    final normalizedPlaceName = placeName?.trim();
    if (normalizedNickname != null &&
        (normalizedNickname.isEmpty || normalizedNickname.length > 30)) {
      throw const LeafieApiException(
        code: 'INVALID_NICKNAME',
        message: '식물 이름은 1자 이상 30자 이하로 입력해주세요.',
        statusCode: 400,
      );
    }
    if (normalizedPlaceName != null &&
        (normalizedPlaceName.isEmpty || normalizedPlaceName.length > 50)) {
      throw const LeafieApiException(
        code: 'INVALID_PLACE_NAME',
        message: '장소는 1자 이상 50자 이하로 입력해주세요.',
        statusCode: 400,
      );
    }
    final body = <String, Object?>{
      'nickname': ?normalizedNickname,
      'place_name': ?normalizedPlaceName,
      'personality_type': ?personalityType,
    };
    if (body.isEmpty) {
      throw const LeafieApiException(
        code: 'PLANT_CHANGE_REQUIRED',
        message: '변경할 식물 정보를 입력해주세요.',
        statusCode: 400,
      );
    }
    final response = await _client.patch('/plants/$plantId', body: body);
    return _parseDetail(response);
  }

  @override
  Future<ManagedPlant> updateAppearance(
    String plantId, {
    String? colorId,
    String? hairId,
  }) async {
    final normalizedColorId = colorId?.trim();
    final normalizedHairId = hairId?.trim();
    if ((normalizedColorId != null &&
            (normalizedColorId.isEmpty || normalizedColorId.length > 100)) ||
        (normalizedHairId != null &&
            (normalizedHairId.isEmpty || normalizedHairId.length > 100))) {
      throw const LeafieApiException(
        code: 'INVALID_APPEARANCE',
        message: '올바른 외형을 선택해주세요.',
        statusCode: 400,
      );
    }
    final body = <String, Object?>{
      'color_id': ?normalizedColorId,
      'hair_id': ?normalizedHairId,
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
    required this.startedOn,
    this.category,
    this.scientificName,
    this.familyName,
    this.floweringPeriod,
    this.placeName,
    this.createdAt,
    this.updatedAt,
    this.isSelected = false,
  });

  factory ManagedPlant.fromListJson(Map<String, dynamic> json) =>
      ManagedPlant._fromJson(json, requireDetail: false);

  factory ManagedPlant.fromDetailJson(Map<String, dynamic> json) =>
      ManagedPlant._fromJson(json, requireDetail: true);

  factory ManagedPlant._fromJson(
    Map<String, dynamic> json, {
    required bool requireDetail,
  }) {
    final id = json['id'];
    final nickname = json['nickname'];
    final speciesReferenceId = json['species_reference_id'];
    final speciesDisplayName = json['species_display_name'];
    final primaryPhotoUrl = json['primary_photo_url'];
    final personalityType = json['personality_type'];
    final colorId = json['color_id'];
    final hairId = json['hair_id'];
    final startedOn = _date(json['started_on']);
    final category = json['category'];
    final scientificName = json['scientific_name'];
    final familyName = json['family_name'];
    final floweringPeriod = json['flowering_period'];
    final placeName = json['place_name'];
    final createdAt = _dateTime(json['created_at']);
    final updatedAt = _dateTime(json['updated_at']);
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
        startedOn == null ||
        (requireDetail &&
            (category is! String ||
                category.isEmpty ||
                (scientificName != null && scientificName is! String) ||
                (familyName != null && familyName is! String) ||
                (floweringPeriod != null && floweringPeriod is! String) ||
                placeName is! String ||
                placeName.isEmpty ||
                createdAt == null ||
                updatedAt == null))) {
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
      startedOn: startedOn,
      category: requireDetail ? category as String : null,
      scientificName: requireDetail ? scientificName as String? : null,
      familyName: requireDetail ? familyName as String? : null,
      floweringPeriod: requireDetail ? floweringPeriod as String? : null,
      placeName: requireDetail ? placeName as String : null,
      createdAt: requireDetail ? createdAt : null,
      updatedAt: requireDetail ? updatedAt : null,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null ||
        '${parsed.year.toString().padLeft(4, '0')}-'
                '${parsed.month.toString().padLeft(2, '0')}-'
                '${parsed.day.toString().padLeft(2, '0')}' !=
            value) {
      return null;
    }
    return parsed;
  }

  static DateTime? _dateTime(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  final String id;
  final String nickname;
  final String speciesReferenceId;
  final String speciesDisplayName;
  final String? primaryPhotoUrl;
  final String personalityType;
  final String colorId;
  final String hairId;
  final DateTime startedOn;
  final String? category;
  final String? scientificName;
  final String? familyName;
  final String? floweringPeriod;
  final String? placeName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSelected;

  int get daysTogether {
    // User profiles are currently created with the backend's fixed
    // Asia/Seoul timezone, so mirror its date boundary instead of the device's.
    final nowInSeoul = DateTime.now().toUtc().add(const Duration(hours: 9));
    final today = DateTime(nowInSeoul.year, nowInSeoul.month, nowInSeoul.day);
    final startDate = DateTime(startedOn.year, startedOn.month, startedOn.day);
    final days = today.difference(startDate).inDays;
    return days < 0 ? 0 : days;
  }

  ManagedPlant copyWith({
    String? nickname,
    String? colorId,
    String? hairId,
    String? placeName,
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
    startedOn: startedOn,
    category: category,
    scientificName: scientificName,
    familyName: familyName,
    floweringPeriod: floweringPeriod,
    placeName: placeName ?? this.placeName,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isSelected: isSelected ?? this.isSelected,
  );
}
