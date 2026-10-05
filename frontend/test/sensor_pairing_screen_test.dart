import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/sensor_pairing_screen.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/services/sensor_api.dart';
import 'package:yeso_plant/services/sensor_ble.dart';
import 'package:yeso_plant/services/sensor_pairing.dart';

const _id = 'D40592E7D168';
const _device = SensorBleDevice(deviceId: _id, bleId: 'ble-1', rssi: -50);

const _timings = SensorPairingTimings(
  scan: Duration(milliseconds: 200),
  rescanAttempts: 1,
  wifiStatusInterval: Duration(milliseconds: 10),
  wifiConnect: Duration(milliseconds: 200),
  claimPollInterval: Duration(milliseconds: 10),
  claimWait: Duration(seconds: 5),
  bleSettle: Duration(milliseconds: 10),
);

class _Session implements SensorBleSession {
  _Session(this.ble, this.info);

  final _Ble ble;
  final SensorDeviceInfo info;

  @override
  String get deviceId => info.deviceId;

  @override
  Future<SensorDeviceInfo> readDeviceInfo() async => info;

  @override
  Future<List<SensorWifiNetwork>> scanWifi() async => const [
    SensorWifiNetwork(ssid: 'Home_2.4G', rssi: -40),
  ];

  @override
  Future<void> sendWifi({
    required String ssid,
    required String password,
  }) async => ble.sentWifi.add('$ssid/$password');

  @override
  Future<SensorWifiStatus> readWifiStatus() async => ble.wifiStatuses.isEmpty
      ? SensorWifiStatus.connected
      : ble.wifiStatuses.removeAt(0);

  @override
  Future<void> sendClaimToken(String claimToken) async {}

  @override
  Future<void> close() async {}
}

class _Ble implements SensorBle {
  List<SensorDeviceInfo> infos = const [];
  int connects = 0;
  bool wrongPin = false;
  final sentWifi = <String>[];
  List<SensorWifiStatus> wifiStatuses = [];

  /// claim 대기 중 감시 검색에는 기기가 보이지 않게 한다(= 성공).
  int scans = 0;
  Set<int> visibleScans = {0, 1};

  @override
  Future<SensorBleAvailability> availability() async =>
      SensorBleAvailability.ready;

