import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/models/plant_species_candidate.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/media_api.dart';

typedef PlantApiDelay = Future<void> Function(Duration duration);

class PlantApi {
  PlantApi({
    LeafieApiClient? client,
    MediaApi? mediaApi,
    PlantApiDelay? delay,
    this.pollInterval = const Duration(seconds: 2),
    this.maxPollAttempts = 45,
  }) : _client = client ?? LeafieApiClient(),
       _mediaApi = mediaApi ?? MediaApi(client: client),
       _delay = delay ?? Future<void>.delayed;

  final LeafieApiClient _client;
  final MediaApi _mediaApi;
  final PlantApiDelay _delay;
  final Duration pollInterval;
  final int maxPollAttempts;

  Future<List<PlantSpeciesCandidate>> searchSpecies(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) {
      throw const LeafieApiException(
        code: 'SPECIES_QUERY_TOO_SHORT',
        message: '검색어를 두 글자 이상 입력해 주세요.',
        statusCode: 422,
      );
    }
    final response = await _client.get(
      '/species',
      queryParameters: {'query': normalized, 'limit': '20'},
    );
    final items = response['items'];
    if (items is! List) {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '식물 검색 결과를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
    try {
      final candidates = <PlantSpeciesCandidate>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid species candidate');
        }
        candidates.add(PlantSpeciesCandidate.fromJson(item));
      }
      return List.unmodifiable(candidates);
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '식물 검색 결과를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }

