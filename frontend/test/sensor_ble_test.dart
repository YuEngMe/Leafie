import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_provisioning_ble/esp_provisioning_ble.dart';
// ignore: implementation_imports
import 'package:esp_provisioning_ble/src/protos/generated/session.pb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/esp_sensor_ble.dart';
import 'package:yeso_plant/services/sensor_ble.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

class _PlainSecurity implements ProvSecurity {
  @override
  Future<Uint8List> encrypt(Uint8List data) async => data;

  @override
  Future<Uint8List> decrypt(Uint8List data) async => data;

  @override
  Future<SessionData?> securitySession(SessionData responseData) async => null;
}

class _FakeTransport implements ProvTransport {
  _FakeTransport(this.responses);

  final Map<String, Uint8List> responses;
  final sent = <String, String>{};
  Object? error;

  @override
  Future<bool> connect() async => true;

  @override
  Future<bool> checkConnect() async => true;

  @override
  Future<bool> disconnect() async => true;

  @override
  Future<Uint8List> sendReceive(String epName, Uint8List data) async {
    sent[epName] = utf8.decode(data);
    if (error != null) throw error!;
    return responses[epName] ?? Uint8List(0);
  }
}

void main() {
  group('입력 형식', () {
    test('기기 ID는 대문자 hex 12자리', () {
      expect(isValidSensorDeviceId('D40592E7D168'), isTrue);
      expect(isValidSensorDeviceId('d40592e7d168'), isFalse);
      expect(isValidSensorDeviceId('D40592E7D16'), isFalse);
    });

    test('PIN은 숫자 8자리', () {
      expect(isValidSensorPin('48201937'), isTrue);
      expect(isValidSensorPin('4820193'), isFalse);
      expect(isValidSensorPin('4820193a'), isFalse);
      expect(isValidSensorPin('leafie_pop'), isFalse);
    });

    test('BLE 이름에서 기기 ID를 꺼낸다', () {
      expect(sensorDeviceIdFromBleName('PROV_D40592E7D168'), 'D40592E7D168');
      expect(sensorDeviceIdFromBleName('PROV_xyz'), isNull);
      expect(sensorDeviceIdFromBleName('Speaker'), isNull);
      expect(sensorDeviceIdFromBleName(null), isNull);
    });
  });

  group('device-info', () {
    test('두 상태를 읽는다', () {
      final info = decodeSensorDeviceInfo(
        _bytes(
          '{"deviceId":"D40592E7D168","state":"WAITING_CLAIM","hasDeviceToken":false}',
        ),
      );
      expect(info.deviceId, 'D40592E7D168');
      expect(info.state, SensorDeviceBleState.waitingClaim);
      expect(info.hasDeviceToken, isFalse);

      final reset = decodeSensorDeviceInfo(
        _bytes(
          '{"deviceId":"D40592E7D168","state":"PROVISIONING","hasDeviceToken":true}',
        ),
      );
      expect(reset.state, SensorDeviceBleState.provisioning);
      expect(reset.hasDeviceToken, isTrue);
    });

    test('모르는 상태나 깨진 응답은 protocol 오류', () {
      for (final raw in [
        '{"deviceId":"D40592E7D168","state":"ACTIVE","hasDeviceToken":true}',
        '{"deviceId":"D40592E7D168","state":"PROVISIONING"}',
        'not json',
        '[]',
      ]) {
        expect(
          () => decodeSensorDeviceInfo(_bytes(raw)),
          throwsA(
            isA<SensorBleException>().having(
              (e) => e.error,
              'error',
              SensorBleError.protocol,
            ),
          ),
          reason: raw,
        );
      }
    });
  });

  group('claim', () {
    test('요청은 claimToken JSON', () {
      final token = 'a' * 64;
      expect(jsonDecode(utf8.decode(encodeSensorClaimRequest(token))), {
        'claimToken': token,
      });
    });

    test('status ok만 받아들인다', () {
      checkSensorClaimResponse(_bytes('{"status":"ok"}'));
      for (final raw in ['', '{"status":"error"}', 'ok']) {
        expect(
          () => checkSensorClaimResponse(_bytes(raw)),
          throwsA(isA<SensorBleException>()),
          reason: raw,
        );
      }
    });
  });

  group('엔드포인트 표', () {
    final scan = sensorBleCharacteristicUuid(0xFF50);
    final session = sensorBleCharacteristicUuid(0xFF51);
    final config = sensorBleCharacteristicUuid(0xFF52);
    final version = sensorBleCharacteristicUuid(0xFF53);
    final ff54 = sensorBleCharacteristicUuid(0xFF54);
    final ff55 = sensorBleCharacteristicUuid(0xFF55);

    test('특성 UUID는 서비스 UUID에 번호를 끼운다', () {
      expect(session, '021aff51-0382-4aea-bff4-6b3f1c5adfb4');
    });

    test('디스크립터 이름이 있으면 그것을 쓴다', () {
      final table = sensorBleEndpointTable({
        session: 'prov-session',
        ff54: 'claim',
        ff55: 'device-info',
      });
      expect(table['prov-session'], session);
      expect(table['claim'], ff54);
      expect(table['device-info'], ff55);
    });

    test('못 읽은 특성만 기본 번호로 채운다', () {
      final table = sensorBleEndpointTable({
        scan: null,
        session: null,
        config: null,
        version: null,
        ff54: null,
      });
      expect(table['prov-session'], session);
      expect(table['prov-config'], config);
      expect(table['device-info'], ff54);
      // Wi-Fi 설정 세션에는 claim 특성이 없다
      expect(table.containsKey('claim'), isFalse);
    });

    test('디스크립터 값의 NUL과 공백을 지운다', () {
      expect(decodeSensorBleDescriptorName(_bytes('claim\u0000')), 'claim');
      expect(decodeSensorBleDescriptorName(Uint8List(0)), isNull);
      expect(decodeSensorBleDescriptorName(null), isNull);
    });
  });

  group('Wi-Fi 상태', () {
    test('실패 사유는 ConnectionFailed일 때만 쓴다', () {
      expect(
        sensorWifiStatusFrom(
          ConnectionStatus(state: WifiConnectionState.Connected),
        ),
        SensorWifiStatus.connected,
      );
      expect(
        sensorWifiStatusFrom(
          ConnectionStatus(
            state: WifiConnectionState.ConnectionFailed,
            failedReason: WifiConnectFailedReason.AuthError,
          ),
        ),
        SensorWifiStatus.authError,
      );
      expect(
        sensorWifiStatusFrom(
          ConnectionStatus(
            state: WifiConnectionState.ConnectionFailed,
            failedReason: WifiConnectFailedReason.NetworkNotFound,
          ),
        ),
        SensorWifiStatus.networkNotFound,
      );
      expect(
        sensorWifiStatusFrom(
          ConnectionStatus(state: WifiConnectionState.ConnectionFailed),
        ),
        SensorWifiStatus.failed,
      );
    });
  });

  group('세션', () {
    late _FakeTransport transport;
    late bool closed;
    late EspSensorBleSession session;

    setUp(() {
      transport = _FakeTransport({
        'device-info': _bytes(
          '{"deviceId":"D40592E7D168","state":"PROVISIONING","hasDeviceToken":false}',
        ),
        'claim': _bytes('{"status":"ok"}'),
      });
      closed = false;
      session = EspSensorBleSession(
        deviceId: 'D40592E7D168',
        bleId: 'ble-1',
        prov: EspProv(transport: transport, security: _PlainSecurity()),
        onClose: () async => closed = true,
      );
    });

    test('device-info는 빈 객체를 써서 읽는다', () async {
      final info = await session.readDeviceInfo();
      expect(transport.sent['device-info'], '{}');
      expect(info.state, SensorDeviceBleState.provisioning);
    });

    test('claimToken을 claim 엔드포인트로 보낸다', () async {
      await session.sendClaimToken('t' * 64);
      expect(jsonDecode(transport.sent['claim']!), {'claimToken': 't' * 64});
    });

    test('빈 응답과 전송 오류는 protocol 오류', () async {
      transport.responses.remove('claim');
      await expectLater(
        session.sendClaimToken('t'),
        throwsA(
          isA<SensorBleException>().having(
            (e) => e.error,
            'error',
            SensorBleError.protocol,
          ),
        ),
      );
      transport.error = StateError('gatt');
      await expectLater(
        session.readDeviceInfo(),
        throwsA(isA<SensorBleException>()),
      );
    });

    test('닫은 뒤에는 disconnected', () async {
      await session.close();
      expect(closed, isTrue);
      await expectLater(
        session.readDeviceInfo(),
        throwsA(
          isA<SensorBleException>().having(
            (e) => e.error,
            'error',
            SensorBleError.disconnected,
          ),
        ),
      );
    });
  });
}
