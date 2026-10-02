import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';

LeafieApiClient _client(LeafieTransport transport) => LeafieApiClient(
  baseUrl: 'http://localhost:8000/api/v1',
  accessTokenProvider: () async => 'test-token',
  transport: transport,
);

Map<String, Object?> _plantJson({
  String id = 'plant-1',
  String nickname = '새싹이',
  String colorId = 'color_green',
  String placeName = '거실',
  bool detail = false,
}) => {
  'id': id,
  'nickname': nickname,
  'species_reference_id': 'species-1',
  'species_display_name': '몬스테라',
  'personality_type': 'CUTE',
  'color_id': colorId,
  'hair_id': 'hair_sprout',
  'primary_photo_url': null,
  'started_on': '2026-08-26',
  if (detail) ...{
    'category': 'FOLIAGE',
    'scientific_name': null,
    'family_name': null,
    'flowering_period': null,
    'place_name': placeName,
    'created_at': '2026-08-26T00:00:00Z',
    'updated_at': '2026-09-06T00:00:00Z',
  },
};

void main() {
  test('식물 목록과 사용자 프로필을 조회해 현재 선택 식물을 표시한다', () async {
    final requests = <LeafieHttpRequest>[];
    final api = PlantManagementApi(
      client: _client((input) async {
        requests.add(input);
        if (input.uri.path.endsWith('/users/me')) {
          return LeafieHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              'user_id': 'user-1',
              'email': 'leafie@example.com',
              'email_verified_at': '2026-08-01T00:00:00Z',
              'auth_providers': ['password'],
              'can_change_password': true,
              'nickname': '가드너',
              'timezone': 'Asia/Seoul',
              'selected_plant_id': 'plant-2',
              'push_enabled': true,
              'profile_completed': true,
              'profile_completed_at': '2026-08-01T00:00:00Z',
              'gardener_days': 46,
            }),
          );
        }
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'items': [_plantJson(), _plantJson(id: 'plant-2', nickname: '초록이')],
          }),
        );
      }),
    );

    final plants = await api.listPlants();

    expect(requests.map((request) => '${request.method} ${request.uri.path}'), [
      'GET /api/v1/plants',
      'GET /api/v1/users/me',
    ]);
    expect(plants, hasLength(2));
    expect(plants.first.isSelected, isFalse);
    expect(plants.last.isSelected, isTrue);
    expect(plants.first.startedOn, DateTime(2026, 8, 26));
  });

  test('선택 식물 변경 계약을 사용한다', () async {
    late LeafieHttpRequest request;
    final api = PlantManagementApi(
      client: _client((input) async {
        request = input;
        return const LeafieHttpResponse(
          statusCode: 200,
          body: '{"selected_plant_id":"plant-2"}',
        );
      }),
    );

    expect(await api.selectPlant('plant-2'), 'plant-2');
    expect(request.method, 'PATCH');
    expect(request.uri.path, '/api/v1/users/me/selected-plant');
    expect(request.body, {'selected_plant_id': 'plant-2'});
  });

  test('편집용 식물 상세를 조회해 장소를 파싱한다', () async {
    late LeafieHttpRequest request;
    final api = PlantManagementApi(
      client: _client((input) async {
        request = input;
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode(_plantJson(placeName: '창가', detail: true)),
        );
      }),
    );

    final plant = await api.getPlant('plant-1');

    expect(request.method, 'GET');
    expect(request.uri.path, '/api/v1/plants/plant-1');
    expect(plant.placeName, '창가');
  });

  test('닉네임과 장소를 식물 PATCH 허용 필드로만 수정한다', () async {
    late LeafieHttpRequest request;
    final api = PlantManagementApi(
      client: _client((input) async {
        request = input;
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode(
            _plantJson(nickname: '변경이', placeName: '베란다', detail: true),
          ),
        );
      }),
    );

    final updated = await api.updatePlant(
      'plant-1',
      nickname: '  변경이  ',
      placeName: '  베란다  ',
    );

    expect(updated.nickname, '변경이');
    expect(updated.placeName, '베란다');
    expect(request.uri.path, '/api/v1/plants/plant-1');
    expect(request.body, {'nickname': '변경이', 'place_name': '베란다'});
  });

  test('상세 응답의 마지막 물 준 날·분갈이 날을 읽고, 바꾼 날짜만 보낸다', () async {
    late LeafieHttpRequest request;
    final api = PlantManagementApi(
      client: _client((input) async {
        request = input;
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            ..._plantJson(detail: true),
            'last_watered_on': '2026-09-20',
            'last_repotted_on': null,
          }),
        );
      }),
    );

    final updated = await api.updatePlant(
      'plant-1',
      lastWateredOn: DateTime(2026, 9, 20, 18, 30),
    );

    expect(request.body, {'last_watered_on': '2026-09-20'});
    expect(updated.lastWateredOn, DateTime(2026, 9, 20));
    expect(updated.lastRepottedOn, isNull);
  });

  test('날짜 형식이 틀린 상세 응답은 거부한다', () async {
    final api = PlantManagementApi(
      client: _client(
        (_) async => LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            ..._plantJson(detail: true),
            'last_watered_on': '2026/09/20',
          }),
        ),
      ),
    );

    await expectLater(api.getPlant('plant-1'), throwsA(anything));
  });

  test('식물 PATCH는 빈 변경과 서버 길이 제한 초과를 요청 전에 거부한다', () async {
    var requestCount = 0;
    final api = PlantManagementApi(
      client: _client((input) async {
        requestCount++;
        return const LeafieHttpResponse(statusCode: 500, body: '{}');
      }),
    );

    await expectLater(
      api.updatePlant('plant-1'),
      throwsA(isA<LeafieApiException>()),
    );
    await expectLater(
      api.updatePlant('plant-1', nickname: List.filled(31, '가').join()),
      throwsA(isA<LeafieApiException>()),
    );
    await expectLater(
      api.updatePlant('plant-1', placeName: List.filled(51, '가').join()),
      throwsA(isA<LeafieApiException>()),
    );
    expect(requestCount, 0);
  });

  test('외형 PATCH는 color_id와 hair_id만 전송한다', () async {
    late LeafieHttpRequest request;
    final api = PlantManagementApi(
      client: _client((input) async {
        request = input;
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode(_plantJson(colorId: 'color_pink', detail: true)),
        );
      }),
    );

    final updated = await api.updateAppearance(
      'plant-1',
      colorId: 'color_pink',
      hairId: 'hair_leaf_01',
    );

    expect(updated.colorId, 'color_pink');
    expect(request.uri.path, '/api/v1/plants/plant-1/appearance');
    expect(request.body, {
      'color_id': 'color_pink',
      'hair_id': 'hair_leaf_01',
    });
  });

  test('식물 삭제는 DELETE 204 계약을 사용한다', () async {
    late LeafieHttpRequest request;
    final api = PlantManagementApi(
      client: _client((input) async {
        request = input;
        return const LeafieHttpResponse(statusCode: 204, body: '');
      }),
    );

    await api.deletePlant('plant-1');

    expect(request.method, 'DELETE');
    expect(request.uri.path, '/api/v1/plants/plant-1');
  });
}
