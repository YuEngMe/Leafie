import 'package:flutter/foundation.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/sha256.dart';

typedef DiagnosisDelay = Future<void> Function(Duration duration);

abstract interface class DiagnosisRepository {
  Future<List<DiagnosisSummary>> listDiagnoses(String plantId);

  Future<DiagnosisDetailData> getDiagnosis(String diagnosisId);

  Future<DiagnosisPlantData> getPlant(String plantId);

  Future<DiagnosisDetailData> submitDiagnosis({
    required String plantId,
    required List<int> photoBytes,
  });
}

class DiagnosisApi implements DiagnosisRepository {
  DiagnosisApi({
    LeafieApiClient? client,
    DiagnosisDelay? delay,
    this.pollInterval = const Duration(seconds: 2),
    this.maxPollAttempts = 45,
  }) : _client = client ?? LeafieApiClient(),
       _delay = delay ?? Future<void>.delayed;

  final LeafieApiClient _client;
  final DiagnosisDelay _delay;
  final Duration pollInterval;
  final int maxPollAttempts;

  @override
  Future<List<DiagnosisSummary>> listDiagnoses(String plantId) async {
    final records = <DiagnosisSummary>[];
    final seenCursors = <String>{};
    String? cursor;
    while (true) {
      final response = await _client.get(
        '/plants/$plantId/diagnoses',
        queryParameters: {'limit': '100', 'cursor': ?cursor},
      );
      try {
        final page = _DiagnosisPage.fromJson(response);
        records.addAll(page.items);
        if (!page.hasNext) return List.unmodifiable(records);
        final nextCursor = page.nextCursor;
        if (nextCursor == null || !seenCursors.add(nextCursor)) {
          throw const FormatException('Invalid diagnosis cursor');
        }
        cursor = nextCursor;
      } on FormatException {
        throw const LeafieApiException(
          code: 'INVALID_RESPONSE',
          message: '진단 기록을 확인할 수 없습니다.',
          statusCode: 502,
        );
      }
    }
  }

