import 'dart:convert';
import 'dart:typed_data';

// 센서 기기(ESP32)와 BLE로 주고받는 한 번의 요청·응답만 맡는다. 어떤 순서로
// 무엇을 할지(Wi-Fi 전송, claim 재시도 등)는 이 계층 위에서 정한다.
// 기기 쪽 규칙은 펌웨어 레포(jdk829355/leafie_sensor)의 docs/app-ble-guide.md가 기준이다.

/// 기기가 BLE로 광고하는 이름은 `PROV_{deviceId}`이고 deviceId는 12자리 대문자 hex다.
const sensorBleNamePrefix = 'PROV_';

/// ESP-IDF provisioning BLE 서비스 UUID(펌웨어 기본값).
const sensorBleServiceUuid = '021a9004-0382-4aea-bff4-6b3f1c5adfb4';

final _deviceIdPattern = RegExp(r'^[0-9A-F]{12}$');
final _pinPattern = RegExp(r'^[0-9]{8}$');

bool isValidSensorDeviceId(String value) => _deviceIdPattern.hasMatch(value);

/// PIN(PoP)은 라벨에 인쇄된 숫자 8자리다. 맞는 값인지는 기기가 세션을 열 때 판단한다.
bool isValidSensorPin(String value) => _pinPattern.hasMatch(value);

/// `PROV_D40592E7D168` → `D40592E7D168`. 형식이 다르면 null.
String? sensorDeviceIdFromBleName(String? name) {
  if (name == null || !name.startsWith(sensorBleNamePrefix)) return null;
  final id = name.substring(sensorBleNamePrefix.length);
  return isValidSensorDeviceId(id) ? id : null;
}

abstract interface class SensorBle {
  Future<SensorBleAvailability> availability();

  /// `PROV_` 기기를 찾는다. 찾은 기기 목록 전체를 바뀔 때마다 내보내고,
  /// [timeout]이 지나면 스캔을 멈추고 끝난다. 구독을 취소해도 멈춘다.
  Stream<List<SensorBleDevice>> scan({
    Duration timeout = const Duration(seconds: 30),
  });

  /// 연결하고 PIN으로 security1 세션을 연다. 세션은 동시에 하나만 연다.
  /// 이전 세션이 열려 있으면 먼저 닫는다.
  Future<SensorBleSession> connect(
    SensorBleDevice device, {
    required String pin,
  });
}

abstract interface class SensorBleSession {
  String get deviceId;

  /// 두 BLE 세션(PROVISIONING, WAITING_CLAIM) 모두에서 읽을 수 있다.
  Future<SensorDeviceInfo> readDeviceInfo();

  /// 기기가 스캔한 주변 Wi-Fi(2.4GHz만 나온다).
  Future<List<SensorWifiNetwork>> scanWifi();

  /// SSID·비밀번호를 보내고 적용시킨다. 결과는 [readWifiStatus]로 확인한다.
  Future<void> sendWifi({required String ssid, required String password});

  Future<SensorWifiStatus> readWifiStatus();

  /// WAITING_CLAIM 세션에만 있는 엔드포인트다. 기기가 토큰을 받았다는 뜻일 뿐이고
  /// claim 성공 여부는 서버의 GET claim으로 확인한다.
  Future<void> sendClaimToken(String claimToken);

  Future<void> close();
}

enum SensorBleAvailability { ready, poweredOff, unauthorized, unsupported }

enum SensorBleError {
  /// 블루투스가 꺼져 있거나 권한이 없다.
  unavailable,
  connectFailed,

  /// 세션 핸드셰이크가 실패했다. PIN이 틀린 경우가 대부분이다.
  wrongPin,
  timeout,
  disconnected,

  /// 기기 응답이 예상과 다르다.
  protocol,
}

class SensorBleException implements Exception {
  const SensorBleException(this.error, [this.detail]);

  final SensorBleError error;
  final String? detail;

  @override
  String toString() =>
      'SensorBleException(${error.name}${detail == null ? '' : ': $detail'})';
}

class SensorBleDevice {
  const SensorBleDevice({
    required this.deviceId,
    required this.bleId,
    this.rssi,
  });

  /// 라벨에 인쇄된 ID와 같다.
  final String deviceId;

  /// 플랫폼이 붙인 BLE 식별자(iOS는 UUID). 연결할 때만 쓴다.
  final String bleId;
  final int? rssi;
}

/// 기기가 BLE를 켜는 상황. 펌웨어는 이 두 값만 보낸다.
enum SensorDeviceBleState {
  provisioning('PROVISIONING'),
  waitingClaim('WAITING_CLAIM');

  const SensorDeviceBleState(this.value);
  final String value;
}

class SensorDeviceInfo {
  const SensorDeviceInfo({
    required this.deviceId,
    required this.state,
    required this.hasDeviceToken,
  });

