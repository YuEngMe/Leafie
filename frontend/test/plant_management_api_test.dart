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
  String colorId = 'color_mint_01',
  bool includeSelection = true,
}) => {
  'id': id,
  'nickname': nickname,
  'species_reference_id': 'species-1',
  'species_display_name': '몬스테라',
  'primary_photo_url': null,
  'personality_type': 'CUTE',
  'color_id': colorId,
  'hair_id': 'NONE',
  'accessory_id': 'NONE',
  'days_together': 12,
  if (includeSelection) 'is_selected': id == 'plant-1',
  if (!includeSelection) ...{
    'category': 'FOLIAGE',
    'scientific_name': null,
    'family_name': null,
    'flowering_period': null,
    'started_on': '2026-08-26',
    'place_name': '거실',
    'pot_type': 'SOIL',
    'placement': 'INDOOR',
    'condition': {'recorded': false, 'score': null, 'level': null},
    'created_at': '2026-08-26T00:00:00Z',
    'updated_at': '2026-09-06T00:00:00Z',
  },
};

void main() {
  test('식물 목록을 조회하고 현재 선택 식물을 파싱한다', () async {
    late LeafieHttpRequest request;
    final api = PlantManagementApi(
      client: _client((input) async {
        request = input;
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'plants': [
              _plantJson(),
              _plantJson(id: 'plant-2', nickname: '초록이'),
            ],
          }),
        );
      }),
    );

    final plants = await api.listPlants();

    expect(request.method, 'GET');
    expect(request.uri.path, '/api/v1/plants');
    expect(plants, hasLength(2));
    expect(plants.first.isSelected, isTrue);
    expect(plants.last.isSelected, isFalse);
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

  test('이름과 외형을 각 전용 PATCH로 수정한다', () async {
    final requests = <LeafieHttpRequest>[];
    final api = PlantManagementApi(
      client: _client((input) async {
        requests.add(input);
        final appearance = input.uri.path.endsWith('/appearance');
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode(
            _plantJson(
              nickname: appearance ? '새싹이' : '변경이',
              colorId: appearance ? 'color_pink_01' : 'color_mint_01',
              includeSelection: false,
            ),
          ),
        );
      }),
    );

    final renamed = await api.updateNickname('plant-1', '  변경이  ');
    final decorated = await api.updateAppearance(
      'plant-1',
      colorId: 'color_pink_01',
    );

    expect(renamed.nickname, '변경이');
    expect(decorated.colorId, 'color_pink_01');
    expect(requests[0].uri.path, '/api/v1/plants/plant-1');
    expect(requests[0].body, {'nickname': '변경이'});
    expect(requests[1].uri.path, '/api/v1/plants/plant-1/appearance');
    expect(requests[1].body, {'color_id': 'color_pink_01'});
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
