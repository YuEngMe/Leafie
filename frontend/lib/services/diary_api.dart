import 'dart:convert';
import 'dart:io';

import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/services/home_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/media_api.dart';

abstract interface class DiaryStore {
  Future<List<DiaryEntry>> loadMonth(DateTime month);

  Future<DiaryEntry?> loadDay(DateTime date);

  Future<void> save(DiaryEntry entry);

  Future<void> delete(DateTime date);
}

class ApiDiaryStore implements DiaryStore {
  ApiDiaryStore({
    String? plantId,
    this.resolvePlantIdIfMissing = true,
    LeafieApiClient? client,
    HomeApi? homeApi,
    MediaApi? mediaApi,
  }) : _client = client ?? LeafieApiClient(),
       _homeApi = homeApi ?? HomeApi(client: client),
       _mediaApi = mediaApi ?? MediaApi(client: client),
       _plantId = plantId;

  final LeafieApiClient _client;
  final HomeApi _homeApi;
  final MediaApi _mediaApi;
  final bool resolvePlantIdIfMissing;
  String? _plantId;

  Future<String> _resolvePlantId() async {
    final cached = _plantId;
    if (cached != null) return cached;
    if (!resolvePlantIdIfMissing) {
      throw const LeafieApiException(
        code: 'PLANT_NOT_FOUND',
        message: '먼저 식물을 등록해주세요.',
        statusCode: 404,
      );
    }
    final home = await _homeApi.fetchHome();
    final id = home.plant?.id;
    if (id == null || id.isEmpty) {
      throw const LeafieApiException(
        code: 'PLANT_NOT_FOUND',
        message: '먼저 식물을 등록해주세요.',
        statusCode: 404,
      );
    }
    return _plantId = id;
  }

  @override
  Future<List<DiaryEntry>> loadMonth(DateTime month) async {
    final plantId = await _resolvePlantId();
    final response = await _client.get(
      '/plants/$plantId/diaries',
      queryParameters: {'year': '${month.year}', 'month': '${month.month}'},
    );
    try {
      final rawEntries = response['entries'];
      if (rawEntries is! List) throw const FormatException('entries');
      return List.unmodifiable(
        rawEntries.map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('entry');
          }
          final date = _parseDate(raw['diary_date']);
          if (date == null) throw const FormatException('date');
          final title = raw['title'];
          if (title != null && title is! String) {
            throw const FormatException('title');
          }
          return DiaryEntry(
            date: date,
            title: title as String? ?? '',
            weather: _decodeWeather(raw['weather']),
          );
        }),
      );
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '다이어리 목록을 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }

  @override
  Future<DiaryEntry?> loadDay(DateTime date) async {
    final plantId = await _resolvePlantId();
    try {
      final response = await _client.get(
        '/plants/$plantId/diaries/${_dateOnly(date)}',
      );
      return _decodeEntry(response);
    } on LeafieApiException catch (error) {
      if (error.code == 'DIARY_NOT_FOUND' || error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> save(DiaryEntry entry) async {
    final title = entry.title.trim();
    final content = entry.body.trim();
    final weather = entry.weather;
    _validateUpsert(title: title, content: content, weather: weather);

    final plantId = await _resolvePlantId();
    var mediaFileId = entry.mediaFileId;
    final photoPath = entry.photoPath;
    if (photoPath != null) {
      final media = await _mediaApi.uploadImage(
        bytes: await File(photoPath).readAsBytes(),
        purpose: 'DIARY',
      );
      mediaFileId = media.id;
    }
    await _client.put(
      '/plants/$plantId/diaries/${_dateOnly(entry.date)}',
      body: {
        'weather': _encodeWeather(weather!),
        'title': title,
        'content': content,
        'media_file_id': mediaFileId,
      },
    );
  }

  @override
  Future<void> delete(DateTime date) async {
    final plantId = await _resolvePlantId();
    await _client.delete('/plants/$plantId/diaries/${_dateOnly(date)}');
  }
}

DiaryEntry _decodeEntry(Map<String, dynamic> json) {
  final date = _parseDate(json['diary_date']);
  final content = json['content'];
  final rawTitle = json['title'];
  final media = json['media'];
  if (date == null ||
      content is! String ||
      (rawTitle != null && rawTitle is! String)) {
    throw const LeafieApiException(
      code: 'INVALID_RESPONSE',
      message: '다이어리를 확인할 수 없습니다.',
      statusCode: 502,
    );
  }

  var title = rawTitle as String? ?? '';
  var body = content;
  if (rawTitle == null) {
    final legacyContent = _decodeLegacyContent(content);
    if (legacyContent != null) {
      title = legacyContent.title;
      body = legacyContent.body;
    }
  }

  String? mediaFileId;
  String? photoUrl;
  if (media is Map) {
    mediaFileId = media['id'] is String ? media['id'] as String : null;
    photoUrl = media['download_url'] is String
        ? media['download_url'] as String
        : null;
  }
  return DiaryEntry(
    date: date,
    title: title,
    body: body,
    weather: _decodeResponseWeather(json['weather']),
    mediaFileId: mediaFileId,
    photoUrl: photoUrl,
  );
}

({String title, String body})? _decodeLegacyContent(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map || decoded['v'] != 1) return null;
    final title = decoded['title'];
    final body = decoded['body'];
    if (title is! String || body is! String) return null;
    return (title: title, body: body);
  } on FormatException {
    return null;
  }
}

