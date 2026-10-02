import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/sensor_api.dart';

void main() {
  SensorApi api(LeafieTransport transport) => SensorApi(
    client: LeafieApiClient(
      baseUrl: 'http://localhost:8000/api/v1',
      accessTokenProvider: () async => 'test-access-token',
      transport: transport,
    ),
  );

  LeafieHttpResponse json(int status, Object body) =>
      LeafieHttpResponse(statusCode: status, body: jsonEncode(body));

  test('기기 등록은 deviceId를 POST하고 201/200 응답을 파싱한다', () async {
    for (final status in [201, 200]) {
      final result = await api((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/sensor-devices');
        expect(request.body, {'deviceId': 'D40592E7D168'});
        expect(request.headers['authorization'], 'Bearer test-access-token');
        return json(status, {'deviceId': 'D40592E7D168', 'status': 'CLAIMED'});
      }).registerDevice('D40592E7D168');
      expect(result.deviceId, 'D40592E7D168');
      expect(result.status, SensorDeviceStatus.claimed);
    }
  });

  test('claim 생성은 claimToken을 돌려주고 409를 예외로 던진다', () async {
    final token = await api((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/sensor-devices/D40592E7D168/claims');
      return json(201, {'claimToken': 'token-1'});
    }).createClaim('D40592E7D168');
    expect(token, 'token-1');

    await expectLater(
      api(
        (_) async => json(409, {
          'error': {'code': 'SENSOR_DEVICE_ALREADY_CLAIMED', 'message': 'x'},
        }),
      ).createClaim('D40592E7D168'),
      throwsA(
        isA<LeafieApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'SENSOR_DEVICE_ALREADY_CLAIMED'),
      ),
    );
  });

  test('claim 상태 4가지를 모두 파싱한다', () async {
    const expected = {
      'PENDING': SensorDeviceClaimStatus.pending,
      'COMPLETED': SensorDeviceClaimStatus.completed,
      'EXPIRED': SensorDeviceClaimStatus.expired,
      'CANCELLED': SensorDeviceClaimStatus.cancelled,
    };
    for (final entry in expected.entries) {
      final status = await api((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/v1/sensor-device-claims/token-1');
        return json(200, {'status': entry.key});
      }).getClaimStatus('token-1');
      expect(status, entry.value);
    }
  });

  test('기기 목록은 null 필드를 그대로 허용한다', () async {
    final items = await api((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/v1/sensor-devices');
      return json(200, {
        'items': [
          {
            'deviceId': 'AAAAAAAAAAAA',
            'status': 'CLAIMED',
            'lastSeenAt': '2026-07-01T00:00:00Z',
            'plantId': 'plant-1',
            'lux': 123.4,
            'soilPercent': 64,
            'measuredAt': '2026-07-01T00:00:00Z',
          },
          {
            'deviceId': 'BBBBBBBBBBBB',
            'status': 'UNCLAIMED',
            'lastSeenAt': null,
            'plantId': null,
            'lux': null,
            'soilPercent': null,
            'measuredAt': null,
          },
          {
            'deviceId': 'CCCCCCCCCCCC',
            'status': 'CLAIMED',
            'lastSeenAt': null,
            'plantId': null,
            'lux': 100,
            'soilPercent': null,
            'measuredAt': null,
          },
        ],
      });
    }).listDevices();

    expect(items, hasLength(3));
    expect(items[0].plantId, 'plant-1');
    expect(items[0].lux, 123.4);
    expect(items[0].soilPercent, 64);
    expect(items[0].lastSeenAt, DateTime.utc(2026, 7, 1));
    expect(items[0].measuredAt, DateTime.utc(2026, 7, 1));
    expect(items[1].status, SensorDeviceStatus.unclaimed);
    expect(items[1].plantId, isNull);
    expect(items[1].lux, isNull);
    expect(items[1].soilPercent, isNull);
    expect(items[1].measuredAt, isNull);
    expect(items[1].lastSeenAt, isNull);
    expect(items[2].lux, 100.0);
  });

  test('기기 해제는 DELETE를 보내고 204 빈 본문을 허용한다', () async {
    var called = false;
    await api((request) async {
      called = true;
      expect(request.method, 'DELETE');
      expect(request.uri.path, '/api/v1/sensor-devices/D40592E7D168');
      return const LeafieHttpResponse(statusCode: 204, body: '');
    }).releaseDevice('D40592E7D168');
    expect(called, isTrue);
  });

  test('식물-기기 연결은 PUT, 해제는 DELETE를 보낸다', () async {
    final linked = await api((request) async {
      expect(request.method, 'PUT');
      expect(request.uri.path, '/api/v1/plants/plant-1/sensor-device');
      expect(request.body, {'deviceId': 'D40592E7D168'});
      return json(200, {'plantId': 'plant-1', 'deviceId': 'D40592E7D168'});
    }).connectPlantDevice('plant-1', 'D40592E7D168');
    expect(linked.plantId, 'plant-1');
    expect(linked.deviceId, 'D40592E7D168');

    var called = false;
    await api((request) async {
      called = true;
      expect(request.method, 'DELETE');
      expect(request.uri.path, '/api/v1/plants/plant-1/sensor-device');
      return const LeafieHttpResponse(statusCode: 204, body: '');
    }).disconnectPlantDevice('plant-1');
    expect(called, isTrue);
  });

  test('센서 상태 ACTIVE는 latest와 dailyLight를 파싱한다', () async {
    final status = await api((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/v1/plants/plant-1/sensor/status');
      return json(200, {
        'plantId': 'plant-1',
        'deviceId': 'D40592E7D168',
        'connection': 'ACTIVE',
        'latest': {
          'lux': 123.4,
          'soilPercent': 50,
          'measuredAt': '2026-10-01T02:55:00Z',
          'receivedAt': '2026-10-01T02:56:00Z',
        },
        'dailyLight': {'date': '2026-10-01', 'luxHours': 1000},
      });
    }).getPlantSensorStatus('plant-1');

    expect(status.connection, SensorConnection.active);
    expect(status.deviceId, 'D40592E7D168');
    expect(status.latest!.lux, 123.4);
    expect(status.latest!.soilPercent, 50);
    expect(status.latest!.measuredAt, DateTime.utc(2026, 10, 1, 2, 55));
    expect(status.latest!.receivedAt, DateTime.utc(2026, 10, 1, 2, 56));
    expect(status.dailyLight!.date, DateTime(2026, 10, 1));
    expect(status.dailyLight!.luxHours, 1000.0);
  });

  test('센서 상태 연결 enum 4가지와 null 필드를 파싱한다', () async {
    Future<PlantSensorStatus> fetch(Map<String, Object?> body) =>
        api((_) async => json(200, body)).getPlantSensorStatus('plant-1');

    final noDevice = await fetch({
      'plantId': 'plant-1',
      'deviceId': null,
      'connection': 'NO_DEVICE',
      'latest': null,
      'dailyLight': null,
    });
    expect(noDevice.connection, SensorConnection.noDevice);
    expect(noDevice.deviceId, isNull);
    expect(noDevice.latest, isNull);
    expect(noDevice.dailyLight, isNull);

    final noData = await fetch({
      'plantId': 'plant-1',
      'deviceId': 'D40592E7D168',
      'connection': 'NO_DATA',
      'latest': null,
      'dailyLight': null,
    });
    expect(noData.connection, SensorConnection.noData);
    expect(noData.deviceId, 'D40592E7D168');

    final stale = await fetch({
      'plantId': 'plant-1',
      'deviceId': 'D40592E7D168',
      'connection': 'STALE',
      'latest': {
        'lux': null,
        'soilPercent': null,
        'measuredAt': null,
        'receivedAt': '2026-10-01T02:56:00Z',
      },
      'dailyLight': null,
    });
    expect(stale.connection, SensorConnection.stale);
    expect(stale.latest!.lux, isNull);
    expect(stale.latest!.soilPercent, isNull);
    expect(stale.latest!.measuredAt, isNull);
  });

  test('잘못된 응답은 INVALID_RESPONSE 예외로 바뀐다', () async {
    final malformed = <Future<Object?> Function()>[
      () => api(
        (_) async => json(200, {'plantId': 'p', 'connection': 'UNKNOWN'}),
      ).getPlantSensorStatus('p'),
      () => api((_) async => json(200, {'items': 'nope'})).listDevices(),
      () => api(
        (_) async => json(200, {
          'items': [
            {'deviceId': 'A', 'status': 'CLAIMED', 'soilPercent': '50'},
          ],
        }),
      ).listDevices(),
      () => api((_) async => json(200, {'status': 'DONE'})).getClaimStatus('t'),
      () => api((_) async => json(201, {'claimToken': 1})).createClaim('A'),
    ];
    for (final call in malformed) {
      await expectLater(
        call(),
        throwsA(
          isA<LeafieApiException>()
              .having((e) => e.code, 'code', 'INVALID_RESPONSE')
              .having((e) => e.statusCode, 'statusCode', 502),
        ),
      );
    }
  });

  test('모델 fromJson은 잘못된 타입에서 FormatException을 던진다', () {
    expect(
      () => SensorDeviceData.fromJson({'deviceId': 1, 'status': 'CLAIMED'}),
      throwsFormatException,
    );
    expect(
      () => SensorLatestReading.fromJson({
        'lux': 'bright',
        'receivedAt': '2026-10-01T02:56:00Z',
      }),
      throwsFormatException,
    );
    expect(
      () => SensorDailyLight.fromJson({'date': 'bad', 'luxHours': 1}),
      throwsFormatException,
    );
  });
}
