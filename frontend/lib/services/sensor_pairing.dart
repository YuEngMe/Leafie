import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/sensor_api.dart';
import 'package:yeso_plant/services/sensor_ble.dart';

// 센서 기기 등록 흐름의 판단을 모두 여기서 한다. 화면은 [SensorPairing.state]를
// 그리고 사용자 입력을 메서드로 넘기기만 한다.
// 기준: 펌웨어 레포 docs/app-ble-guide.md 3절(device-info 분기)·5절(claim 판단표).
//
// 1. 기기 검색 → 선택 → PIN → 세션 → device-info
// 2. state == PROVISIONING 이면 Wi-Fi 입력 → 전송 → 상태 확인
//    (hasDeviceToken == true 면 Wi-Fi만 받고 끝난다)
// 3. claim: 서버에서 토큰 발급 → 연결 끊고 다시 찾기 → 토큰 전송
//    → 서버 상태 폴링과 BLE 재광고 감시를 함께 한다
// 4. 성공하면 식물을 고른다

class SensorPairingTimings {
  const SensorPairingTimings({
    this.scan = const Duration(seconds: 30),
    this.rescanAttempts = 3,
    this.wifiStatusInterval = const Duration(seconds: 1),
    this.wifiConnect = const Duration(seconds: 30),
    this.claimPollInterval = const Duration(seconds: 3),
    this.claimWait = const Duration(minutes: 2),
    this.bleSettle = const Duration(seconds: 3),
  });

  /// 기기 검색 한 번의 길이. 실측 전 추정치(센서 담당 권장 약 30초).
  final Duration scan;

  /// Wi-Fi 연결 뒤 같은 기기를 다시 찾을 때 검색을 반복하는 횟수.
  final int rescanAttempts;
  final Duration wifiStatusInterval;
  final Duration wifiConnect;
  final Duration claimPollInterval;

  /// 기기는 최대 6번, 약 90초 동안 claim을 시도한다. 앱은 약 2분 기다린다.
  final Duration claimWait;

  /// 기기가 BLE를 정리(stop → wait → deinit)하는 동안 남은 광고를 무시하는 시간.
  /// Wi-Fi 성공 뒤 다시 찾기 전, 토큰을 보낸 뒤 재광고 감시를 시작하기 전에 기다린다.
  /// 실측 전 추정치.
  final Duration bleSettle;
}

/// 같은 기기에서 claim이 이만큼 연속 실패하면 Wi-Fi가 바뀌었을 수 있다고 안내한다.
const sensorClaimFailuresBeforeWifiHint = 3;

sealed class SensorPairingState {
  const SensorPairingState();
}

class SensorPairingIdle extends SensorPairingState {
  const SensorPairingIdle();
}

class SensorPairingBluetoothUnavailable extends SensorPairingState {
  const SensorPairingBluetoothUnavailable(this.availability);
  final SensorBleAvailability availability;
}

class SensorPairingScanning extends SensorPairingState {
  const SensorPairingScanning(this.devices, {required this.done});
  final List<SensorBleDevice> devices;

  /// 검색 시간이 끝났다. 목록이 비었으면 "기기를 찾지 못했어요".
  final bool done;
}

class SensorPairingNeedPin extends SensorPairingState {
  const SensorPairingNeedPin(this.device, {this.wrongPin = false});
  final SensorBleDevice device;
  final bool wrongPin;
}

class SensorPairingConnecting extends SensorPairingState {
  const SensorPairingConnecting(this.device);
  final SensorBleDevice device;
}

class SensorPairingWifiInput extends SensorPairingState {
  const SensorPairingWifiInput(this.networks, {this.lastFailure});

  /// 기기가 스캔한 2.4GHz 목록. 비어 있으면 직접 입력만 보여 준다.
  final List<SensorWifiNetwork> networks;

  /// 직전 시도가 실패한 이유(authError·networkNotFound·failed).
  final SensorWifiStatus? lastFailure;
}

class SensorPairingWifiConnecting extends SensorPairingState {
  const SensorPairingWifiConnecting();
}

enum SensorClaimStage {
  /// 서버에 기기 등록·토큰 발급
  preparing,

  /// Wi-Fi 연결 뒤 다시 켜진 기기를 찾는 중
  reconnecting,
  sending,