  @override
  Future<DiagnosisDetailData> getDiagnosis(String diagnosisId) async {
    final response = await _client.get('/diagnoses/$diagnosisId');
    try {
      return DiagnosisDetailData.fromJson(response);
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '진단 결과를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }

  @override
  Future<DiagnosisPlantData> getPlant(String plantId) async {
    final response = await _client.get('/plants/$plantId');
    try {
      return DiagnosisPlantData.fromJson(response);
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '식물 정보를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }

  @override
  Future<DiagnosisDetailData> submitDiagnosis({
    required String plantId,
    required List<int> photoBytes,
  }) async {
    if (photoBytes.isEmpty) {
      throw const LeafieApiException(
        code: 'EMPTY_IMAGE',
        message: '촬영한 사진을 확인할 수 없습니다.',
        statusCode: 400,
      );
    }
    if (photoBytes.length > 10 * 1024 * 1024) {
      throw const LeafieApiException(
        code: 'MEDIA_FILE_TOO_LARGE',
        message: '사진 용량은 10MB 이하여야 합니다.',
        statusCode: 413,
      );
    }
    final contentType = diagnosisImageContentType(photoBytes);
    if (contentType == null) {
      throw const LeafieApiException(
        code: 'DIAGNOSIS_IMAGE_TYPE_UNSUPPORTED',
        message: 'JPG, PNG, WebP 사진만 진단할 수 있습니다.',
        statusCode: 422,
      );
    }

    final checksum = await compute(sha256Hex, photoBytes);
    final presign = await _client.post(
      '/media/presign',
      body: {
        'purpose': 'DIAGNOSIS',
        'content_type': contentType,
        'size_bytes': photoBytes.length,
        'checksum_sha256': checksum,
      },
    );
    final upload = _MediaUpload.fromJson(presign);
    await _client.putBytes(
      upload.url,
      bytes: photoBytes,
      headers: upload.headers,
    );
    final completed = await _client.post(
      '/media/${upload.mediaFileId}/complete',
      body: const {},
    );
    if (completed['status'] != 'READY') {
      throw const LeafieApiException(
        code: 'MEDIA_NOT_READY',
        message: '사진 업로드를 완료하지 못했습니다.',
        statusCode: 409,
      );
    }

    final created = await _client.post(
      '/plants/$plantId/diagnoses',
      body: {'media_file_id': upload.mediaFileId},
    );
    final diagnosisId = created['diagnosis_id'];
    if (diagnosisId is! String || diagnosisId.isEmpty) {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '진단 요청 결과를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }

    for (var attempt = 0; attempt < maxPollAttempts; attempt++) {
      final diagnosis = await getDiagnosis(diagnosisId);
      if (!_isPending(diagnosis.status)) return diagnosis;
      if (attempt + 1 < maxPollAttempts) await _delay(pollInterval);
    }
    throw const LeafieApiException(
      code: 'DIAGNOSIS_TIMEOUT',
      message: '진단이 계속 진행 중이에요. 잠시 후 진단 기록에서 확인해 주세요.',
      statusCode: 408,
    );
  }
}

class _MediaUpload {
  const _MediaUpload({
    required this.mediaFileId,
    required this.url,
    required this.headers,
  });

  factory _MediaUpload.fromJson(Map<String, dynamic> json) {
    final mediaFileId = json['media_file_id'];
    final uploadUrl = json['upload_url'];
    final uploadMethod = json['upload_method'];
    final rawHeaders = json['upload_headers'];
    final uri = uploadUrl is String ? Uri.tryParse(uploadUrl) : null;
    if (mediaFileId is! String ||
        mediaFileId.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uploadMethod != 'PUT' ||
        rawHeaders is! Map) {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '사진 업로드 정보를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
    final headers = <String, String>{};
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const LeafieApiException(
          code: 'INVALID_RESPONSE',
          message: '사진 업로드 정보를 확인할 수 없습니다.',
          statusCode: 502,
        );
      }
      headers[entry.key as String] = entry.value as String;
    }
    return _MediaUpload(
      mediaFileId: mediaFileId,
      url: uri,
      headers: Map.unmodifiable(headers),
    );
  }

  final String mediaFileId;
  final Uri url;
  final Map<String, String> headers;
}

bool _isPending(String status) => status == 'PENDING' || status == 'PROCESSING';

String? diagnosisImageContentType(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

class _DiagnosisPage {
  const _DiagnosisPage({
    required this.items,
    required this.hasNext,
    required this.nextCursor,
  });

  factory _DiagnosisPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final hasNext = json['has_next'];
    final nextCursor = json['next_cursor'];
    if (rawItems is! List ||
        hasNext is! bool ||
        (nextCursor != null && nextCursor is! String)) {
      throw const FormatException('Invalid diagnosis page');
    }
    return _DiagnosisPage(
      items: List.unmodifiable(
        rawItems.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid diagnosis item');
          }
          return DiagnosisSummary.fromJson(item);
        }),
      ),
      hasNext: hasNext,
      nextCursor: nextCursor as String?,
    );
  }

  final List<DiagnosisSummary> items;
  final bool hasNext;
  final String? nextCursor;
}

class DiagnosisSummary {
  const DiagnosisSummary({
    required this.id,
    required this.status,
    required this.diagnosedAt,
    required this.photoUrl,
    required this.conditionLabel,
  });

  factory DiagnosisSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final status = json['status'];
    final diagnosedAt = DateTime.tryParse(
      json['diagnosed_at']?.toString() ?? '',
    );
    final photoUrl = json['photo_url'];
    final conditionLabel = json['condition_label'];
    if (id is! String ||
        id.isEmpty ||
        status is! String ||
        status.isEmpty ||
        diagnosedAt == null ||
        photoUrl is! String ||
        photoUrl.isEmpty ||
        (conditionLabel != null && conditionLabel is! String)) {
      throw const FormatException('Invalid diagnosis summary');
    }
    return DiagnosisSummary(
      id: id,
      status: status,
      diagnosedAt: diagnosedAt,
      photoUrl: photoUrl,
      conditionLabel: conditionLabel as String?,
    );
  }