void _validateUpsert({
  required String title,
  required String content,
  required DiaryWeather? weather,
}) {
  if (title.isEmpty) {
    throw const LeafieApiException(
      code: 'DIARY_TITLE_REQUIRED',
      message: '제목을 입력해 주세요.',
      statusCode: 422,
    );
  }
  if (title.runes.length > 100) {
    throw const LeafieApiException(
      code: 'DIARY_TITLE_TOO_LONG',
      message: '제목은 100자 이하로 입력해 주세요.',
      statusCode: 422,
    );
  }
  if (content.isEmpty) {
    throw const LeafieApiException(
      code: 'DIARY_CONTENT_REQUIRED',
      message: '내용을 입력해 주세요.',
      statusCode: 422,
    );
  }
  if (content.runes.length > 2000) {
    throw const LeafieApiException(
      code: 'DIARY_CONTENT_TOO_LONG',
      message: '내용은 2000자 이하로 입력해 주세요.',
      statusCode: 422,
    );
  }
  if (weather == null) {
    throw const LeafieApiException(
      code: 'DIARY_WEATHER_REQUIRED',
      message: '날씨를 선택해 주세요.',
      statusCode: 422,
    );
  }
}

String _encodeWeather(DiaryWeather weather) => switch (weather) {
  DiaryWeather.sunny => 'SUNNY',
  DiaryWeather.partlyCloudy => 'PARTLY_CLOUDY',
  DiaryWeather.cloudy => 'CLOUDY',
  DiaryWeather.rainy => 'RAINY',
  DiaryWeather.snowy => 'SNOWY',
};

DiaryWeather? _decodeResponseWeather(Object? value) {
  try {
    return _decodeWeather(value);
  } on FormatException {
    throw const LeafieApiException(
      code: 'INVALID_RESPONSE',
      message: '다이어리를 확인할 수 없습니다.',
      statusCode: 502,
    );
  }
}

DiaryWeather? _decodeWeather(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('weather');
  return switch (value) {
    'SUNNY' => DiaryWeather.sunny,
    'PARTLY_CLOUDY' => DiaryWeather.partlyCloudy,
    'CLOUDY' => DiaryWeather.cloudy,
    'RAINY' => DiaryWeather.rainy,
    'SNOWY' => DiaryWeather.snowy,
    _ => throw const FormatException('weather'),
  };
}

String _dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? _parseDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
