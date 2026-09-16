import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/letter_api.dart';

LeafieApiClient _client(
  LeafieTransport transport, {
  AccessTokenProvider? accessTokenProvider,
}) => LeafieApiClient(
  baseUrl: 'http://localhost:8000/api/v1',
  accessTokenProvider: accessTokenProvider ?? () async => 'test-token',
  transport: transport,
);

Map<String, Object?> _letterJson({
  required String id,
  String plantId = 'plant-1',
  String preview = '짧은 편지',
  String? content,
  bool isRead = false,
  String publishedAt = '2026-09-14T03:00:00Z',
}) => {
  'id': id,
  'plant_id': plantId,
  'plant_nickname': '새싹이',
  'diary_id': 'diary-$id',
  'diary_date': '2026-09-13',
  'status': 'COMPLETED',
  'preview': preview,
  'generated_at': '2026-09-14T02:00:00Z',
  'published_at': publishedAt,
  'is_read': isRead,
  ...(content == null
      ? <String, Object?>{}
      : {
          'content': content,
          'read_at': isRead ? '2026-09-14T04:00:00Z' : null,
        }),
};

LetterApi _api(LeafieTransport transport) => LetterApi(
  client: _client(transport),
  recipientNicknameProvider: () async => '윤지',
);

void main() {
  test('인증된 목록 요청을 끝까지 페이지 순회하고 ID 순서를 보존한다', () async {
    final requests = <LeafieHttpRequest>[];
    final api = _api((request) async {
      requests.add(request);
      final cursor = request.uri.queryParameters['cursor'];
      return LeafieHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'items': cursor == null
              ? [_letterJson(id: 'letter-2'), _letterJson(id: 'letter-1')]
              : [_letterJson(id: 'letter-1'), _letterJson(id: 'letter-0')],
          'next_cursor': cursor == null ? 'opaque cursor/값' : null,
        }),
      );
    });

    final letters = await api.listLetters('plant-1');

    expect(letters.map((letter) => letter.id), [
      'letter-2',
      'letter-1',
      'letter-0',
    ]);
    expect(letters.every((letter) => !letter.contentLoaded), isTrue);
    expect(letters.first.body, letters.first.preview);
    expect(letters.first.recipient, '윤지');
    expect(letters.first.sender, '새싹이');
    expect(letters.first.createdAt, DateTime.parse('2026-09-14T03:00:00Z'));
    expect(requests, hasLength(2));
    expect(requests.first.method, 'GET');
    expect(requests.first.headers['authorization'], 'Bearer test-token');
    expect(requests.first.uri.queryParameters, {
      'plant_id': 'plant-1',
      'limit': '100',
    });
    expect(requests.last.uri.queryParameters['cursor'], 'opaque cursor/값');
    expect(
      requests.where((request) => request.uri.path.contains('/letter-')),
      isEmpty,
    );
  });

  test('상세만 실제 content를 본문으로 사용하며 조회로 읽음 처리하지 않는다', () async {
    late LeafieHttpRequest request;
    final api = _api((input) async {
      request = input;
      return LeafieHttpResponse(
        statusCode: 200,
        body: jsonEncode(
          _letterJson(
            id: 'letter-1',
            preview: '100자 미리보기',
            content: '잘리지 않은 편지 전문',
          ),
        ),
      );
    });

    final letter = await api.getLetter('plant-1', 'letter-1');

    expect(request.method, 'GET');
    expect(request.uri.path, '/api/v1/letters/letter-1');
    expect(request.body, isNull);
    expect(letter.body, '잘리지 않은 편지 전문');
    expect(letter.preview, '100자 미리보기');
    expect(letter.contentLoaded, isTrue);
  });

  test('읽음과 삭제 요청은 계약된 method와 빈 body를 사용한다', () async {
    final requests = <LeafieHttpRequest>[];
    var profileCalls = 0;
    final api = LetterApi(
      client: _client((request) async {
        requests.add(request);
        if (request.method == 'DELETE') {
          return const LeafieHttpResponse(statusCode: 204, body: '');
        }
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode(
            _letterJson(id: 'letter-1', content: '전문', isRead: true),
          ),
        );
      }),
      recipientNicknameProvider: () async {
        profileCalls++;
        return '윤지';
      },
    );

    await api.markRead('plant-1', 'letter-1');
    await api.deleteLetter('plant-1', 'letter-1');

    expect(requests[0].method, 'POST');
    expect(requests[0].uri.path, '/api/v1/letters/letter-1/read');
    expect(requests[0].body, isEmpty);
    expect(requests[1].method, 'DELETE');
    expect(requests[1].uri.path, '/api/v1/letters/letter-1');
    expect(profileCalls, 0);
  });

  test('목록과 상세의 다른 식물 응답을 INVALID_RESPONSE로 거부한다', () async {
    final listApi = _api(
      (_) async => LeafieHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'items': [_letterJson(id: 'letter-1', plantId: 'plant-2')],
          'next_cursor': null,
        }),
      ),
    );
    final detailApi = _api(
      (_) async => LeafieHttpResponse(
        statusCode: 200,
        body: jsonEncode(
          _letterJson(id: 'letter-1', plantId: 'plant-2', content: '전문'),
        ),
      ),
    );

    await expectLater(
      listApi.listLetters('plant-1'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
    await expectLater(
      detailApi.getLetter('plant-1', 'letter-1'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });

  test('상세 content 누락과 반복 cursor를 INVALID_RESPONSE로 거부한다', () async {
    final missingContentApi = _api(
      (_) async => LeafieHttpResponse(
        statusCode: 200,
        body: jsonEncode(_letterJson(id: 'letter-1')),
      ),
    );
    final repeatedCursorApi = _api(
      (_) async => LeafieHttpResponse(
        statusCode: 200,
        body: jsonEncode({'items': const [], 'next_cursor': 'same'}),
      ),
    );

    await expectLater(
      missingContentApi.getLetter('plant-1', 'letter-1'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
    await expectLater(
      repeatedCursorApi.listLetters('plant-1'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });

  test('상세 ID 불일치와 읽히지 않은 POST 응답을 거부한다', () async {
    final wrongIdApi = _api(
      (_) async => LeafieHttpResponse(
        statusCode: 200,
        body: jsonEncode(_letterJson(id: 'other-letter', content: '전문')),
      ),
    );
    final unreadApi = _api(
      (_) async => LeafieHttpResponse(
        statusCode: 200,
        body: jsonEncode(_letterJson(id: 'letter-1', content: '전문')),
      ),
    );

    await expectLater(
      wrongIdApi.getLetter('plant-1', 'letter-1'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
    await expectLater(
      unreadApi.markRead('plant-1', 'letter-1'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });

  test('인증 오류와 네트워크 오류를 변환하지 않는다', () async {
    final authApi = LetterApi(
      client: _client(
        (_) async => throw StateError('transport must not run'),
        accessTokenProvider: () async => null,
      ),
      recipientNicknameProvider: () async => '윤지',
    );
    final networkApi = _api((_) async {
      throw const LeafieApiException(
        code: 'NETWORK_ERROR',
        message: '서버에 연결할 수 없습니다.',
        statusCode: 0,
      );
    });

    await expectLater(
      authApi.listLetters('plant-1'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'AUTH_REQUIRED',
        ),
      ),
    );
    await expectLater(
      networkApi.listLetters('plant-1'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_ERROR',
        ),
      ),
    );
  });

  test('닉네임이 없으면 중립 수신인을 사용한다', () async {
    final api = LetterApi(
      client: _client(
        (_) async => LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'items': [_letterJson(id: 'letter-1')],
            'next_cursor': null,
          }),
        ),
      ),
      recipientNicknameProvider: () async => null,
    );

    final letters = await api.listLetters('plant-1');

    expect(letters.single.recipient, '식집사님');
  });

  test('프로필 조회 실패를 캐시하지 않아 다음 목록 요청에서 재시도한다', () async {
    var profileCalls = 0;
    final api = LetterApi(
      client: _client(
        (_) async => LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({'items': const [], 'next_cursor': null}),
        ),
      ),
      recipientNicknameProvider: () async {
        profileCalls++;
        if (profileCalls == 1) {
          throw const LeafieApiException(
            code: 'NETWORK_ERROR',
            message: '서버에 연결할 수 없습니다.',
            statusCode: 0,
          );
        }
        return '윤지';
      },
    );

    await expectLater(
      api.listLetters('plant-1'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_ERROR',
        ),
      ),
    );
    expect(await api.listLetters('plant-1'), isEmpty);
    expect(profileCalls, 2);
  });
}
