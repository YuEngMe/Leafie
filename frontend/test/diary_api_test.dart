import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/services/diary_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/media_api.dart';

const plantId = '4c738341-ef6b-4ca9-8eec-f6423e3e62ed';

LeafieApiClient client(LeafieTransport transport) => LeafieApiClient(
  baseUrl: 'http://localhost:8000/api/v1',
  accessTokenProvider: () async => 'test-token',
  transport: transport,
);

void main() {
  test('월별 다이어리 목록을 조회한다', () async {
    late LeafieHttpRequest request;
    final store = ApiDiaryStore(
      plantId: plantId,
      client: client((input) async {
        request = input;
        return const LeafieHttpResponse(
          statusCode: 200,
          body:
              '{"entries":[{"id":"entry","diary_date":"2026-07-15","condition_score":100,"condition_level":5,"has_photo":false}],"statistics":{"entry_count":1,"average_score":100,"average_level":5}}',
        );
      }),
    );

    final entries = await store.loadMonth(DateTime(2026, 7));

    expect(entries.single.date, DateTime(2026, 7, 15));
    expect(request.uri.queryParameters, {'year': '2026', 'month': '7'});
  });

  test('날짜별 다이어리의 제목·본문·날씨·사진을 복원한다', () async {
    final encodedContent = jsonEncode({
      'v': 1,
      'title': '새 잎',
      'body': '잎이 자랐다.',
    });
    final store = ApiDiaryStore(
      plantId: plantId,
      client: client(
        (_) async => LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'id': 'entry',
            'plant_id': plantId,
            'diary_date': '2026-07-15',
            'content': encodedContent,
            'condition_score': 75,
            'condition_level': 4,
            'media': {
              'id': 'media-id',
              'download_url': 'https://example.com/diary.jpg',
              'expires_at': '2026-07-16T00:00:00Z',
            },
            'created_at': '2026-07-15T00:00:00Z',
            'updated_at': '2026-07-15T00:00:00Z',
          }),
        ),
      ),
    );

    final entry = await store.loadDay(DateTime(2026, 7, 15));

    expect(entry?.title, '새 잎');
    expect(entry?.body, '잎이 자랐다.');
    expect(entry?.weather, DiaryWeather.partlyCloudy);
    expect(entry?.mediaFileId, 'media-id');
    expect(entry?.photoUrl, 'https://example.com/diary.jpg');
  });

  test('다이어리를 PUT하고 빈 날짜는 DELETE한다', () async {
    final requests = <LeafieHttpRequest>[];
    final store = ApiDiaryStore(
      plantId: plantId,
      client: client((input) async {
        requests.add(input);
        return const LeafieHttpResponse(statusCode: 204, body: '');
      }),
    );

    await store.save(
      DiaryEntry(
        date: DateTime(2026, 7, 15),
        title: '제목',
        body: '본문',
        weather: DiaryWeather.rainy,
        mediaFileId: 'media-id',
      ),
    );
    await store.delete(DateTime(2026, 7, 16));

    expect(requests[0].method, 'PUT');
    expect(requests[0].body?['condition_score'], 25);
    expect(requests[0].body?['media_file_id'], 'media-id');
    expect(jsonDecode(requests[0].body?['content']! as String), {
      'v': 1,
      'title': '제목',
      'body': '본문',
    });
    expect(requests[1].method, 'DELETE');
    expect(requests[1].uri.path, '/api/v1/plants/$plantId/diaries/2026-07-16');
  });

  test('사진 업로드는 presign, PUT, complete 순서다', () async {
    final requests = <LeafieHttpRequest>[];
    final api = MediaApi(
      client: client((input) async {
        requests.add(input);
        if (input.method == 'PUT') {
          return const LeafieHttpResponse(statusCode: 200, body: '');
        }
        if (input.uri.path.endsWith('/complete')) {
          return const LeafieHttpResponse(
            statusCode: 200,
            body: '{"status":"READY"}',
          );
        }
        return const LeafieHttpResponse(
          statusCode: 201,
          body:
              '{"media_file_id":"media-id","upload_url":"https://storage.example.com/file","upload_method":"PUT","upload_headers":{"Content-Type":"image/jpeg"},"expires_at":"2026-07-16T00:00:00Z"}',
        );
      }),
    );

    final media = await api.uploadImage(
      bytes: const [0xff, 0xd8, 0xff, 0x00],
      purpose: 'DIARY',
    );

    expect(media.id, 'media-id');
    expect(requests.map((request) => request.method), ['POST', 'PUT', 'POST']);
    expect(requests.first.body?['purpose'], 'DIARY');
    expect(requests[1].headers, {'Content-Type': 'image/jpeg'});
    expect(requests[1].headers, isNot(contains('Authorization')));
  });
}