  factory SensorDeviceInfo.fromJson(Map<String, dynamic> json) {
    final deviceId = json['deviceId'];
    final state = json['state'];
    final hasDeviceToken = json['hasDeviceToken'];
    if (deviceId is! String || state is! String || hasDeviceToken is! bool) {
      throw const FormatException('Invalid device-info');
    }
    final parsedState = SensorDeviceBleState.values
        .where((s) => s.value == state)
        .firstOrNull;
    if (parsedState == null) {
      throw FormatException('Unknown device state', state);
    }
    return SensorDeviceInfo(
      deviceId: deviceId,
      state: parsedState,
      hasDeviceToken: hasDeviceToken,
    );
  }

  final String deviceId;
  final SensorDeviceBleState state;

  /// true면 이미 서버에 등록된 기기다. Wi-Fi만 받으면 되고 claim은 하지 않는다.
  final bool hasDeviceToken;
}

/// 보안 방식(잠금 여부)은 두지 않는다. 앱이 쓰는 proto에 WPA3 값이 없어서
/// WPA3 AP가 개방형으로 읽히기 때문이다. 비밀번호 입력은 항상 받는다.
class SensorWifiNetwork {
  const SensorWifiNetwork({required this.ssid, required this.rssi});

  final String ssid;
  final int rssi;
}

enum SensorWifiStatus {
  connected,
  connecting,
  disconnected,

  /// 비밀번호가 틀렸다. 같은 세션에서 다시 보낼 수 있다.
  authError,

  /// AP를 찾지 못했다. 같은 세션에서 다시 보낼 수 있다.
  networkNotFound,

  /// 실패했지만 사유를 모른다.
  failed,
}

SensorDeviceInfo decodeSensorDeviceInfo(Uint8List bytes) {
  try {
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw const FormatException('device-info is not an object');
    }
    return SensorDeviceInfo.fromJson(json);
  } on FormatException catch (e) {
    throw SensorBleException(SensorBleError.protocol, e.message);
  }
}

Uint8List encodeSensorClaimRequest(String claimToken) =>
    utf8.encode(jsonEncode({'claimToken': claimToken}));

/// 기기는 토큰을 받으면 `{"status":"ok"}`를 돌려준다. 형식이 틀린 요청에는
/// 빈 응답이 온다.
void checkSensorClaimResponse(Uint8List bytes) {
  Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    json = null;
  }
  if (json is! Map || json['status'] != 'ok') {
    throw const SensorBleException(
      SensorBleError.protocol,
      'claim not accepted',
    );
  }
}

/// protocomm BLE는 엔드포인트마다 특성 하나를 두고, 서비스 UUID의 3~4번째
/// 바이트 자리에 16비트 번호를 넣어 특성 UUID를 만든다.
/// 예: 0xFF51 → `021aff51-0382-4aea-bff4-6b3f1c5adfb4`
String sensorBleCharacteristicUuid(int shortUuid) {
  final hex = shortUuid.toRadixString(16).padLeft(4, '0');
  return '${sensorBleServiceUuid.substring(0, 4)}$hex'
      '${sensorBleServiceUuid.substring(8)}';
}

/// 엔드포인트 이름 → 특성 UUID. 1차로 각 특성의 0x2901(User Description)
/// 디스크립터에 적힌 이름을 쓴다. 세션마다 등록된 커스텀 엔드포인트가 달라서
/// 번호를 외워 두면 펌웨어가 바뀔 때 깨지기 때문이다. 디스크립터를 못 읽은
/// 엔드포인트만 network_provisioning의 기본 번호로 채운다(커스텀은 등록 순서대로
/// 0xFF54부터, 펌웨어 main.c 기준 device-info → claim).
Map<String, String> sensorBleEndpointTable(
  Map<String, String?> descriptorNameByCharacteristic,
) {
  final table = <String, String>{};
  for (final entry in descriptorNameByCharacteristic.entries) {
    final name = entry.value;
    if (name != null && name.isNotEmpty) {
      table[name] = entry.key.toLowerCase();
    }
  }
  const fallback = {
    'prov-scan': 0xFF50,
    'prov-session': 0xFF51,
    'prov-config': 0xFF52,
    'proto-ver': 0xFF53,
    'device-info': 0xFF54,
    'claim': 0xFF55,
  };
  final present = descriptorNameByCharacteristic.keys
      .map((uuid) => uuid.toLowerCase())
      .toSet();
  for (final entry in fallback.entries) {
    final uuid = sensorBleCharacteristicUuid(entry.value);
    if (!table.containsKey(entry.key) &&
        present.contains(uuid) &&
        !table.containsValue(uuid)) {
      table[entry.key] = uuid;
    }
  }
  return table;
}

/// 디스크립터 값은 UTF-8 문자열이고 끝에 NUL이 붙어 올 수 있다.
String? decodeSensorBleDescriptorName(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  final name = utf8
      .decode(bytes, allowMalformed: true)
      .replaceAll('\u0000', '');
  return name.trim().isEmpty ? null : name.trim();
}
