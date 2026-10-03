import 'dart:async';

import 'package:esp_provisioning_ble/esp_provisioning_ble.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:yeso_plant/services/sensor_ble.dart';

// security1 세션과 Wi-Fi 설정은 esp_provisioning_ble을, BLE 입출력은 universal_ble을 쓴다.
// esp_provisioning_ble은 펌웨어의 network_provisioning과 Wi-Fi 메시지 필드 번호가 같다.
// 주의할 점:
// - 응답이 영영 오지 않는 경로가 있다(iOS 플러그인의 AES 초기화 실패 시).
//   그래서 모든 호출에 timeout을 건다.
// - AES-CTR 상태가 앱 전체에 하나뿐이라 세션은 동시에 하나만 연다.
// - 세션마다 Security1을 새로 만든다. 재사용하면 핸드셰이크 없이 연결됨으로 나온다.

const _connectTimeout = Duration(seconds: 15);
const _sessionTimeout = Duration(seconds: 20);
const _requestTimeout = Duration(seconds: 15);

/// 기기가 Wi-Fi 스캔을 블로킹으로 하므로 일반 요청보다 길게 둔다.
const _wifiScanTimeout = Duration(seconds: 30);

const _userDescriptionUuid = '00002901-0000-1000-8000-00805f9b34fb';

class EspSensorBle implements SensorBle {
  EspSensorBleSession? _active;

  @override
  Future<SensorBleAvailability> availability() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return switch (state) {
      AvailabilityState.poweredOn => SensorBleAvailability.ready,
      AvailabilityState.unauthorized => SensorBleAvailability.unauthorized,
      AvailabilityState.unsupported => SensorBleAvailability.unsupported,
      _ => SensorBleAvailability.poweredOff,
    };
  }

  @override
  Stream<List<SensorBleDevice>> scan({
    Duration timeout = const Duration(seconds: 30),
  }) {
    late final StreamController<List<SensorBleDevice>> controller;
    StreamSubscription<BleDevice>? subscription;
    Timer? timer;
    final found = <String, SensorBleDevice>{};

    Future<void> stop() async {
      timer?.cancel();
      await subscription?.cancel();
      subscription = null;
      try {
        await UniversalBle.stopScan();
      } catch (_) {
        // 이미 멈춘 경우
      }
    }

    controller = StreamController<List<SensorBleDevice>>(
      onListen: () async {
        subscription = UniversalBle.scanStream.listen((device) {
          final deviceId = sensorDeviceIdFromBleName(device.name);
          if (deviceId == null) return;
          found[deviceId] = SensorBleDevice(
            deviceId: deviceId,
            bleId: device.deviceId,
            rssi: device.rssi,
          );
          controller.add(found.values.toList(growable: false));
        });
        timer = Timer(timeout, () async {
          await stop();
          await controller.close();
        });
        try {
          await UniversalBle.startScan(
            scanFilter: ScanFilter(withNamePrefix: [sensorBleNamePrefix]),
          );
        } catch (e) {
          await stop();
          controller.addError(
            SensorBleException(SensorBleError.unavailable, '$e'),
          );
          await controller.close();
        }
      },
      onCancel: stop,
    );
    return controller.stream;
  }

  @override
  Future<SensorBleSession> connect(
    SensorBleDevice device, {
    required String pin,
  }) async {
    await _active?.close();
    _active = null;
    try {
      await UniversalBle.stopScan();
    } catch (_) {
      // 스캔 중이 아니었다
    }

    final bleId = device.bleId;
    try {
      await UniversalBle.connect(bleId, timeout: _connectTimeout);
    } catch (e) {
      throw SensorBleException(SensorBleError.connectFailed, '$e');
    }

    try {
      final endpoints = await _discoverEndpoints(bleId);
      final transport = _UniversalBleTransport(bleId, endpoints);
      final prov = EspProv(
        transport: transport,
        security: Security1(pop: pin),
      );
      final status = await prov.establishSession().timeout(_sessionTimeout);
      switch (status) {
        case EstablishSessionStatus.connected:
          break;
        case EstablishSessionStatus.keymismatch:
          throw const SensorBleException(SensorBleError.wrongPin);
        case EstablishSessionStatus.disconnected:
          throw const SensorBleException(SensorBleError.disconnected);
      }
      final session = EspSensorBleSession(
        deviceId: device.deviceId,
        bleId: bleId,
        prov: prov,
        onClose: () => _disconnect(bleId),
      );
      _active = session;
      return session;
    } catch (e) {
      await _disconnect(bleId);
      if (e is SensorBleException) rethrow;
      if (e is TimeoutException) {
        throw const SensorBleException(SensorBleError.timeout);
      }
      throw SensorBleException(SensorBleError.connectFailed, '$e');
    }
  }

  Future<Map<String, String>> _discoverEndpoints(String bleId) async {
    final services = await UniversalBle.discoverServices(
      bleId,
      withDescriptors: true,
      timeout: _requestTimeout,
    );
    final service = services
        .where((s) => s.uuid.toLowerCase() == sensorBleServiceUuid)
        .firstOrNull;
    if (service == null) {
      throw const SensorBleException(
        SensorBleError.protocol,
        'provisioning service not found',
      );
    }
    final names = <String, String?>{};
    for (final characteristic in service.characteristics) {
      final hasDescription = characteristic.descriptors.any(
        (d) => d.uuid.toLowerCase() == _userDescriptionUuid,
      );
      String? name;
      if (hasDescription) {
        try {
          name = decodeSensorBleDescriptorName(
            await UniversalBle.readDescriptor(
              bleId,
              service.uuid,
              characteristic.uuid,
              _userDescriptionUuid,
              timeout: _requestTimeout,
            ),
          );
        } catch (_) {
          // 기본 번호표로 채운다
        }
      }
      names[characteristic.uuid] = name;
    }
    return sensorBleEndpointTable(names);
  }

  Future<void> _disconnect(String bleId) async {
    if (_active?._bleId == bleId) _active = null;
    try {
      await UniversalBle.disconnect(bleId);
    } catch (_) {
      // 이미 끊겼다
    }
  }
}

