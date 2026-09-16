import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/calendar_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';

void main() {
  LeafieApiClient client(LeafieTransport transport) => LeafieApiClient(
    baseUrl: 'http://localhost:8000/api/v1',
    accessTokenProvider: () async => 'test-access-token',
    transport: transport,
  );

  test('캘린더 조회 쿼리를 인코딩하고 응답을 파싱한다', () async {
    final api = CalendarApi(
      client: client((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/v1/plants/plant-id/calendar');
        expect(request.uri.queryParameters, {
          'from': '2026-07-01',
          'to': '2026-07-31',
          'types': 'WATERING,REPOTTING',
        });
        expect(request.headers['authorization'], 'Bearer test-access-token');
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'items': [
              {
                'id': 'event-id',
                'date': '2026-07-15',
                'type': 'WATERING',
                'status': 'SCHEDULED',
                'view_status': 'TODAY',
                'title': null,
                'source': 'SYSTEM',
                'completable': true,
              },
              {
                'id': 'repotting-id',
                'date': '2026-07-14',
                'type': 'REPOTTING',
                'status': 'COMPLETED',
                'view_status': 'COMPLETED',
                'title': '분갈이',
                'source': 'USER',
                'completable': false,
              },
            ],
          }),
        );
      }),
    );

    final items = await api.listCalendar(
      'plant-id',
      DateTime(2026, 7),
      DateTime(2026, 7, 31),
      types: const ['WATERING', 'REPOTTING'],
    );

    expect(items, hasLength(2));
    expect(items.first.id, 'event-id');
    expect(items.first.date, DateTime(2026, 7, 15));
    expect(items.first.type, 'WATERING');
    expect(items.first.status, 'SCHEDULED');
    expect(items.first.viewStatus, 'TODAY');
    expect(items.first.source, 'SYSTEM');
    expect(items.first.completable, isTrue);
    expect(items.last.type, 'REPOTTING');
    expect(items.last.title, '분갈이');
    expect(items.last.completable, isFalse);
  });

  test('지원하지 않는 CONDITION 필터를 요청 전에 거부한다', () async {
    var requestCount = 0;
    final api = CalendarApi(
      client: client((_) async {
        requestCount += 1;
        return const LeafieHttpResponse(statusCode: 200, body: '{"items":[]}');
      }),
    );

    await expectLater(
      api.listCalendar(
        'plant-id',
        DateTime(2026, 7),
        DateTime(2026, 7, 31),
        types: const ['CONDITION'],
      ),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_CALENDAR_TYPES',
        ),
      ),
    );
    expect(requestCount, 0);
  });

  test('타입 필터가 비어 있으면 types 쿼리를 생략한다', () async {
    final api = CalendarApi(
      client: client((request) async {
        expect(request.uri.queryParameters, {
          'from': '2026-07-01',
          'to': '2026-07-07',
        });
        return const LeafieHttpResponse(statusCode: 200, body: '{"items":[]}');
      }),
    );

    expect(
      await api.listCalendar(
        'plant-id',
        DateTime(2026, 7),
        DateTime(2026, 7, 7),
        types: const ['', '  '],
      ),
      isEmpty,
    );
  });

  test('완료 요청에 수행일을 선택적으로 전송한다', () async {
    final requests = <LeafieHttpRequest>[];
    final api = CalendarApi(
      client: client((request) async {
        requests.add(request);
        return const LeafieHttpResponse(statusCode: 200, body: '{}');
      }),
    );

    await api.completeEvent('event-id', performedOn: DateTime(2026, 7, 15));
    await api.completeEvent('event-with-default-date');

    expect(requests.first.method, 'POST');
    expect(requests.first.uri.path, '/api/v1/care-events/event-id/complete');
    expect(requests.first.body, {'performed_on': '2026-07-15'});
    expect(requests.last.body, isEmpty);
  });

  test('단발성 일정을 UUID v4 멱등 키와 함께 생성한다', () async {
    late LeafieHttpRequest captured;
    final api = CalendarApi(
      client: client((request) async {
        captured = request;
        return const LeafieHttpResponse(statusCode: 201, body: '{}');
      }),
    );

    await api.createEvent(
      'plant-id',
      type: 'FERTILIZING',
      title: '영양제 주기',
      dueDate: DateTime(2026, 7, 20),
    );

    expect(captured.method, 'POST');
    expect(captured.uri.path, '/api/v1/plants/plant-id/care-events');
    expect(
      captured.body?['client_event_id'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(captured.body?['type'], 'FERTILIZING');
    expect(captured.body?['title'], '영양제 주기');
    expect(captured.body?['due_date'], '2026-07-20');
  });

  test('잘못된 캘린더 응답을 INVALID_RESPONSE로 거부한다', () async {
    final malformedResponses = [
      {'items': 'not-a-list'},
      {
        'items': [
          {
            'id': 'event-id',
            'date': '2026-02-30',
            'type': 'WATERING',
            'status': 'SCHEDULED',
            'view_status': 'UPCOMING',
            'title': null,
            'source': 'SYSTEM',
            'completable': true,
          },
        ],
      },
      {
        'items': [
          {
            'id': 'condition-id',
            'date': '2026-02-28',
            'type': 'CONDITION',
            'status': null,
            'view_status': null,
            'title': null,
            'source': null,
            'completable': false,
          },
        ],
      },
    ];

    for (final response in malformedResponses) {
      final api = CalendarApi(
        client: client(
          (_) async =>
              LeafieHttpResponse(statusCode: 200, body: jsonEncode(response)),
        ),
      );

      await expectLater(
        api.listCalendar('plant-id', DateTime(2026, 2), DateTime(2026, 2, 28)),
        throwsA(
          isA<LeafieApiException>().having(
            (error) => error.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );
    }
  });
}
