import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/diagnosis_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';

void main() {
  LeafieApiClient client(LeafieTransport transport) => LeafieApiClient(
    baseUrl: 'http://localhost:8000/api/v1',
    accessTokenProvider: () async => 'test-access-token',
    transport: transport,
  );

  test('진단 목록 GET 요청과 응답 변환', () async {
    final api = DiagnosisApi(
      client: client((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/v1/plants/plant-id/diagnoses');
        expect(request.uri.queryParameters['limit'], '100');
        expect(request.headers['authorization'], 'Bearer test-access-token');
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'items': [
              {
                'id': 'diagnosis-id',
                'status': 'COMPLETED',
                'diagnosed_at': '2026-09-06T01:02:03Z',
                'photo_url': 'https://example.com/plant.jpg',
                'condition_label': '조금 관리가 필요해요',
                'retake_reason_code': null,
                'failure_code': null,
              },
            ],
            'has_next': false,
            'next_cursor': null,
          }),
        );
      }),
    );

    final records = await api.listDiagnoses('plant-id');

    expect(records.single.id, 'diagnosis-id');
    expect(records.single.status, 'COMPLETED');
    expect(records.single.conditionLabel, '조금 관리가 필요해요');
  });

  test('진단 상세와 식물 상세를 실제 경로에서 읽는다', () async {
    final api = DiagnosisApi(
      client: client((request) async {
        if (request.uri.path == '/api/v1/diagnoses/diagnosis-id') {
          return LeafieHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              'id': 'diagnosis-id',
              'plant_id': 'plant-id',
              'status': 'COMPLETED',
              'diagnosed_at': '2026-09-06T01:02:03Z',
              'photo_url': 'https://example.com/plant.jpg',
              'overall_condition': 'CAUTION',
              'condition_label': '조금 관리가 필요해요',
              'observations': ['잎 처짐'],
              'possible_causes': [
                {'name': '과습', 'confidence': 0.76},
              ],
              'recommended_care': ['물을 줄여주세요.'],
              'retake_reason_code': null,
              'failure_code': null,
            }),
          );
        }
        expect(request.uri.path, '/api/v1/plants/plant-id');
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'id': 'plant-id',
            'nickname': '새싹이',
            'species_display_name': '해바라기',
            'started_on': '2026-03-01',
          }),
        );
      }),
    );

    final detail = await api.getDiagnosis('diagnosis-id');
    final plant = await api.getPlant(detail.plantId);

    expect(detail.observations, ['잎 처짐']);
    expect(detail.possibleCauses.single.confidence, 0.76);
    expect(plant.nickname, '새싹이');
    expect(plant.speciesDisplayName, '해바라기');
  });

  test('잘못된 목록 응답은 INVALID_RESPONSE로 거부한다', () async {
    final api = DiagnosisApi(
      client: client(
        (_) async => const LeafieHttpResponse(
          statusCode: 200,
          body: '{"items":"not-a-list"}',
        ),
      ),
    );

    await expectLater(
      api.listDiagnoses('plant-id'),
      throwsA(
        isA<LeafieApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });

  test('사진 업로드부터 완료된 진단 조회까지 실제 계약 순서로 요청한다', () async {
    final requests = <LeafieHttpRequest>[];
    final photoBytes = <int>[0xff, 0xd8, 0xff, 0x00];
    final api = DiagnosisApi(
      client: client((request) async {
        requests.add(request);
        if (request.uri.path == '/api/v1/media/presign') {
          expect(request.method, 'POST');
          expect(request.body, {
            'purpose': 'DIAGNOSIS',
            'content_type': 'image/jpeg',
            'size_bytes': 4,
            'checksum_sha256':
                '374ffede23adbc8bc625205f4bf86750807ffb6ce71fc7d10cac8bded0872bf5',
          });
          return LeafieHttpResponse(
            statusCode: 201,
            body: jsonEncode({
              'media_file_id': 'media-id',
              'upload_url': 'https://upload.example.com/photo',
              'upload_method': 'PUT',
              'upload_headers': {'Content-Type': 'image/jpeg'},
              'expires_at': '2026-09-06T03:00:00Z',
            }),
          );
        }
        if (request.uri.host == 'upload.example.com') {
          expect(request.method, 'PUT');
          expect(request.headers, {'Content-Type': 'image/jpeg'});
          expect(request.headers.containsKey('authorization'), isFalse);
          expect(request.rawBody, photoBytes);
          return const LeafieHttpResponse(statusCode: 200, body: '');
        }
        if (request.uri.path == '/api/v1/media/media-id/complete') {
          expect(request.method, 'POST');
          expect(request.body, isEmpty);
          return const LeafieHttpResponse(
            statusCode: 200,
            body:
                '{"id":"media-id","status":"READY","content_type":"image/jpeg","size_bytes":4}',
          );
        }
        if (request.uri.path == '/api/v1/plants/plant-id/diagnoses') {
          expect(request.method, 'POST');
          expect(request.body, {'media_file_id': 'media-id'});
          return const LeafieHttpResponse(
            statusCode: 202,
            body:
                '{"diagnosis_id":"diagnosis-id","status":"PENDING","created_at":"2026-09-06T01:02:03Z"}',
          );
        }
        expect(request.uri.path, '/api/v1/diagnoses/diagnosis-id');
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'id': 'diagnosis-id',
            'plant_id': 'plant-id',
            'status': 'COMPLETED',
            'diagnosed_at': '2026-09-06T01:02:03Z',
            'photo_url': 'https://example.com/plant.jpg',
            'overall_condition': 'CAUTION',
            'condition_label': '조금 관리가 필요해요',
            'observations': ['잎 처짐'],
            'possible_causes': [
              {'name': '과습', 'confidence': 0.76},
            ],
            'recommended_care': ['물을 줄여주세요.'],
            'retake_reason_code': null,
            'failure_code': null,
          }),
        );
      }),
    );

    final result = await api.submitDiagnosis(
      plantId: 'plant-id',
      photoBytes: photoBytes,
    );

    expect(result.id, 'diagnosis-id');
    expect(result.status, 'COMPLETED');
    expect(
      requests.where((request) => request.uri.path.contains('conversations')),
      isEmpty,
    );
    expect(requests, hasLength(5));
  });
}