  /// 기기가 서버에 등록하는 중(최대 약 2분)
  waitingServer,
}

class SensorPairingClaiming extends SensorPairingState {
  const SensorPairingClaiming(this.stage);
  final SensorClaimStage stage;
}

enum SensorClaimFailure {
  /// Wi-Fi 연결 뒤 기기를 다시 찾지 못했다.
  deviceNotFound,

  /// 기기가 서버 등록을 끝내지 못했다.
  notCompleted,
}

class SensorPairingClaimFailed extends SensorPairingState {
  const SensorPairingClaimFailed(
    this.failure, {
    required this.suggestWifiReset,
  });
  final SensorClaimFailure failure;

  /// 연속 실패가 쌓였다. "기기 버튼을 3초 눌러 Wi-Fi를 다시 설정하세요".
  final bool suggestWifiReset;
}

/// 서버가 claim을 409로 거절했다. 이미 등록된 기기다.
class SensorPairingAlreadyClaimed extends SensorPairingState {
  const SensorPairingAlreadyClaimed({required this.ownedByMe});

  /// true: 내 계정에 등록돼 있다(기기 관리에서 삭제 후 10초 초기화).
  /// false: 다른 계정 소유다(기존 주인이 삭제한 뒤 10초 초기화).
  final bool ownedByMe;
}

class SensorPairingChoosePlant extends SensorPairingState {
  const SensorPairingChoosePlant(this.deviceId);
  final String deviceId;
}

class SensorPairingDone extends SensorPairingState {
  const SensorPairingDone(this.deviceId, {this.plantId, this.wifiOnly = false});
  final String deviceId;
  final String? plantId;

  /// 버튼 3초로 Wi-Fi만 다시 설정한 기기였다.
  final bool wifiOnly;
}

/// 다시 시도할 수 있는 오류. [SensorPairing.retry]는 마지막 단계부터 다시 한다.
class SensorPairingError extends SensorPairingState {
  const SensorPairingError(this.error);

  /// [SensorBleException]이나 [LeafieApiException].
  final Object error;
}

enum _Resume { scan, connect, wifi, claim, plant }

class SensorPairing extends ChangeNotifier {
  SensorPairing({
    required SensorBle ble,
    required SensorRepository repository,
    this.timings = const SensorPairingTimings(),
  }) : _ble = ble,
       _repository = repository;

  final SensorBle _ble;
  final SensorRepository _repository;
  final SensorPairingTimings timings;

  SensorPairingState _state = const SensorPairingIdle();
  SensorPairingState get state => _state;

  SensorBleDevice? _device;
  String? _pin;
  SensorBleSession? _session;
  SensorDeviceInfo? _info;
  int _claimFailures = 0;
  _Resume _resume = _Resume.scan;
  String? _pendingPlantId;
  List<SensorWifiNetwork> _networks = const [];

  /// 이번 흐름에서 토큰을 기기에 보낸 적이 있다. 그 뒤 409는 내 claim이 이미
  /// 끝났다는 뜻일 수 있다.
  bool _tokenSent = false;

  /// 진행 중인 모든 검색. 흐름이 바뀌면 함께 멈춘다.
  final _scans = <StreamSubscription<List<SensorBleDevice>>>{};
  final _waiters = <Completer<SensorBleDevice?>>{};

  /// 진행 중인 비동기 작업이 취소됐는지 가리는 번호. 바뀌면 이전 작업은 상태를 쓰지 않는다.
  int _run = 0;
  bool _disposed = false;

  void _emit(int run, SensorPairingState next) {
    if (run != _run || _disposed) return;
    _state = next;
    notifyListeners();
  }

  bool _alive(int run) => run == _run && !_disposed;