class EspSensorBleSession implements SensorBleSession {
  EspSensorBleSession({
    required this.deviceId,
    required String bleId,
    required EspProv prov,
    required Future<void> Function() onClose,
  }) : _bleId = bleId,
       _prov = prov,
       _onClose = onClose;

  @override
  final String deviceId;
  final String _bleId;
  final EspProv _prov;
  final Future<void> Function() _onClose;
  bool _closed = false;

  @override
  Future<SensorDeviceInfo> readDeviceInfo() async {
    // 펌웨어는 입력을 보지 않지만 쓰기가 있어야 핸들러가 돈다.
    final response = await _custom(
      'device-info',
      Uint8List.fromList([0x7B, 0x7D]),
    );
    return decodeSensorDeviceInfo(response);
  }

  @override
  Future<List<SensorWifiNetwork>> scanWifi() async {
    final aps = await _guard(_prov.startScanWiFi, _wifiScanTimeout);
    final bySsid = <String, SensorWifiNetwork>{};
    for (final ap in aps) {
      if (ap.ssid.isEmpty) continue;
      final previous = bySsid[ap.ssid];
      if (previous == null || ap.rssi > previous.rssi) {
        bySsid[ap.ssid] = SensorWifiNetwork(ssid: ap.ssid, rssi: ap.rssi);
      }
    }
    return bySsid.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  @override
  Future<void> sendWifi({
    required String ssid,
    required String password,
  }) async {
    final sent = await _guard(
      () => _prov.sendWifiConfig(ssid: ssid, password: password),
    );
    if (!sent) {
      throw const SensorBleException(SensorBleError.protocol, 'set config');
    }
    final applied = await _guard(_prov.applyWifiConfig);
    if (!applied) {
      throw const SensorBleException(SensorBleError.protocol, 'apply config');
    }
  }

  @override
  Future<SensorWifiStatus> readWifiStatus() async =>
      sensorWifiStatusFrom(await _guard(_prov.getStatus));

  @override
  Future<void> sendClaimToken(String claimToken) async {
    final response = await _custom(
      'claim',
      encodeSensorClaimRequest(claimToken),
    );
    checkSensorClaimResponse(response);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _onClose();
  }

  Future<Uint8List> _custom(String endpoint, Uint8List data) async {
    return _guard(() async {
      final request = await _prov.security.encrypt(data);
      final response = await _prov.transport.sendReceive(endpoint, request);
      if (response.isEmpty) {
        throw SensorBleException(SensorBleError.protocol, 'empty $endpoint');
      }
      return _prov.security.decrypt(response);
    });
  }

  Future<T> _guard<T>(
    Future<T> Function() request, [
    Duration timeout = _requestTimeout,
  ]) async {
    if (_closed) {
      throw const SensorBleException(SensorBleError.disconnected);
    }
    try {
      return await request().timeout(timeout);
    } on SensorBleException {
      rethrow;
    } on TimeoutException {
      throw const SensorBleException(SensorBleError.timeout);
    } catch (e) {
      throw SensorBleException(SensorBleError.protocol, '$e');
    }
  }
}

/// esp_provisioning_ble은 모르는 연결 상태를 AuthError로 돌려주므로,
/// 실패 사유는 [ConnectionStatus.state]가 ConnectionFailed일 때만 믿는다.
@visibleForTesting
SensorWifiStatus sensorWifiStatusFrom(ConnectionStatus status) {
  return switch (status.state) {
    WifiConnectionState.Connected => SensorWifiStatus.connected,
    WifiConnectionState.Connecting => SensorWifiStatus.connecting,
    WifiConnectionState.Disconnected => SensorWifiStatus.disconnected,
    WifiConnectionState.ConnectionFailed => switch (status.failedReason) {
      WifiConnectFailedReason.AuthError => SensorWifiStatus.authError,
      WifiConnectFailedReason.NetworkNotFound =>
        SensorWifiStatus.networkNotFound,
      null => SensorWifiStatus.failed,
    },
  };
}

/// protocomm BLE 한 번의 요청: 엔드포인트 특성에 쓰고 같은 특성을 읽는다.
class _UniversalBleTransport implements ProvTransport {
  _UniversalBleTransport(this.bleId, this.endpoints);

  final String bleId;
  final Map<String, String> endpoints;

  @override
  Future<bool> connect() => checkConnect();

  @override
  Future<bool> checkConnect() async {
    try {
      final state = await UniversalBle.getConnectionState(bleId);
      return state == BleConnectionState.connected;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      await UniversalBle.disconnect(bleId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List> sendReceive(String epName, Uint8List data) async {
    final characteristic = endpoints[epName];
    if (characteristic == null) {
      throw SensorBleException(SensorBleError.protocol, 'no endpoint $epName');
    }
    await UniversalBle.write(
      bleId,
      sensorBleServiceUuid,
      characteristic,
      data,
      timeout: _requestTimeout,
    );
    return UniversalBle.read(
      bleId,
      sensorBleServiceUuid,
      characteristic,
      timeout: _requestTimeout,
    );
  }
}
