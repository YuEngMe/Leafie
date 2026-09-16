import 'package:yeso_plant/models/plant_letter.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/user_api.dart';

typedef RecipientNicknameProvider = Future<String?> Function();

class LetterApi implements PlantLetterRepository {
  LetterApi({
    LeafieApiClient? client,
    RecipientNicknameProvider? recipientNicknameProvider,
  }) : _client = client ?? LeafieApiClient() {
    _recipientNicknameProvider =
        recipientNicknameProvider ??
        () async => (await UserApi(client: _client).getProfile()).nickname;
  }

  final LeafieApiClient _client;
  late final RecipientNicknameProvider _recipientNicknameProvider;
  Future<String>? _recipientLookup;

  @override
  Future<List<PlantLetter>> listLetters(String plantId) async {
    final recipient = await _getRecipient();
    final letters = <PlantLetter>[];
    final ids = <String>{};
    final requestedCursors = <String>{};
    String? cursor;

    do {
      if (cursor != null && !requestedCursors.add(cursor)) {
        throw _invalidResponse('편지 페이지가 반복되었습니다.');
      }
      final response = await _client.get(
        '/letters',
        queryParameters: {
          'plant_id': plantId,
          'limit': '100',
          'cursor': ?cursor,
        },
      );
      try {
        final rawItems = response['items'];
        final rawNextCursor = response['next_cursor'];
        if (rawItems is! List ||
            (rawNextCursor != null &&
                (rawNextCursor is! String || rawNextCursor.isEmpty))) {
          throw const FormatException('Invalid letter page');
        }
        for (final rawItem in rawItems) {
          if (rawItem is! Map<String, dynamic>) {
            throw const FormatException('Invalid letter item');
          }
          final letter = _parseLetter(
            rawItem,
            recipient: recipient,
            expectedPlantId: plantId,
            requireContent: false,
          );
          if (ids.add(letter.id)) letters.add(letter);
        }
        cursor = rawNextCursor as String?;
      } on FormatException {
        throw _invalidResponse('편지 목록을 확인할 수 없습니다.');
      }
    } while (cursor != null);

    return List.unmodifiable(letters);
  }

  @override
  Future<PlantLetter> getLetter(String plantId, String letterId) async {
    final response = await _client.get('/letters/$letterId');
    try {
      return _parseLetter(
        response,
        recipient: await _getRecipient(),
        expectedPlantId: plantId,
        expectedLetterId: letterId,
        requireContent: true,
      );
    } on FormatException {
      throw _invalidResponse('편지 내용을 확인할 수 없습니다.');
    }
  }

  @override
  Future<void> markRead(String plantId, String letterId) async {
    final response = await _client.post(
      '/letters/$letterId/read',
      body: const {},
    );
    try {
      final letter = _parseLetter(
        response,
        recipient: '식집사님',
        expectedPlantId: plantId,
        expectedLetterId: letterId,
        requireContent: true,
      );
      if (!letter.isRead) {
        throw const FormatException('Letter was not marked read');
      }
    } on FormatException {
      throw _invalidResponse('편지 읽음 상태를 확인할 수 없습니다.');
    }
  }

  @override
  Future<void> deleteLetter(String plantId, String letterId) async {
    await _client.delete('/letters/$letterId');
  }

  Future<String> _getRecipient() async {
    final activeLookup = _recipientLookup;
    if (activeLookup != null) return activeLookup;
    final lookup = _resolveRecipient();
    _recipientLookup = lookup;
    try {
      return await lookup;
    } finally {
      if (identical(_recipientLookup, lookup)) _recipientLookup = null;
    }
  }

  Future<String> _resolveRecipient() async {
    final nickname = (await _recipientNicknameProvider())?.trim();
    if (nickname == null || nickname.isEmpty) return '식집사님';
    return nickname;
  }
}

PlantLetter _parseLetter(
  Map<String, dynamic> json, {
  required String recipient,
  required String expectedPlantId,
  String? expectedLetterId,
  required bool requireContent,
}) {
  final id = _requiredText(json['id']);
  final plantId = _requiredText(json['plant_id']);
  final sender = _requiredText(json['plant_nickname']);
  _requiredText(json['diary_id']);
  _parseDate(json['diary_date']);
  if (json['status'] != 'COMPLETED') {
    throw const FormatException('Invalid letter status');
  }
  final preview = _requiredText(json['preview']);
  if (preview.runes.length > 100) {
    throw const FormatException('Invalid letter preview');
  }
  _parseDateTime(json['generated_at']);
  final publishedAt = _parseDateTime(json['published_at']);
  final isRead = json['is_read'];
  if (isRead is! bool ||
      plantId != expectedPlantId ||
      (expectedLetterId != null && id != expectedLetterId)) {
    throw const FormatException('Invalid letter ownership');
  }

  if (!requireContent) {
    return PlantLetter(
      id: id,
      plantId: plantId,
      recipient: recipient,
      sender: sender,
      body: preview,
      preview: preview,
      createdAt: publishedAt,
      isRead: isRead,
      contentLoaded: false,
    );
  }

  if (!json.containsKey('content') || !json.containsKey('read_at')) {
    throw const FormatException('Incomplete letter detail');
  }
  final content = _requiredText(json['content']);
  final readAt = json['read_at'];
  if (readAt != null) _parseDateTime(readAt);
  if (isRead != (readAt != null)) {
    throw const FormatException('Invalid letter read state');
  }
  return PlantLetter(
    id: id,
    plantId: plantId,
    recipient: recipient,
    sender: sender,
    body: content,
    preview: preview,
    createdAt: publishedAt,
    isRead: isRead,
    contentLoaded: true,
  );
}

String _requiredText(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Required text is missing');
  }
  return value;
}

DateTime _parseDateTime(Object? value) {
  if (value is! String) throw const FormatException('Invalid datetime');
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw const FormatException('Invalid datetime');
  }
  return parsed;
}

DateTime _parseDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid date');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      '${parsed.year.toString().padLeft(4, '0')}-'
              '${parsed.month.toString().padLeft(2, '0')}-'
              '${parsed.day.toString().padLeft(2, '0')}' !=
          value) {
    throw const FormatException('Invalid date');
  }
  return parsed;
}

LeafieApiException _invalidResponse(String message) => LeafieApiException(
  code: 'INVALID_RESPONSE',
  message: message,
  statusCode: 502,
);
