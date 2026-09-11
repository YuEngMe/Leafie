import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_api.dart';

PlantRegistrationDraft _completeDraft() =>
    PlantRegistrationDraft(
        name: '씩씩이',
        species: const PlantSpeciesCandidate(
          referenceId: 'catalog:ocimum-basilicum',
          displayName: '바질',
          scientificName: 'Ocimum basilicum',
          categorySuggestion: 'HERB',
        ),
        clientRegistrationId: '87a4fcef-26ce-4f84-9d26-a6626c5c9216',
        startedOn: DateTime(2026, 9, 5),
      )
      ..placeName = '학교'
      ..lastWateredOn = DateTime(2026, 9, 4)
      ..lastRepottedOn = DateTime(2026, 8, 1)
      ..personalityType = 'OUTGOING'
      ..bodyColorId = 'color_orange_01';

void main() {
  test('선택한 헤어 ID가 등록 요청과 고정된 초안에 유지된다', () {
    final draft = _completeDraft()..headItem = 'hair_cactus_heart_01';
    expect(buildPlantCreateRequest(draft)['hair_id'], 'hair_cactus_heart_01');
    final snapshot = draft.freezeForSubmission();
    draft.headItem = 'hair_cactus_column_01';
    expect(snapshot.headItem, 'hair_cactus_heart_01');
    expect(draft.freezeForSubmission().headItem, 'hair_cactus_heart_01');
  });

  LeafieApiClient client(
    LeafieTransport transport, {
    Duration requestTimeout = const Duration(seconds: 15),
  }) => LeafieApiClient(
    baseUrl: 'http://localhost:8000/api/v1',
    accessTokenProvider: () async => 'test-access-token',
    transport: transport,
    requestTimeout: requestTimeout,
  );

  test('검색 GET에 JWT와 query를 보내고 items를 후보로 바꾼다', () async {
    final apiClient = client((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/v1/species');
      expect(request.uri.queryParameters['query'], '바질');
      expect(request.uri.queryParameters['limit'], '20');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      return LeafieHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'items': [
            {
              'reference_id': 'catalog:ocimum-basilicum',
              'display_name': '바질',
              'scientific_name': 'Ocimum basilicum',
              'category': 'HERB',
            },
          ],
          'next_cursor': null,
          'has_next': false,
        }),
      );
    });

    final results = await PlantApi(client: apiClient).searchSpecies(' 바질 ');

    expect(results, hasLength(1));
    expect(results.single.referenceId, 'catalog:ocimum-basilicum');
    expect(results.single.displayName, '바질');
    expect(results.single.categorySuggestion, 'HERB');
  });

  test('등록 전에 프로필을 초기화하고 서버의 flat payload로 POST한다', () async {
    final requests = <LeafieHttpRequest>[];
    final apiClient = client((request) async {
      requests.add(request);
      expect(request.headers['authorization'], 'Bearer test-access-token');
      if (request.uri.path.endsWith('/users/me')) {
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({'profile_completed': true}),
        );
      }
      return LeafieHttpResponse(
        statusCode: 201,
        body: jsonEncode({
          'id': '4c738341-ef6b-4ca9-8eec-f6423e3e62ed',
          'created_at': '2026-09-05T12:00:00Z',
        }),
      );
    });

    final id = await PlantApi(
      client: apiClient,
    ).registerPlant(_completeDraft());

    expect(id, '4c738341-ef6b-4ca9-8eec-f6423e3e62ed');
    expect(requests.map((request) => request.uri.path), [
      '/api/v1/users/me',
      '/api/v1/plants',
    ]);
    final body = requests.last.body!;
    expect(
      body['client_registration_id'],
      '87a4fcef-26ce-4f84-9d26-a6626c5c9216',
    );
    expect(body['nickname'], '씩씩이');
    expect(body['species_selection_method'], 'SEARCH');
    expect(body['started_on'], '2026-09-05');
    expect(body['place_name'], '학교');
    expect(body['pot_type'], 'OTHER');
    expect(body['placement'], 'OTHER');
    expect(body['last_watered_on'], '2026-09-04');
    expect(body['repotting_history'], {
      'status': 'KNOWN',
      'date': '2026-08-01',
    });
    expect(body['personality_type'], 'OUTGOING');
    expect(body['color_id'], 'color_orange_01');
    expect(body['hair_id'], 'NONE');
    expect(body['accessory_id'], 'NONE');
    expect(body, isNot(contains('character')));
    expect(body, isNot(contains('environment')));
  });

  test('서버 오류 코드와 메시지를 화면 계층으로 전달한다', () async {
    final apiClient = client(
      (_) async => LeafieHttpResponse(
        statusCode: 409,
        body: jsonEncode({
          'error': {
            'code': 'PROFILE_INCOMPLETE',
            'message': '닉네임 설정을 완료해 주세요.',
          },
        }),
      ),
    );

    await expectLater(
      PlantApi(client: apiClient).registerPlant(_completeDraft()),
      throwsA(
        isA<LeafieApiException>()
            .having((error) => error.code, 'code', 'PROFILE_INCOMPLETE')
            .having((error) => error.message, 'message', '닉네임 설정을 완료해 주세요.'),
      ),
    );
  });

  test('같은 draft는 재시도해도 동일한 멱등 UUID와 날짜를 만든다', () {
    final draft = _completeDraft();

    final first = buildPlantCreateRequest(draft);
    draft
      ..placeName = '수정된 장소'
      ..personalityType = 'CHIC';
    final second = buildPlantCreateRequest(draft);

    expect(second, first);
    expect(second['place_name'], '학교');
    expect(second['personality_type'], 'OUTGOING');
  });

  test('검색 응답 항목 하나라도 계약이 깨지면 전체 응답을 거부한다', () async {
    final apiClient = client(
      (_) async => LeafieHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'items': [
            {'reference_id': 'catalog:ocimum-basilicum'},
            'invalid-item',
          ],
        }),
      ),
    );

    await expectLater(
      PlantApi(client: apiClient).searchSpecies('바질'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });

  test('응답 제한 시간을 넘기면 재시도 가능한 오류를 낸다', () async {
    final pending = Completer<LeafieHttpResponse>();
    final apiClient = client(
      (_) => pending.future,
      requestTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      PlantApi(client: apiClient).searchSpecies('바질'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_TIMEOUT',
        ),
      ),
    );
  });

  test('기본 transport가 한글 JSON 본문을 UTF-8 바이트로 만든다', () {
    final encoded = encodeLeafieJsonBody({'nickname': '테스트잎'});

    expect(jsonDecode(utf8.decode(encoded)), {'nickname': '테스트잎'});
  });

  test('미래 관리 날짜는 POST 전에 거부한다', () {
    final draft = _completeDraft()
      ..lastWateredOn = DateTime.now().add(const Duration(days: 1));

    expect(
      () => buildPlantCreateRequest(draft),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'FUTURE_DATE_NOT_ALLOWED',
        ),
      ),
    );
  });

  test('사진을 업로드하고 식물 인식 완료 결과를 가져온다', () async {
    final requests = <LeafieHttpRequest>[];
    final apiClient = client((request) async {
      requests.add(request);
      if (request.method == 'PUT') {
        return const LeafieHttpResponse(statusCode: 200, body: '');
      }
      return switch (request.uri.path) {
        '/api/v1/media/presign' => const LeafieHttpResponse(
          statusCode: 201,
          body:
              '{"media_file_id":"media-id","upload_url":"https://storage.example.com/file","upload_method":"PUT","upload_headers":{"Content-Type":"image/jpeg"},"expires_at":"2026-09-06T00:00:00Z"}',
        ),
        '/api/v1/media/media-id/complete' => const LeafieHttpResponse(
          statusCode: 200,
          body: '{"status":"READY"}',
        ),
        '/api/v1/species/identifications' => const LeafieHttpResponse(
          statusCode: 202,
          body:
              '{"identification_id":"identification-id","status":"PENDING","created_at":"2026-09-06T00:00:00Z"}',
        ),
        '/api/v1/species/identifications/identification-id' =>
          const LeafieHttpResponse(
            statusCode: 200,
            body:
                '{"id":"identification-id","status":"COMPLETED","current_candidate_index":0,"candidates":[{"reference_id":"catalog:sedum","display_name":"바위채송화","scientific_name":"Sedum polytrichoides","family_name":"돌나무과","flowering_period":"8월 ~ 9월","category":"SUCCULENT_CACTUS"}],"failure_code":null,"completed_at":"2026-09-06T00:00:00Z"}',
          ),
        _ => throw StateError('unexpected request: ${request.uri}'),
      };
    });

    final result = await PlantApi(
      client: apiClient,
      delay: (_) async {},
      pollInterval: Duration.zero,
    ).identifySpecies(const [0xff, 0xd8, 0xff, 0x00]);

    expect(result.identificationId, 'identification-id');
    expect(result.mediaFileId, 'media-id');
    expect(result.candidate.displayName, '바위채송화');
    expect(result.candidate.familyName, '돌나무과');
    expect(requests.map((request) => request.method), [
      'POST',
      'PUT',
      'POST',
      'POST',
      'GET',
    ]);
  });

  test('사진 인식 draft는 PHOTO 등록 계약을 만든다', () {
    final draft =
        PlantRegistrationDraft(
            name: '사진식물',
            species: const PlantSpeciesCandidate(
              referenceId: 'catalog:sedum',
              displayName: '바위채송화',
              scientificName: 'Sedum polytrichoides',
              categorySuggestion: 'SUCCULENT_CACTUS',
            ),
            speciesIdentificationId: 'identification-id',
            primaryMediaFileId: 'media-id',
          )
          ..placeName = '학교'
          ..lastWateredOn = DateTime.now()
          ..personalityType = 'OUTGOING'
          ..bodyColorId = 'color_orange_01';

    final body = buildPlantCreateRequest(draft);

    expect(body['species_selection_method'], 'PHOTO');
    expect(body['species_identification_id'], 'identification-id');
    expect(body['primary_media_file_id'], 'media-id');
  });
}