  final String id;
  final String status;
  final DateTime diagnosedAt;
  final String photoUrl;
  final String? conditionLabel;
}

class DiagnosisDetailData {
  const DiagnosisDetailData({
    required this.id,
    required this.plantId,
    required this.status,
    required this.diagnosedAt,
    required this.photoUrl,
    required this.conditionLabel,
    required this.observations,
    required this.possibleCauses,
    required this.recommendedCare,
    this.retakeReasonCode,
    this.failureCode,
  });

  factory DiagnosisDetailData.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final plantId = json['plant_id'];
    final status = json['status'];
    final diagnosedAt = DateTime.tryParse(
      json['diagnosed_at']?.toString() ?? '',
    );
    final photoUrl = json['photo_url'];
    final conditionLabel = json['condition_label'];
    final observations = _stringList(json['observations']);
    final recommendedCare = _stringList(json['recommended_care']);
    final rawCauses = json['possible_causes'];
    if (id is! String ||
        id.isEmpty ||
        plantId is! String ||
        plantId.isEmpty ||
        status is! String ||
        status.isEmpty ||
        diagnosedAt == null ||
        photoUrl is! String ||
        photoUrl.isEmpty ||
        (conditionLabel != null && conditionLabel is! String) ||
        rawCauses is! List) {
      throw const FormatException('Invalid diagnosis detail');
    }

    return DiagnosisDetailData(
      id: id,
      plantId: plantId,
      status: status,
      diagnosedAt: diagnosedAt,
      photoUrl: photoUrl,
      conditionLabel: conditionLabel as String?,
      observations: observations,
      possibleCauses: List.unmodifiable(
        rawCauses.map((cause) {
          if (cause is! Map<String, dynamic>) {
            throw const FormatException('Invalid diagnosis cause');
          }
          return DiagnosisCauseData.fromJson(cause);
        }),
      ),
      recommendedCare: recommendedCare,
      retakeReasonCode: json['retake_reason_code']?.toString(),
      failureCode: json['failure_code']?.toString(),
    );
  }

  final String id;
  final String plantId;
  final String status;
  final DateTime diagnosedAt;
  final String photoUrl;
  final String? conditionLabel;
  final List<String> observations;
  final List<DiagnosisCauseData> possibleCauses;
  final List<String> recommendedCare;
  final String? retakeReasonCode;
  final String? failureCode;
}

class DiagnosisCauseData {
  const DiagnosisCauseData({required this.name, required this.confidence});

  factory DiagnosisCauseData.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final confidence = json['confidence'];
    if (name is! String ||
        name.isEmpty ||
        (confidence != null && confidence is! num)) {
      throw const FormatException('Invalid diagnosis cause');
    }
    return DiagnosisCauseData(
      name: name,
      confidence: (confidence as num?)?.toDouble(),
    );
  }

  final String name;
  final double? confidence;
}

class DiagnosisPlantData {
  const DiagnosisPlantData({
    required this.id,
    required this.nickname,
    required this.speciesDisplayName,
    required this.startedOn,
  });

  factory DiagnosisPlantData.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nickname = json['nickname'];
    final speciesDisplayName = json['species_display_name'];
    final startedOn = DateTime.tryParse(json['started_on']?.toString() ?? '');
    if (id is! String ||
        id.isEmpty ||
        nickname is! String ||
        nickname.isEmpty ||
        speciesDisplayName is! String ||
        speciesDisplayName.isEmpty ||
        startedOn == null) {
      throw const FormatException('Invalid plant detail');
    }
    return DiagnosisPlantData(
      id: id,
      nickname: nickname,
      speciesDisplayName: speciesDisplayName,
      startedOn: startedOn,
    );
  }

  final String id;
  final String nickname;
  final String speciesDisplayName;
  final DateTime startedOn;
}

List<String> _stringList(Object? value) {
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Invalid string list');
  }
  return List.unmodifiable(value.cast<String>());
}
