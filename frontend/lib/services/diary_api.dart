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
  String? _plantId;

  Future<String> _resolvePlantId() async {
    final cached = _plantId;
    if (cached != null) return cached;
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
          return DiaryEntry(date: date);
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
    final content = _encodeContent(entry);
    if (content.length > 2000) {
      throw const LeafieApiException(
        code: 'DIARY_CONTENT_TOO_LONG',
        message: '다이어리 내용이 너무 길어요.',
        statusCode: 422,
      );
    }
    await _client.put(
      '/plants/$plantId/diaries/${_dateOnly(entry.date)}',
      body: {
        'content': content,
        'condition_score': _conditionScore(entry.weather),
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
  final conditionScore = json['condition_score'];
  final media = json['media'];
  if (date == null || content is! String || conditionScore is! int) {
    throw const LeafieApiException(
      code: 'INVALID_RESPONSE',
      message: '다이어리를 확인할 수 없습니다.',
      statusCode: 502,
    );
  }

  var title = '';
  var body = content;
  try {
    final decoded = jsonDecode(content);
    if (decoded is Map && decoded['v'] == 1) {
      title = decoded['title'] is String ? decoded['title'] as String : '';
      body = decoded['body'] is String ? decoded['body'] as String : '';
    }
  } on FormatException {
    // 이전 버전의 일반 문자열 content는 본문으로 그대로 보여준다.
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
    weather: _weatherFromScore(conditionScore),
    mediaFileId: mediaFileId,
    photoUrl: photoUrl,
  );
}

String _encodeContent(DiaryEntry entry) => jsonEncode({
  'v': 1,
  'title': entry.title.trim(),
  'body': entry.body.trim(),
});

int _conditionScore(DiaryWeather? weather) => switch (weather) {
  DiaryWeather.sunny => 100,
  DiaryWeather.partlyCloudy => 75,
  DiaryWeather.cloudy => 50,
  DiaryWeather.rainy => 25,
  DiaryWeather.shower => 0,
  null => 50,
};

DiaryWeather _weatherFromScore(int score) => switch (score) {
  100 => DiaryWeather.sunny,
  75 => DiaryWeather.partlyCloudy,
  50 => DiaryWeather.cloudy,
  25 => DiaryWeather.rainy,
  _ => DiaryWeather.shower,
};

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