  @override
  Stream<List<SensorBleDevice>> scan({
    Duration timeout = const Duration(seconds: 30),
  }) {
    final visible = visibleScans.contains(scans++);
    late final StreamController<List<SensorBleDevice>> controller;
    Timer? timer;
    controller = StreamController(
      onListen: () {
        if (visible) controller.add(const [_device]);
        timer = Timer(timeout, controller.close);
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<SensorBleSession> connect(
    SensorBleDevice device, {
    required String pin,
  }) async {
    if (wrongPin) throw const SensorBleException(SensorBleError.wrongPin);
    final info = infos[connects < infos.length ? connects : infos.length - 1];
    connects++;
    return _Session(this, info);
  }
}

class _Sensors implements SensorRepository {
  final linked = <String>[];
  LeafieApiException? claimError;

  @override
  Future<SensorDeviceData> registerDevice(String deviceId) async =>
      SensorDeviceData.fromJson({'deviceId': deviceId, 'status': 'UNCLAIMED'});

  @override
  Future<String> createClaim(String deviceId) async {
    if (claimError != null) throw claimError!;
    return 'token';
  }

  @override
  Future<SensorDeviceClaimStatus> getClaimStatus(String claimToken) async =>
      SensorDeviceClaimStatus.completed;

  @override
  Future<List<SensorDeviceListItem>> listDevices() async => [
    SensorDeviceListItem.fromJson({
      'deviceId': 'AAAAAAAA0001',
      'status': 'CLAIMED',
      'lastSeenAt': null,
      'plantId': 'plant-2',
      'lux': null,
      'soilPercent': null,
      'measuredAt': null,
    }),
  ];

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
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ManagedPlant _plant(String id, String nickname) => ManagedPlant(
  id: id,
  nickname: nickname,
  speciesReferenceId: 'species',
  speciesDisplayName: '몬스테라',
  primaryPhotoUrl: null,
  personalityType: 'CALM',
  colorId: 'yellow',
  hairId: 'hair_sprout',
  startedOn: DateTime(2026, 9, 1),
);

class _Plants implements PlantManagementRepository {
  @override
  Future<List<ManagedPlant>> listPlants() async => [
    _plant('plant-1', '새싹이'),
    _plant('plant-2', '무럭이'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

SensorDeviceInfo _info(SensorDeviceBleState state, {bool token = false}) =>
    SensorDeviceInfo(deviceId: _id, state: state, hasDeviceToken: token);

void main() {
  late _Ble ble;
  late _Sensors sensors;
  late SensorPairing pairing;
  bool? popped;

  setUp(() {
    ble = _Ble();
    sensors = _Sensors();
    pairing = SensorPairing(ble: ble, repository: sensors, timings: _timings);
    popped = null;
  });

  tearDown(() => pairing.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => SensorPairingScreen(
                    pairing: pairing,
                    sensorRepository: sensors,
                    plantRepository: _Plants(),
                    registeredHold: Duration.zero,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await pairing.start();
    await tester.pump();
  }

  /// 페이크 타이머와 비동기 작업을 조금씩 흘려보낸다. 흐름 일부가 테스트의
  /// 가짜 시계 밖(실제 이벤트 루프)에서 이어지므로 실제 시간도 잠깐씩 준다.
  Future<void> run(WidgetTester tester, [int steps = 30]) async {
    for (var i = 0; i < steps; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('찾은 기기를 ID 끝 4자리 이름과 신호 세기로 보여 준다', (tester) async {
    await open(tester);
    expect(find.text('주변 기기를 찾고 있어요'), findsOneWidget);
    expect(find.text('Leafie D168'), findsOneWidget);
    expect(find.text('신호세기: 강함'), findsOneWidget);
    await run(tester, 15);
    expect(find.text('연결할 기기를 선택하세요'), findsOneWidget);
  });

  testWidgets('PIN 8자리를 넣어야 맞아요를 누를 수 있고 LED 버튼은 없다', (tester) async {
    await open(tester);
    await tester.tap(find.text('Leafie D168'));
    await tester.pump();
    expect(find.text('이 기기가 맞나요?'), findsOneWidget);
    expect(find.text('기기번호 $_id'), findsOneWidget);
    expect(find.text('LED 깜빡이기'), findsNothing);

    ElevatedButton confirm() => tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('sensor_confirm')),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.enterText(find.byType(TextField), '1234abc');
    await tester.pump();
    expect(confirm().onPressed, isNull);
    await tester.enterText(find.byType(TextField), '482019379');
    await tester.pump();
    // 숫자만, 8자리까지만 들어간다
    expect(confirm().onPressed, isNotNull);
  });

  testWidgets('PIN이 틀리면 다시 입력받는다', (tester) async {
    ble.wrongPin = true;
    await open(tester);
    await tester.tap(find.text('Leafie D168'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '48201937');
    await tester.pump();
    await tester.tap(find.text('맞아요'));
    await run(tester, 5);
    expect(find.text('PIN이 맞지 않아요. 라벨을 다시 확인해주세요.'), findsOneWidget);
  });

  testWidgets('처음 등록: Wi-Fi 목록에서 고르고 식물까지 연결한다', (tester) async {
    ble.infos = [
      _info(SensorDeviceBleState.provisioning),
      _info(SensorDeviceBleState.waitingClaim),
    ];
    await open(tester);
    await tester.tap(find.text('Leafie D168'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '48201937');
    await tester.pump();
    await tester.tap(find.text('맞아요'));
    await run(tester, 5);

    expect(find.text('WI-FI 연결'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sensor_ssid_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sensor_wifi_Home_2.4G')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('sensor_wifi_password')),
        matching: find.byType(TextField),
      ),
      'pw',
    );
    await tester.pump();
    await tester.tap(find.text('연결'));
    await run(tester);
    expect(ble.sentWifi, ['Home_2.4G/pw']);

    expect(find.text('기기 등록 완료'), findsOneWidget);
    expect(find.text('Home_2.4G'), findsOneWidget);
    await tester.tap(find.text('완료'));
    await run(tester, 5);

    expect(find.text('연결할 식물 선택'), findsOneWidget);
    expect(find.text('Leafie 0001에 연결됨'), findsOneWidget);
    await tester.tap(find.text('새싹이'));
    await tester.pump();
    await tester.tap(find.text('완료'));
    await run(tester, 10);
    await tester.pumpAndSettle();
    expect(sensors.linked, ['plant-1:$_id']);
    expect(popped, isTrue);
  });

  testWidgets('Wi-Fi 비밀번호가 틀리면 실패 화면 뒤 다시 입력받는다', (tester) async {
    ble.infos = [_info(SensorDeviceBleState.provisioning)];
    ble.wifiStatuses = [SensorWifiStatus.authError];
    await open(tester);
    await tester.tap(find.text('Leafie D168'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '48201937');
    await tester.pump();
    await tester.tap(find.text('맞아요'));
    await run(tester, 5);
    await tester.tap(find.byKey(const ValueKey('sensor_ssid_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sensor_wifi_Home_2.4G')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('연결'));
    await run(tester, 10);

    expect(find.text('WI-FI 연결에 실패했어요'), findsOneWidget);
    expect(find.text('비밀번호가 올바른지 확인해주세요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(find.text('WI-FI 연결'), findsOneWidget);
  });

  testWidgets('이미 다른 사람이 등록한 기기면 초기화 방법을 안내한다', (tester) async {
    ble.infos = [_info(SensorDeviceBleState.waitingClaim)];
    sensors.claimError = const LeafieApiException(
      code: 'CONFLICT',
      message: 'conflict',
      statusCode: 409,
    );
    await open(tester);
    await tester.tap(find.text('Leafie D168'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '48201937');
    await tester.pump();
    await tester.tap(find.text('맞아요'));
    await run(tester, 10);
    expect(find.text('이미 등록된 기기예요'), findsOneWidget);
    expect(find.text('기존 사용자가 앱에서 기기를 삭제해야 해요.'), findsOneWidget);
  });
}
