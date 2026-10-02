import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/home_api.dart';
import 'package:yeso_plant/services/sensor_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';

void main() {
  LeafieApiClient client(LeafieTransport transport) => LeafieApiClient(
    baseUrl: 'http://localhost:8000/api/v1',
    accessTokenProvider: () async => 'test-access-token',
    transport: transport,
  );

  test('GET /home 응답을 홈 모델로 바꾼다', () async {
    final api = HomeApi(
      client: client((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/v1/home');
        expect(request.headers['authorization'], 'Bearer test-access-token');
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'plant': {
              'id': 'plant-id',
              'nickname': '새싹이',
              'personality_type': 'OUTGOING',
              'color_id': 'color_orange',
              'hair_id': 'hair_sprout',
              'started_on': '2026-05-01',
              'days_together': 128,
              'primary_photo_url': null,
            },
            'room': {
              'background_phase': 'DAY',
              'dialogue_key': 'NORMAL',
              'dialogue': null,
            },
            'today_events': [
              {
                'id': 'event-id',
                'care_type': 'WATERING',
                'title': null,
                'due_date': '2026-09-05',
                'view_status': 'TODAY',
                'source': 'SYSTEM',
                'completable': true,
              },
            ],
            'unread_letter_count': 0,
            'unread_notification_count': 2,
          }),
        );
      }),
    );

    final home = await api.fetchHome();

    expect(home.plant?.nickname, '새싹이');
    expect(home.plant?.daysTogether, 128);
    expect(home.plant?.personalityType, 'OUTGOING');
    expect(home.room?.backgroundPhase, 'DAY');
    expect(home.todayEvents.single.careType, 'WATERING');
    expect(home.todayEvents.single.completable, isTrue);
    expect(home.unreadNotificationCount, 2);
  });

  test('선택한 식물 id를 홈 조회에 전달한다', () async {
    final api = HomeApi(
      client: client((request) async {
        expect(request.uri.path, '/api/v1/home');
        expect(request.uri.queryParameters['plant_id'], 'plant-id');
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'plant': null,
            'room': null,
            'today_events': [],
            'unread_letter_count': 0,
            'unread_notification_count': 0,
          }),
        );
      }),
    );

    await api.fetchHome(plantId: 'plant-id');
  });

  test('필수 필드가 없으면 INVALID_RESPONSE로 거부한다', () async {
    final api = HomeApi(
      client: client(
        (_) async => LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'plant': null,
            'room': null,
            'today_events': [],
          }),
        ),
      ),
    );

    await expectLater(
      api.fetchHome(),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });

  test('등록 당일 days_together 0을 허용한다', () {
    final data = HomePlantData.fromJson({
      'id': 'plant-id',
      'nickname': '새싹이',
      'personality_type': 'OUTGOING',
      'color_id': 'color_orange',
      'hair_id': 'hair_sprout',
      'started_on': '2026-05-01',
      'days_together': 0,
      'primary_photo_url': null,
    });

    expect(data.daysTogether, 0);
  });

  test('홈 방의 센서 판정을 읽고, 형식이 틀리면 판정만 버린다', () {
    Map<String, dynamic> room(Object? sensor) => {
      'background_phase': 'DAY',
      'dialogue_key': 'NORMAL',
      'dialogue': '안녕',
      'sensor': sensor,
    };
    final parsed = HomeRoomData.fromJson(
      room({
        'connection': 'ACTIVE',
        'thresholdVersion': '2026-10-02.app-v1',
        'provisional': true,
        'soil': {
          'state': 'LOW',
          'value': 20,
          'unit': 'relative_percent',
          'lower': 40,
          'upper': 90,
          'reason': null,
        },
        'light': {
          'state': 'UNKNOWN',
          'value': 1000,
          'unit': 'lux_hours',
          'lower': 60000,
          'upper': null,
          'reason': 'INSUFFICIENT_COVERAGE',
        },
      }),
    );
    expect(parsed.sensor!.connection, SensorConnection.active);
    expect(parsed.sensor!.soil.state, SensorLevel.low);
    expect(parsed.sensor!.soil.value, 20);
    expect(parsed.sensor!.light.reason, 'INSUFFICIENT_COVERAGE');

    expect(HomeRoomData.fromJson(room(null)).sensor, isNull);
    expect(
      HomeRoomData.fromJson(room({'connection': 'SOMETHING_NEW'})).sensor,
      isNull,
      reason: '센서 형식이 바뀌어도 홈 전체가 실패하지 않는다',
    );
  });

  test('홈 대사 큐를 읽고, 형식이 틀린 항목만 건너뛴다', () {
    final room = HomeRoomData.fromJson({
      'background_phase': 'DAY',
      'dialogue_key': 'NORMAL',
      'dialogue': '안녕',
      'dialogue_queue': [
        {
          'event_id': 'e-1',
          'dialogue_key': 'WATERING_COMPLETED',
          'dialogue': ' 물 고마워! ',
          'duration_seconds': 15,
          'occurred_at': '2026-10-02T01:00:00Z',
        },
        {'event_id': 'e-2', 'dialogue_key': 'LETTER_SENT'},
        {
          'event_id': 'e-3',
          'dialogue_key': 'DIARY_RECEIVED',
          'dialogue': '일기 잘 받았어',
          'duration_seconds': 9999,
          'occurred_at': '2026-10-02T02:00:00Z',
        },
      ],
    });

    expect(room.dialogueQueue.map((e) => e.eventId), ['e-1', 'e-3']);
    expect(room.dialogueQueue.first.dialogue, '물 고마워!');
    expect(room.dialogueQueue.first.duration, const Duration(seconds: 15));
    expect(room.dialogueQueue.last.duration, const Duration(seconds: 60));
  });
}
