import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/notification_api.dart';

LeafieApiClient _client(LeafieTransport transport) => LeafieApiClient(
  baseUrl: 'http://localhost:8000/api/v1',
  accessTokenProvider: () async => 'test-token',
  transport: transport,
);

Map<String, Object?> _notificationJson({String? readAt}) => {
  'id': '11111111-1111-4111-8111-111111111111',
  'plant_id': '22222222-2222-4222-8222-222222222222',
  'type': 'WATERING_REMINDER',
  'title': '물을 줄 시간이에요',
  'body': '새싹이에게 물을 주세요.',
  'source_type': 'CARE_SCHEDULE',
  'source_id': '33333333-3333-4333-8333-333333333333',
  'read_at': readAt,
  'created_at': '2026-09-06T08:30:00Z',
};

void main() {
  test('cursor와 안 읽음 조건으로 알림 목록을 조회한다', () async {
    late LeafieHttpRequest request;
    final api = NotificationApi(
      client: _client((input) async {
        request = input;
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'items': [_notificationJson()],
            'next_cursor': 'MjA',
            'has_next': true,
          }),
        );
      }),
    );

    final page = await api.getNotifications(
      cursor: 'MA',
      unreadOnly: true,
      limit: 10,
    );

    expect(request.method, 'GET');
    expect(request.uri.path, '/api/v1/notifications');
    expect(request.uri.queryParameters, {
      'cursor': 'MA',
      'unread_only': 'true',
      'limit': '10',
    });
    expect(page.items.single.title, '물을 줄 시간이에요');
    expect(page.items.single.isRead, isFalse);
    expect(page.nextCursor, 'MjA');
    expect(page.hasNext, isTrue);
  });

  test('개별 읽음과 전체 읽음을 POST한다', () async {
    final requests = <LeafieHttpRequest>[];
    final api = NotificationApi(
      client: _client((input) async {
        requests.add(input);
        if (input.uri.path.endsWith('/read-all')) {
          return const LeafieHttpResponse(statusCode: 204, body: '');
        }
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode(_notificationJson(readAt: '2026-09-06T09:00:00Z')),
        );
      }),
    );

    final notification = await api.markRead(
      '11111111-1111-4111-8111-111111111111',
    );
    await api.markAllRead();

    expect(notification.isRead, isTrue);
    expect(requests[0].method, 'POST');
    expect(
      requests[0].uri.path,
      '/api/v1/notifications/11111111-1111-4111-8111-111111111111/read',
    );
    expect(requests[1].method, 'POST');
    expect(requests[1].uri.path, '/api/v1/notifications/read-all');
  });

  test('iOS 기기를 등록하고 해제한다', () async {
    final requests = <LeafieHttpRequest>[];
    final api = NotificationApi(
      client: _client((input) async {
        requests.add(input);
        if (input.method == 'DELETE') {
          return const LeafieHttpResponse(statusCode: 204, body: '');
        }
        return const LeafieHttpResponse(
          statusCode: 200,
          body:
              '{"id":"44444444-4444-4444-8444-444444444444",'
              '"platform":"IOS","created_at":"2026-09-06T09:00:00Z"}',
        );
      }),
    );

    final device = await api.registerDevice(
      platform: NotificationDevicePlatform.ios,
      installationId: '  fcm-token  ',
    );
    await api.revokeDevice(device.id);

    expect(device.platform, NotificationDevicePlatform.ios);
    expect(requests[0].method, 'POST');
    expect(requests[0].uri.path, '/api/v1/devices');
    expect(requests[0].body, {
      'platform': 'IOS',
      'installation_id': 'fcm-token',
    });
    expect(requests[1].method, 'DELETE');
    expect(
      requests[1].uri.path,
      '/api/v1/devices/44444444-4444-4444-8444-444444444444',
    );
  });

  test('알림 항목 형태가 잘못되면 INVALID_RESPONSE로 거부한다', () async {
    final api = NotificationApi(
      client: _client(
        (_) async => const LeafieHttpResponse(
          statusCode: 200,
          body: '{"items":["invalid"],"next_cursor":null,"has_next":false}',
        ),
      ),
    );

    await expectLater(
      api.getNotifications(),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });
}
