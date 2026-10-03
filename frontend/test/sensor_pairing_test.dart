import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/sensor_api.dart';
import 'package:yeso_plant/services/sensor_ble.dart';
import 'package:yeso_plant/services/sensor_pairing.dart';

const _id = 'D40592E7D168';
const _device = SensorBleDevice(deviceId: _id, bleId: 'ble-1');
const _pin = '48201937';

const _fast = SensorPairingTimings(
  scan: Duration(milliseconds: 20),
  rescanAttempts: 2,
  wifiStatusInterval: Duration(milliseconds: 1),
  wifiConnect: Duration(milliseconds: 50),
  claimPollInterval: Duration(milliseconds: 2),
  claimWait: Duration(milliseconds: 60),
  bleSettle: Duration(milliseconds: 5),
);

SensorDeviceInfo _info(
  SensorDeviceBleState state, {
  bool hasDeviceToken = false,
  String deviceId = _id,
}) => SensorDeviceInfo(
  deviceId: deviceId,
  state: state,
  hasDeviceToken: hasDeviceToken,
);

class _FakeSession implements SensorBleSession {
  _FakeSession(this.ble, this.info);

  final _FakeBle ble;
  final SensorDeviceInfo info;
  bool closed = false;
  final sentWifi = <String>[];

  @override
  String get deviceId => info.deviceId;

  @override
  Future<SensorDeviceInfo> readDeviceInfo() async => info;

  @override
  Future<List<SensorWifiNetwork>> scanWifi() async => ble.networks;

  @override
  Future<void> sendWifi({
    required String ssid,
    required String password,
  }) async {
    sentWifi.add('$ssid/$password');
  }

  @override
  Future<SensorWifiStatus> readWifiStatus() async {
    if (ble.wifiStatuses.isEmpty) {
      throw const SensorBleException(SensorBleError.disconnected);
    }
    return ble.wifiStatuses.removeAt(0);
  }

  @override
  Future<void> sendClaimToken(String claimToken) async {
    ble.claimTokens.add(claimToken);
    if (ble.claimSendError != null) throw ble.claimSendError!;
  }

  @override
  Future<void> close() async => closed = true;
}

class _FakeBle implements SensorBle {
  SensorBleAvailability availabilityValue = SensorBleAvailability.ready;

  /// connect 호출 순서대로 쓰는 device-info. 마지막 값은 계속 쓴다.
  List<SensorDeviceInfo> infos = [_info(SensorDeviceBleState.provisioning)];

  /// scan 호출마다 내보낼 기기 목록. 인덱스는 호출 순서.
  List<SensorBleDevice> Function(int call) scanPlan = (_) => [_device];
  int scanCalls = 0;

  SensorBleException? connectError;
  SensorBleException? claimSendError;
  int activeScans = 0;
  List<SensorWifiNetwork> networks = const [
    SensorWifiNetwork(ssid: 'Home_2.4G', rssi: -40),
  ];
  List<SensorWifiStatus> wifiStatuses = [SensorWifiStatus.connected];
  final claimTokens = <String>[];
  final sessions = <_FakeSession>[];
  final connectedPins = <String>[];

  @override
  Future<SensorBleAvailability> availability() async => availabilityValue;