  Future<String> registerPlant(PlantRegistrationDraft draft) async {
    // GET /users/me는 Supabase auth metadata로 서버 프로필을 최초 1회 만든다.
    final profile = await _client.get('/users/me');
    if (profile['profile_completed'] != true) {
      throw const LeafieApiException(
        code: 'PROFILE_INCOMPLETE',
        message: '닉네임 설정을 완료해 주세요.',
        statusCode: 409,
      );
    }

    final response = await _client.post(
      '/plants',
      body: buildPlantCreateRequest(draft),
    );
    final id = response['id'];
    if (id is! String || id.isEmpty) {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '등록된 식물 정보를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
    return id;
  }

  Future<PlantIdentificationResult> identifySpecies(
    List<int> photoBytes,
  ) async {
    if (imageContentType(photoBytes) == 'image/webp') {
      throw const LeafieApiException(
        code: 'SPECIES_IMAGE_TYPE_UNSUPPORTED',
        message: '식물 사진 인식은 JPG 또는 PNG 사진만 지원합니다.',
        statusCode: 422,
      );
    }
    final media = await _mediaApi.uploadImage(
      bytes: photoBytes,
      purpose: 'SPECIES_IDENTIFICATION',
    );
    final created = await _client.post(
      '/species/identifications',
      body: {'media_file_id': media.id},
    );
    final identificationId = created['identification_id'];
    if (identificationId is! String || identificationId.isEmpty) {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '식물 인식 요청 결과를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }

    for (var attempt = 0; attempt < maxPollAttempts; attempt++) {
      final response = await _client.get(
        '/species/identifications/$identificationId',
      );
      final status = response['status'];
      if (status == 'COMPLETED') {
        final candidates = response['candidates'];
        final index = response['current_candidate_index'];
        if (candidates is! List || candidates.isEmpty || index is! int) {
          throw const LeafieApiException(
            code: 'INVALID_RESPONSE',
            message: '식물 인식 결과를 확인할 수 없습니다.',
            statusCode: 502,
          );
        }
        final selectedIndex = index.clamp(0, candidates.length - 1);
        final raw = candidates[selectedIndex];
        if (raw is! Map<String, dynamic>) {
          throw const LeafieApiException(
            code: 'INVALID_RESPONSE',
            message: '식물 인식 결과를 확인할 수 없습니다.',
            statusCode: 502,
          );
        }
        try {
          return PlantIdentificationResult(
            identificationId: identificationId,
            mediaFileId: media.id,
            candidate: PlantSpeciesCandidate.fromJson(raw),
          );
        } on FormatException {
          throw const LeafieApiException(
            code: 'INVALID_RESPONSE',
            message: '식물 인식 결과를 확인할 수 없습니다.',
            statusCode: 502,
          );
        }
      }
      if (status == 'FAILED') {
        throw LeafieApiException(
          code:
              response['failure_code']?.toString() ??
              'SPECIES_IDENTIFICATION_FAILED',
          message: '식물을 인식하지 못했어요. 다른 사진으로 다시 시도해 주세요.',
          statusCode: 422,
        );
      }
      if (status != 'PENDING' && status != 'PROCESSING') {
        throw const LeafieApiException(
          code: 'INVALID_RESPONSE',
          message: '식물 인식 상태를 확인할 수 없습니다.',
          statusCode: 502,
        );
      }
      if (attempt + 1 < maxPollAttempts) await _delay(pollInterval);
    }
    throw const LeafieApiException(
      code: 'SPECIES_IDENTIFICATION_TIMEOUT',
      message: '식물 인식이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
      statusCode: 408,
    );
  }
}

class PlantIdentificationResult {
  const PlantIdentificationResult({
    required this.identificationId,
    required this.mediaFileId,
    required this.candidate,
  });

  final String identificationId;
  final String mediaFileId;
  final PlantSpeciesCandidate candidate;
}

Map<String, Object?> buildPlantCreateRequest(PlantRegistrationDraft draft) {
  final existingSnapshot = draft.submissionSnapshot;
  if (existingSnapshot != null) return _buildPayload(existingSnapshot);

  final nickname = draft.name.trim();
  final placeName = draft.placeName?.trim();
  final lastWateredOn = draft.lastWateredOn;
  final personalityType = draft.personalityType?.trim();
  final colorId = draft.bodyColorId?.trim();
  if (nickname.isEmpty ||
      placeName == null ||
      placeName.isEmpty ||
      lastWateredOn == null) {
    throw const LeafieApiException(
      code: 'REGISTRATION_INCOMPLETE',
      message: '식물의 애칭, 장소와 마지막 물 준 날을 입력해 주세요.',
      statusCode: 422,
    );
  }
  if (nickname.runes.length > 30) {
    throw const LeafieApiException(
      code: 'PLANT_NICKNAME_TOO_LONG',
      message: '식물 애칭은 30자 이하로 입력해 주세요.',
      statusCode: 422,
    );
  }
  if (placeName.runes.length > 50) {
    throw const LeafieApiException(
      code: 'PLANT_PLACE_NAME_TOO_LONG',
      message: '식물이 있는 장소는 50자 이하로 입력해 주세요.',
      statusCode: 422,
    );
  }
  if (personalityType == null ||
      personalityType.isEmpty ||
      colorId == null ||
      colorId.isEmpty) {
    throw const LeafieApiException(
      code: 'REGISTRATION_INCOMPLETE',
      message: '캐릭터의 성격과 색상을 선택해 주세요.',
      statusCode: 422,
    );
  }

  final identificationId = draft.speciesIdentificationId?.trim();
  final mediaFileId = draft.primaryMediaFileId?.trim();
  final hasIdentification =
      identificationId != null && identificationId.isNotEmpty;
  final hasMedia = mediaFileId != null && mediaFileId.isNotEmpty;
  if (hasIdentification != hasMedia) {
    throw const LeafieApiException(
      code: 'REGISTRATION_INCOMPLETE',
      message: '사진으로 등록하려면 식물 인식 결과와 사진이 모두 필요해요.',
      statusCode: 422,
    );
  }

  final today = _dateOnly(DateTime.now());
  if (_dateOnly(draft.startedOn).isAfter(today) ||
      _dateOnly(lastWateredOn).isAfter(today) ||
      (draft.lastRepottedOn != null &&
          _dateOnly(draft.lastRepottedOn!).isAfter(today))) {
    throw const LeafieApiException(
      code: 'FUTURE_DATE_NOT_ALLOWED',
      message: '오늘 이후 날짜는 선택할 수 없습니다.',
      statusCode: 400,
    );
  }

  return _buildPayload(draft.freezeForSubmission());
}

Map<String, Object?> _buildPayload(PlantRegistrationSnapshot draft) {
  final identificationId = draft.speciesIdentificationId?.trim();
  final mediaFileId = draft.primaryMediaFileId?.trim();
  final photoRegistration =
      identificationId != null &&
      identificationId.isNotEmpty &&
      mediaFileId != null &&
      mediaFileId.isNotEmpty;
  return {
    'client_registration_id': draft.clientRegistrationId,
    'nickname': draft.name.trim(),
    'species_reference_id': draft.speciesReferenceId,
    'species_selection_method': photoRegistration ? 'PHOTO' : 'SEARCH',
    'species_identification_id': photoRegistration ? identificationId : null,
    'primary_media_file_id': photoRegistration ? mediaFileId : null,
    'started_on': _isoDate(draft.startedOn),
    'place_name': draft.placeName.trim(),
    'last_watered_on': _isoDate(draft.lastWateredOn),
    'last_repotted_on': draft.lastRepottedOn == null
        ? null
        : _isoDate(draft.lastRepottedOn!),
    'personality_type': draft.personalityType,
    'color_id': draft.bodyColorId.trim(),
    // 헤어 선택 UI를 거치지 않아도 서버의 필수 계약을 지킨다.
    'hair_id': _nonBlankOr(draft.headItem, 'NONE'),
  };
}

String _isoDate(DateTime date) => date.toIso8601String().split('T').first;

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _nonBlankOr(String? value, String fallback) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? fallback : normalized;
}
