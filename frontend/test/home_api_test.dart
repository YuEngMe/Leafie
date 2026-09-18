import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/home_api.dart';
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
              'color_id': 'color_orange_01',
              'hair_id': 'NONE',
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
      'color_id': 'color_orange_01',
      'hair_id': 'NONE',
      'started_on': '2026-05-01',
      'days_together': 0,
      'primary_photo_url': null,
    });

    expect(data.daysTogether, 0);
  });
}