  @override
  Stream<List<SensorBleDevice>> scan({
    Duration timeout = const Duration(seconds: 30),
  }) {
    final devices = scanPlan(scanCalls++);
    Timer? timer;
    var active = false;
    void stop() {
      timer?.cancel();
      if (active) activeScans--;
      active = false;
    }

    late final StreamController<List<SensorBleDevice>> controller;
    controller = StreamController(
      onListen: () {
        active = true;
        activeScans++;
        if (devices.isNotEmpty) controller.add(devices);
        timer = Timer(timeout, () {
          stop();
          controller.close();
        });
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
    if (connectError != null) throw connectError!;
    connectedPins.add(pin);
    final info = infos.length > sessions.length
        ? infos[sessions.length]
        : infos.last;
    final session = _FakeSession(this, info);
    sessions.add(session);
    return session;
  }
}

class _FakeRepository implements SensorRepository {
  final registered = <String>[];
  int claims = 0;
  LeafieApiException? claimError;

  /// 토큰마다 getClaimStatus가 차례로 돌려줄 값. 다 쓰면 PENDING.
  Map<String, List<SensorDeviceClaimStatus>> statuses = {};
  List<SensorDeviceClaimStatus> Function(String token) defaultStatuses = (_) =>
      [SensorDeviceClaimStatus.pending, SensorDeviceClaimStatus.completed];
  List<SensorDeviceListItem> mine = [];
  final linked = <String>[];

  @override
  Future<SensorDeviceData> registerDevice(String deviceId) async {
    registered.add(deviceId);
    return SensorDeviceData.fromJson({
      'deviceId': deviceId,
      'status': 'UNCLAIMED',
    });
  }

  @override
  Future<String> createClaim(String deviceId) async {
    if (claimError != null) throw claimError!;
    claims++;
    return 'token-$claims';
  }

  @override
  Future<SensorDeviceClaimStatus> getClaimStatus(String claimToken) async {
    final queue = statuses.putIfAbsent(
      claimToken,
      () => defaultStatuses(claimToken),
    );
    return queue.isEmpty ? SensorDeviceClaimStatus.pending : queue.removeAt(0);
  }

  @override
  Future<List<SensorDeviceListItem>> listDevices() async => mine;

  @override
  Future<PlantSensorDevice> connectPlantDevice(
    String plantId,
    String deviceId,
  ) async {
    linked.add('$plantId:$deviceId');
    return PlantSensorDevice.fromJson({
      'plantId': plantId,
      'deviceId': deviceId,
    });
  }

  @override
  Future<void> releaseDevice(String deviceId) async {}

  @override
  Future<void> disconnectPlantDevice(String plantId) async {}

  @override
  Future<PlantSensorStatus> getPlantSensorStatus(String plantId) =>
      throw UnimplementedError();
}

/// 상태가 [T]가 될 때까지 기다린다.
Future<T> _until<T extends SensorPairingState>(SensorPairing pairing) {
  if (pairing.state is T) return Future.value(pairing.state as T);
  final completer = Completer<T>();
  void listener() {
    if (pairing.state is T && !completer.isCompleted) {
      completer.complete(pairing.state as T);
    }
  }

  pairing.addListener(listener);
  return completer.future
      .timeout(const Duration(seconds: 2))
      .whenComplete(() => pairing.removeListener(listener));
}

SensorDeviceListItem _mine() => SensorDeviceListItem.fromJson({
  'deviceId': _id,
  'status': 'CLAIMED',
  'lastSeenAt': null,
  'plantId': null,
  'lux': null,
  'soilPercent': null,
  'measuredAt': null,
});

/// [calls]번째 scan 호출에서만 기기가 보인다. claim을 기다리는 동안의 감시
/// 검색에서 보이면 기기가 claim을 포기하고 다시 광고한다는 뜻이다.
List<SensorBleDevice> Function(int) _visibleOn(Set<int> calls) =>
    (call) => calls.contains(call) ? [_device] : [];

void main() {
  late _FakeBle ble;
  late _FakeRepository repository;
  late SensorPairing pairing;

  setUp(() {
    ble = _FakeBle();
    repository = _FakeRepository();
    pairing = SensorPairing(ble: ble, repository: repository, timings: _fast);
  });

  tearDown(() => pairing.dispose());

  test('블루투스가 꺼져 있으면 검색하지 않는다', () async {
    ble.availabilityValue = SensorBleAvailability.poweredOff;
    await pairing.start();
    expect(
      (pairing.state as SensorPairingBluetoothUnavailable).availability,
      SensorBleAvailability.poweredOff,
    );
    expect(ble.scanCalls, 0);
  });

  test('검색이 끝나면 done으로 알린다', () async {
    await pairing.start();
    expect(pairing.state, isA<SensorPairingScanning>());
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final found = pairing.state as SensorPairingScanning;
    expect(found.devices.single.deviceId, _id);
    expect(found.done, isTrue);
  });

  test('처음 등록: Wi-Fi → claim → 식물 연결', () async {
    // scan 0: Wi-Fi 연결 뒤 재검색(보임), 1: claim 대기 중 감시(안 보임)
    ble.scanPlan = _visibleOn({0});
    ble.infos = [
      _info(SensorDeviceBleState.provisioning),
      _info(SensorDeviceBleState.waitingClaim),
    ];

    pairing.selectDevice(_device);
    expect(pairing.state, isA<SensorPairingNeedPin>());
    await pairing.submitPin(_pin);
    final wifi = pairing.state as SensorPairingWifiInput;
    expect(wifi.networks.single.ssid, 'Home_2.4G');
    expect(wifi.lastFailure, isNull);

    await pairing.submitWifi(ssid: 'Home_2.4G', password: 'pw');
    final choose = pairing.state as SensorPairingChoosePlant;
    expect(choose.deviceId, _id);
    expect(ble.sessions.first.sentWifi, ['Home_2.4G/pw']);
    expect(repository.registered, [_id]);
    expect(ble.claimTokens, ['token-1']);
    expect(ble.connectedPins, [_pin, _pin]);
    expect(ble.sessions.every((s) => s.closed), isTrue);

    await pairing.linkPlant('plant-1');
    final done = pairing.state as SensorPairingDone;
    expect(done.plantId, 'plant-1');
    expect(done.wifiOnly, isFalse);
    expect(repository.linked, ['plant-1:$_id']);
  });

  test('비밀번호가 틀리면 같은 세션에서 다시 입력받는다', () async {
    ble.scanPlan = _visibleOn({0});
    ble.infos = [
      _info(SensorDeviceBleState.provisioning),
      _info(SensorDeviceBleState.waitingClaim),
    ];
    ble.wifiStatuses = [
      SensorWifiStatus.connecting,
      SensorWifiStatus.authError,
      SensorWifiStatus.connected,
    ];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);

    await pairing.submitWifi(ssid: 'Home_2.4G', password: 'wrong');
    expect(
      (pairing.state as SensorPairingWifiInput).lastFailure,
      SensorWifiStatus.authError,
    );
    expect(ble.sessions.single.closed, isFalse);

    await pairing.submitWifi(ssid: 'Home_2.4G', password: 'right');
    expect(pairing.state, isA<SensorPairingChoosePlant>());
    expect(ble.sessions.first.sentWifi, ['Home_2.4G/wrong', 'Home_2.4G/right']);
  });

  test('Wi-Fi 적용 뒤 세션이 끊겨도 연결된 것으로 보고 claim으로 간다', () async {
    ble.scanPlan = _visibleOn({0});
    ble.infos = [
      _info(SensorDeviceBleState.provisioning),
      _info(SensorDeviceBleState.waitingClaim),
    ];
    ble.wifiStatuses = [SensorWifiStatus.connecting];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    await pairing.submitWifi(ssid: 'Home_2.4G', password: 'pw');
    expect(pairing.state, isA<SensorPairingChoosePlant>());
  });

  test('토큰이 있는 기기는 Wi-Fi만 받고 끝난다', () async {
    ble.infos = [
      _info(SensorDeviceBleState.provisioning, hasDeviceToken: true),
    ];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    await pairing.submitWifi(ssid: 'Home_2.4G', password: 'pw');
    final done = pairing.state as SensorPairingDone;
    expect(done.wifiOnly, isTrue);
    expect(repository.claims, 0);
  });

  test('Wi-Fi가 이미 있는 기기는 Wi-Fi 단계를 건너뛴다', () async {
    ble.scanPlan = _visibleOn({0});
    ble.infos = [_info(SensorDeviceBleState.waitingClaim)];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    expect(pairing.state, isA<SensorPairingChoosePlant>());
    expect(ble.claimTokens, ['token-1']);
  });

  test('PIN이 틀리면 다시 묻는다', () async {
    ble.connectError = const SensorBleException(SensorBleError.wrongPin);
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    expect((pairing.state as SensorPairingNeedPin).wrongPin, isTrue);
  });

  test('다른 기기가 응답하면 오류', () async {
    ble.infos = [
      _info(SensorDeviceBleState.provisioning, deviceId: 'AAAAAAAAAAAA'),
    ];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    final error = (pairing.state as SensorPairingError).error;
    expect((error as SensorBleException).error, SensorBleError.protocol);
  });

  group('409', () {
    setUp(() {
      ble.infos = [_info(SensorDeviceBleState.waitingClaim)];
      repository.claimError = const LeafieApiException(
        code: 'CONFLICT',
        message: 'conflict',
        statusCode: 409,
      );
    });

    test('내 기기 목록에 있으면 ownedByMe', () async {
      repository.mine = [_mine()];
      pairing.selectDevice(_device);
      await pairing.submitPin(_pin);
      expect((pairing.state as SensorPairingAlreadyClaimed).ownedByMe, isTrue);
    });

    test('없으면 다른 사람 기기', () async {
      pairing.selectDevice(_device);
      await pairing.submitPin(_pin);
      expect((pairing.state as SensorPairingAlreadyClaimed).ownedByMe, isFalse);
    });
  });

  test('기기가 다시 광고하면 새 토큰으로 다시 보낸다', () async {
    ble.infos = [_info(SensorDeviceBleState.waitingClaim)];
    // scan 0: 재검색, 1: 감시(다시 보임 → 기기가 포기), 2: 재검색, 3: 감시(안 보임)
    ble.scanPlan = _visibleOn({0, 1, 2});
    repository.statuses = {
      'token-1': [SensorDeviceClaimStatus.pending],
    };
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    expect(pairing.state, isA<SensorPairingChoosePlant>());
    expect(ble.claimTokens, ['token-1', 'token-2']);
  });

  test('연속으로 포기하면 Wi-Fi 재설정을 안내한다', () async {
    ble.infos = [_info(SensorDeviceBleState.waitingClaim)];
    ble.scanPlan = (_) => [_device];
    repository.defaultStatuses = (_) => [];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    final failed = pairing.state as SensorPairingClaimFailed;
    expect(failed.failure, SensorClaimFailure.notCompleted);
    expect(failed.suggestWifiReset, isTrue);
    expect(ble.claimTokens.length, sensorClaimFailuresBeforeWifiHint);
  });

  test('서버가 끝내 PENDING이면 실패, 다시 시도하면 새 토큰', () async {
    ble.infos = [_info(SensorDeviceBleState.waitingClaim)];
    // scan 0: 재검색, 1: 감시(안 보임 → 시간 초과), 2: 재시도 재검색, 3: 감시
    ble.scanPlan = _visibleOn({0, 2});
    repository.statuses = {'token-1': []};
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    final failed = pairing.state as SensorPairingClaimFailed;
    expect(failed.failure, SensorClaimFailure.notCompleted);
    expect(failed.suggestWifiReset, isFalse);

    await pairing.retry();
    expect(pairing.state, isA<SensorPairingChoosePlant>());
    expect(ble.claimTokens, ['token-1', 'token-2']);
  });

  test('Wi-Fi 연결 뒤 기기를 다시 찾지 못하면 실패', () async {
    ble.scanPlan = (_) => [];
    ble.infos = [_info(SensorDeviceBleState.provisioning)];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    await pairing.submitWifi(ssid: 'Home_2.4G', password: 'pw');
    expect(
      (pairing.state as SensorPairingClaimFailed).failure,
      SensorClaimFailure.deviceNotFound,
    );
    expect(ble.scanCalls, _fast.rescanAttempts);
  });

  test('Wi-Fi 직후 PROVISIONING이 보이면 정리 중일 수 있어 한 번 더 찾는다', () async {
    // scan 0: 재검색(정리 전 광고), 1: 다시 찾기, 2: 감시(안 보임)
    ble.scanPlan = _visibleOn({0, 1});
    ble.infos = [
      _info(SensorDeviceBleState.provisioning),
      _info(SensorDeviceBleState.provisioning),
      _info(SensorDeviceBleState.waitingClaim),
    ];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    await pairing.submitWifi(ssid: 'Home_2.4G', password: 'pw');
    expect(pairing.state, isA<SensorPairingChoosePlant>());
    expect(ble.claimTokens, ['token-1']);
    expect(ble.sessions.every((s) => s.closed), isTrue);
  });

  test('다시 찾아도 PROVISIONING이면 Wi-Fi 연결 실패로 보고 다시 입력받는다', () async {
    ble.scanPlan = _visibleOn({0, 1});
    ble.infos = [_info(SensorDeviceBleState.provisioning)];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    await pairing.submitWifi(ssid: 'Home_2.4G', password: 'pw');
    expect(
      (pairing.state as SensorPairingWifiInput).lastFailure,
      SensorWifiStatus.failed,
    );
    expect(ble.claimTokens, isEmpty);
    // Wi-Fi를 다시 받을 세션은 열어 둔다
    expect(ble.sessions.last.closed, isFalse);
  });

  test('토큰 전송 응답을 못 읽어도 서버 결과를 기다린다', () async {
    ble.infos = [_info(SensorDeviceBleState.waitingClaim)];
    ble.scanPlan = _visibleOn({0});
    ble.claimSendError = const SensorBleException(SensorBleError.timeout);
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    expect(pairing.state, isA<SensorPairingChoosePlant>());
  });

  test('토큰을 보낸 뒤 다시 시도했더니 409이고 내 기기면 성공으로 본다', () async {
    ble.infos = [_info(SensorDeviceBleState.waitingClaim)];
    ble.scanPlan = _visibleOn({0});
    repository.statuses = {'token-1': []};
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    expect(pairing.state, isA<SensorPairingClaimFailed>());

    // 기기의 claim이 늦게 끝났다
    repository.claimError = const LeafieApiException(
      code: 'CONFLICT',
      message: 'conflict',
      statusCode: 409,
    );
    repository.mine = [_mine()];
    await pairing.retry();
    expect(pairing.state, isA<SensorPairingChoosePlant>());
  });

  test('취소하면 진행 중인 claim이 상태를 바꾸지 않고 검색도 멈춘다', () async {
    ble.infos = [_info(SensorDeviceBleState.waitingClaim)];
    ble.scanPlan = _visibleOn({0});
    repository.defaultStatuses = (_) => [];
    pairing.selectDevice(_device);
    final submitting = pairing.submitPin(_pin);
    await _until<SensorPairingClaiming>(pairing);
    await pairing.cancel();
    await submitting;
    expect(pairing.state, isA<SensorPairingIdle>());
    await Future<void>.delayed(Duration.zero);
    expect(ble.activeScans, 0);
    expect(ble.sessions.every((s) => s.closed), isTrue);
  });

  test('다시 찾는 중에 취소하면 바로 멈춘다', () async {
    ble.infos = [_info(SensorDeviceBleState.provisioning)];
    ble.scanPlan = (_) => [];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    final submitting = pairing.submitWifi(ssid: 'Home_2.4G', password: 'pw');
    await _until<SensorPairingClaiming>(pairing);
    await Future<void>.delayed(const Duration(milliseconds: 8));
    await pairing.cancel();
    // 검색 시간(20ms)이 끝나기 전에 이미 멈춰 있어야 한다
    await Future<void>.delayed(Duration.zero);
    expect(ble.activeScans, 0);
    await submitting;
    expect(pairing.state, isA<SensorPairingIdle>());
  });

  test('Wi-Fi만 다시 설정하면 PIN을 들고 있지 않는다', () async {
    ble.infos = [
      _info(SensorDeviceBleState.provisioning, hasDeviceToken: true),
    ];
    pairing.selectDevice(_device);
    await pairing.submitPin(_pin);
    await pairing.submitWifi(ssid: 'Home_2.4G', password: 'pw');
    expect(pairing.state, isA<SensorPairingDone>());
    // PIN이 지워졌으면 다시 시도해도 연결하지 않는다
    await pairing.retry();
    expect(ble.connectedPins, [_pin]);
  });
}