  int _restart() {
    _run++;
    for (final scan in _scans) {
      scan.cancel();
    }
    _scans.clear();
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) waiter.complete(null);
    }
    _waiters.clear();
    return _run;
  }

  /// 블루투스 상태를 확인하고 기기를 찾는다.
  Future<void> start() async {
    final run = _restart();
    await _closeSession();
    _resume = _Resume.scan;
    final SensorBleAvailability availability;
    try {
      availability = await _ble.availability();
    } catch (e) {
      _emit(run, SensorPairingError(e));
      return;
    }
    if (!_alive(run)) return;
    if (availability != SensorBleAvailability.ready) {
      _emit(run, SensorPairingBluetoothUnavailable(availability));
      return;
    }
    _emit(run, const SensorPairingScanning([], done: false));
    var devices = const <SensorBleDevice>[];
    _listenScan(
      timings.scan,
      (found) {
        devices = found;
        _emit(run, SensorPairingScanning(found, done: false));
      },
      onError: (e) => _emit(run, SensorPairingError(e)),
      onDone: () {
        if (_state is SensorPairingScanning) {
          _emit(run, SensorPairingScanning(devices, done: true));
        }
      },
    );
  }

  void selectDevice(SensorBleDevice device) {
    final run = _restart();
    _device = device;
    _emit(run, SensorPairingNeedPin(device));
  }

  /// PIN 형식은 화면에서 [isValidSensorPin]으로 먼저 거른다.
  Future<void> submitPin(String pin) async {
    final device = _device;
    if (device == null || !isValidSensorPin(pin)) return;
    _pin = pin;
    _claimFailures = 0;
    _tokenSent = false;
    await _connectAndBranch(_restart(), device);
  }

  Future<void> submitWifi({
    required String ssid,
    required String password,
  }) async {
    final run = _restart();
    final session = _session;
    if (session == null) return;
    _resume = _Resume.wifi;
    _emit(run, const SensorPairingWifiConnecting());
    try {
      await session.sendWifi(ssid: ssid, password: password);
    } catch (e) {
      _emit(run, SensorPairingError(e));
      return;
    }
    final status = await _waitWifi(run, session);
    if (!_alive(run)) return;
    switch (status) {
      case SensorWifiStatus.authError ||
          SensorWifiStatus.networkNotFound ||
          SensorWifiStatus.failed:
        // 기기가 실패 상태를 초기화하므로 같은 세션에서 다시 보낸다.
        _emit(run, SensorPairingWifiInput(_networks, lastFailure: status));
      case _:
        await _release(session);
        if (_info?.hasDeviceToken ?? false) {
          _finish(run, SensorPairingDone(session.deviceId, wifiOnly: true));
        } else {
          await Future<void>.delayed(timings.bleSettle);
          if (!_alive(run)) return;
          await _claim(run, afterWifi: true);
        }
    }
  }

  /// [SensorPairingClaimFailed]·[SensorPairingError]에서 다시 시도한다.
  Future<void> retry() async {
    final run = _restart();
    final device = _device;
    switch (_resume) {
      case _Resume.scan:
        await start();
      case _Resume.connect || _Resume.wifi:
        if (device == null) return start();
        await _connectAndBranch(run, device);
      case _Resume.claim:
        await _claim(run);
      case _Resume.plant:
        final plantId = _pendingPlantId;
        if (plantId != null && device != null) await linkPlant(plantId);
    }
  }

  Future<void> linkPlant(String plantId) async {
    final run = _restart();
    final deviceId = _device?.deviceId;
    if (deviceId == null) return;
    _resume = _Resume.plant;
    _pendingPlantId = plantId;
    try {
      await _repository.connectPlantDevice(plantId, deviceId);
    } catch (e) {
      _emit(run, SensorPairingError(e));
      return;
    }
    _finish(run, SensorPairingDone(deviceId, plantId: plantId));
  }

  void skipPlant() {
    final deviceId = _device?.deviceId;
    if (deviceId == null) return;
    _finish(_restart(), SensorPairingDone(deviceId));
  }

  /// 화면을 떠날 때 부른다. 연결을 끊고 진행 중인 작업을 버린다.
  Future<void> cancel() async {
    final run = _restart();
    _pin = null;
    await _closeSession();
    _emit(run, const SensorPairingIdle());
  }

  @override
  void dispose() {
    _disposed = true;
    _restart();
    _pin = null;
    _session?.close();
    _session = null;
    super.dispose();
  }

  /// 흐름이 끝났다. PIN은 세션을 여는 데만 쓰므로 더 들고 있지 않는다.
  void _finish(int run, SensorPairingState done) {
    if (!_alive(run)) return;
    _pin = null;
    _emit(run, done);
  }

  Future<void> _connectAndBranch(int run, SensorBleDevice device) async {
    final pin = _pin;
    if (pin == null) return;
    _resume = _Resume.connect;
    _emit(run, SensorPairingConnecting(device));
    await _closeSession();
    final SensorBleSession session;
    final SensorDeviceInfo info;
    try {
      session = await _open(run, device, pin);
    } on _Stale {
      return;
    } on SensorBleException catch (e) {
      if (e.error == SensorBleError.wrongPin) {
        _pin = null;
        _emit(run, SensorPairingNeedPin(device, wrongPin: true));
      } else {
        _emit(run, SensorPairingError(e));
      }
      return;
    }
    try {
      info = await session.readDeviceInfo();
      _checkDeviceId(info, device);
    } on SensorBleException catch (e) {
      await _release(session);
      _emit(run, SensorPairingError(e));
      return;
    }
    if (!_alive(run)) return;
    _info = info;
    switch (info.state) {
      case SensorDeviceBleState.provisioning:
        await _showWifiInput(run, session);
      case SensorDeviceBleState.waitingClaim:
        await _release(session);
        if (info.hasDeviceToken) {
          // 펌웨어상 나오지 않는 조합. 이미 등록된 기기로 본다.
          _resume = _Resume.plant;
          _emit(run, SensorPairingChoosePlant(device.deviceId));
        } else {
          await _claim(run);
        }
    }
  }

  Future<void> _showWifiInput(
    int run,
    SensorBleSession session, {
    SensorWifiStatus? lastFailure,
  }) async {
    _resume = _Resume.wifi;
    try {
      _networks = await session.scanWifi();
    } on SensorBleException {
      // 목록 없이 직접 입력만 받는다.
      _networks = const [];
    }
    _emit(run, SensorPairingWifiInput(_networks, lastFailure: lastFailure));
  }

  /// 연결되면 기기가 provisioning BLE를 정리하므로 세션이 끊기는 것도 성공 신호로 본다.
  /// 진짜 성공인지는 다음 단계(재검색 후 device-info)에서 확인된다.
  Future<SensorWifiStatus> _waitWifi(int run, SensorBleSession session) async {
    final deadline = DateTime.now().add(timings.wifiConnect);
    while (_alive(run)) {
      final SensorWifiStatus status;
      try {
        status = await session.readWifiStatus();
      } on SensorBleException {
        return SensorWifiStatus.connected;
      }
      if (status != SensorWifiStatus.connecting &&
          status != SensorWifiStatus.disconnected) {
        return status;
      }
      if (DateTime.now().isAfter(deadline)) return SensorWifiStatus.failed;
      await Future<void>.delayed(timings.wifiStatusInterval);
    }
    return SensorWifiStatus.failed;
  }

  /// [afterWifi]: 방금 Wi-Fi를 보냈다. 이때 PROVISIONING이 보이면 기기가 아직
  /// 정리 중일 수 있어 한 번 더 찾아본다.
  Future<void> _claim(int run, {bool afterWifi = false}) async {
    final device = _device;
    final pin = _pin;
    if (device == null || pin == null) return;
    _resume = _Resume.claim;
    final deviceId = device.deviceId;

    _emit(run, const SensorPairingClaiming(SensorClaimStage.preparing));
    final String token;
    try {
      await _repository.registerDevice(deviceId);
      token = await _repository.createClaim(deviceId);
    } on LeafieApiException catch (e) {
      if (e.statusCode == 409) {
        await _handleConflict(run, deviceId);
      } else {
        _emit(run, SensorPairingError(e));
      }
      return;
    } catch (e) {
      _emit(run, SensorPairingError(e));
      return;
    }
    if (!_alive(run)) return;

    SensorBleSession? session;
    for (var attempt = 0; session == null; attempt++) {
      _emit(run, const SensorPairingClaiming(SensorClaimStage.reconnecting));
      final found = await _findDevice(run, deviceId);
      if (!_alive(run)) return;
      if (found == null) {
        _claimFailed(run, SensorClaimFailure.deviceNotFound);
        return;
      }
      _device = found;

      _emit(run, const SensorPairingClaiming(SensorClaimStage.sending));
      final SensorBleSession opened;
      final SensorDeviceInfo info;
      try {
        opened = await _open(run, found, pin);
      } on _Stale {
        return;
      } on SensorBleException catch (e) {
        _emit(run, SensorPairingError(e));
        return;
      }
      try {
        info = await opened.readDeviceInfo();
        _checkDeviceId(info, found);
      } on SensorBleException catch (e) {
        await _release(opened);
        _emit(run, SensorPairingError(e));
        return;
      }
      if (!_alive(run)) return;
      _info = info;
      if (info.state == SensorDeviceBleState.waitingClaim) {
        session = opened;
      } else if (afterWifi && attempt == 0) {
        // 아직 Wi-Fi 설정용 BLE가 정리되기 전이었다. 조금 기다렸다 다시 찾는다.
        await _release(opened);
        await Future<void>.delayed(timings.bleSettle);
        if (!_alive(run)) return;
      } else {
        // Wi-Fi 정보가 지워졌다(Wi-Fi 연결 실패, 5분 규칙, 버튼). Wi-Fi부터 다시.
        await _showWifiInput(
          run,
          opened,
          lastFailure: afterWifi ? SensorWifiStatus.failed : null,
        );
        return;
      }
    }

    try {
      await session.sendClaimToken(token);
    } on SensorBleException {
      // 쓰기는 기기에 닿았는데 기기가 곧바로 BLE를 정리해 응답을 못 읽었을 수 있다.
      // 성공 여부는 어차피 서버 폴링으로만 알 수 있으니 그대로 기다린다.
    }
    _tokenSent = true;
    await _release(session);
    if (!_alive(run)) return;

    _emit(run, const SensorPairingClaiming(SensorClaimStage.waitingServer));
    final outcome = await _waitClaim(run, token, deviceId);
    if (!_alive(run)) return;
    switch (outcome) {
      case _ClaimOutcome.completed:
        _claimSucceeded(run, deviceId);
      case _ClaimOutcome.deviceGaveUp:
        // 기기가 다시 광고한다. 새 토큰으로 곧바로 다시 한다(이전 토큰은 기기가 버렸다).
        _claimFailures++;
        if (_claimFailures >= sensorClaimFailuresBeforeWifiHint) {
          _claimFailed(run, SensorClaimFailure.notCompleted, counted: true);
        } else {
          await _claim(run);
        }
      case _ClaimOutcome.notCompleted:
        _claimFailed(run, SensorClaimFailure.notCompleted);
    }
  }

  void _claimSucceeded(int run, String deviceId) {
    _claimFailures = 0;
    _resume = _Resume.plant;
    _emit(run, SensorPairingChoosePlant(deviceId));
  }

  void _claimFailed(
    int run,
    SensorClaimFailure failure, {
    bool counted = false,
  }) {
    if (!counted) _claimFailures++;
    _emit(
      run,
      SensorPairingClaimFailed(
        failure,
        suggestWifiReset: _claimFailures >= sensorClaimFailuresBeforeWifiHint,
      ),
    );
  }

  /// claim 발급이 409다. 이번 흐름에서 토큰을 보낸 뒤라면 그 claim이 늦게 끝나
  /// 내 기기가 된 것일 수 있다.
  Future<void> _handleConflict(int run, String deviceId) async {
    var ownedByMe = false;
    try {
      final mine = await _repository.listDevices();
      ownedByMe = mine.any((d) => d.deviceId == deviceId);
    } catch (_) {
      // 모르면 다른 사람 소유 안내를 띄운다. 두 안내 모두 버튼 10초 초기화가 들어간다.
    }
    if (!_alive(run)) return;
    if (ownedByMe && _tokenSent) {
      _claimSucceeded(run, deviceId);
      return;
    }
    _finish(run, SensorPairingAlreadyClaimed(ownedByMe: ownedByMe));
  }

  Future<SensorBleDevice?> _findDevice(int run, String deviceId) async {
    for (var i = 0; i < timings.rescanAttempts && _alive(run); i++) {
      final waiter = Completer<SensorBleDevice?>();
      _waiters.add(waiter);
      void settle(SensorBleDevice? device) {
        if (!waiter.isCompleted) waiter.complete(device);
      }

      final scan = _listenScan(
        timings.scan,
        (devices) =>
            settle(devices.where((d) => d.deviceId == deviceId).firstOrNull),
        onError: (_) => settle(null),
        onDone: () => settle(null),
      );
      final match = await waiter.future;
      _waiters.remove(waiter);
      await _stopScan(scan);
      if (match != null) return match;
    }
    return null;
  }

  /// 서버 상태와 BLE 재광고를 함께 본다(가이드 5절 판단표).
  /// COMPLETED → 성공. 방송이 다시 보이면 기기가 포기한 것. 둘 다 없이 시간이 지나면 실패.
  /// 토큰을 받은 기기가 BLE를 정리하는 동안 남은 광고를 포기로 오판하지 않도록
  /// [SensorPairingTimings.bleSettle]이 지난 뒤부터 감시한다.
  Future<_ClaimOutcome> _waitClaim(
    int run,
    String token,
    String deviceId,
  ) async {
    final deadline = DateTime.now().add(timings.claimWait);
    var reappeared = false;
    StreamSubscription<List<SensorBleDevice>>? watch;
    final watchFrom = DateTime.now().add(timings.bleSettle);
    try {
      while (_alive(run)) {
        if (watch == null && !DateTime.now().isBefore(watchFrom)) {
          watch = _listenScan(timings.claimWait, (devices) {
            if (devices.any((d) => d.deviceId == deviceId)) reappeared = true;
          });
        }
        try {
          final status = await _repository.getClaimStatus(token);
          switch (status) {
            case SensorDeviceClaimStatus.completed:
              return _ClaimOutcome.completed;
            case SensorDeviceClaimStatus.expired ||
                SensorDeviceClaimStatus.cancelled:
              return reappeared
                  ? _ClaimOutcome.deviceGaveUp
                  : _ClaimOutcome.notCompleted;
            case SensorDeviceClaimStatus.pending:
              break;
          }
        } on LeafieApiException {
          // 일시적인 서버 오류는 다음 폴링에서 다시 본다.
        }
        if (reappeared) return _ClaimOutcome.deviceGaveUp;
        if (DateTime.now().isAfter(deadline)) return _ClaimOutcome.notCompleted;
        await Future<void>.delayed(timings.claimPollInterval);
      }
      return _ClaimOutcome.notCompleted;
    } finally {
      if (watch != null) await _stopScan(watch);
    }
  }

  StreamSubscription<List<SensorBleDevice>> _listenScan(
    Duration timeout,
    void Function(List<SensorBleDevice>) onDevices, {
    void Function(Object error)? onError,
    void Function()? onDone,
  }) {
    late final StreamSubscription<List<SensorBleDevice>> scan;
    scan = _ble
        .scan(timeout: timeout)
        .listen(
          onDevices,
          onError: (Object e) => onError?.call(e),
          onDone: () {
            _scans.remove(scan);
            onDone?.call();
          },
        );
    _scans.add(scan);
    return scan;
  }

  Future<void> _stopScan(StreamSubscription<List<SensorBleDevice>> scan) {
    _scans.remove(scan);
    return scan.cancel();
  }

  /// 세션을 열고 현재 세션으로 둔다. 그 사이 흐름이 바뀌었으면 닫고 [_Stale].
  Future<SensorBleSession> _open(
    int run,
    SensorBleDevice device,
    String pin,
  ) async {
    final session = await _ble.connect(device, pin: pin);
    if (!_alive(run)) {
      await session.close();
      throw const _Stale();
    }
    _session = session;
    return session;
  }

  /// 이 흐름이 연 세션만 닫는다. 그 사이 새 흐름이 연 세션은 건드리지 않는다.
  Future<void> _release(SensorBleSession session) async {
    if (identical(_session, session)) _session = null;
    await session.close();
  }

  void _checkDeviceId(SensorDeviceInfo info, SensorBleDevice device) {
    if (info.deviceId != device.deviceId) {
      throw const SensorBleException(
        SensorBleError.protocol,
        'device-info deviceId mismatch',
      );
    }
  }

  Future<void> _closeSession() async {
    final session = _session;
    _session = null;
    await session?.close();
  }
}

enum _ClaimOutcome { completed, deviceGaveUp, notCompleted }

class _Stale implements Exception {
  const _Stale();
}
