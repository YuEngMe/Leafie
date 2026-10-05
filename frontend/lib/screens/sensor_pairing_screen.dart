import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yeso_plant/services/esp_sensor_ble.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/services/sensor_api.dart';
import 'package:yeso_plant/services/sensor_ble.dart';
import 'package:yeso_plant/services/sensor_pairing.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';
import 'package:yeso_plant/widgets/sensor_pairing_components.dart';

/// 센서 기기 등록(Figma 섹션 "기기연결" 5732:849).
///
/// 흐름 판단은 [SensorPairing]이 하고, 이 화면은 그 상태를 시안 프레임에
/// 맞춰 그린다. 시안의 "LED 깜빡이기"는 펌웨어에 기능이 없어 빼고,
/// "현재 Wi-Fi 사용"(4-2)은 iOS가 폰의 Wi-Fi 이름을 주지 않아 기기가 찾은
/// 목록 바텀시트로 대신한다(2026-10-05 사용자 결정).
///
/// 등록이 끝나면 `true`로 닫힌다.
class SensorPairingScreen extends StatefulWidget {
  const SensorPairingScreen({
    super.key,
    this.pairing,
    this.sensorRepository,
    this.plantRepository,
    this.registeredHold = const Duration(milliseconds: 1200),
  });

  /// 테스트에서 페이크 BLE로 만든 흐름을 넣는다. 넣으면 화면이 dispose하지 않는다.
  final SensorPairing? pairing;
  final SensorRepository? sensorRepository;
  final PlantManagementRepository? plantRepository;

  /// 서버 등록이 끝난 진행 목록(14)을 완료 화면(15) 전에 보여 주는 시간.
  final Duration registeredHold;

  @override
  State<SensorPairingScreen> createState() => _SensorPairingScreenState();
}

enum _Page { flow, registered, done, choosePlant }

class _SensorPairingScreenState extends State<SensorPairingScreen> {
  late final SensorRepository _sensors = widget.sensorRepository ?? SensorApi();
  late final SensorPairing _pairing =
      widget.pairing ??
      SensorPairing(ble: EspSensorBle(), repository: _sensors);
  late final PlantManagementRepository _plants =
      widget.plantRepository ?? PlantManagementApi();

  final _pin = TextEditingController();
  final _ssid = TextEditingController();
  final _password = TextEditingController();

  /// Wi-Fi 이름을 목록에서 고르지 않고 직접 입력한다.
  bool _manualSsid = false;

  /// 6-1에서 '다시 시도'를 눌렀다. 같은 실패를 다시 보여 주지 않는다.
  SensorPairingWifiInput? _dismissedFailure;

  /// 이번 흐름에서 보낸 Wi-Fi 이름. 완료 화면(15)에 보여 준다.
  String? _sentSsid;
  bool _wifiSent = false;

  _Page _page = _Page.flow;
  Timer? _registeredTimer;

  List<ManagedPlant>? _plantList;
  Map<String, String> _deviceByPlant = const {};
  String? _selectedPlantId;
  Object? _plantError;

  @override
  void initState() {
    super.initState();
    _pairing.addListener(_onPairingChanged);
    _pin.addListener(_rebuild);
    _ssid.addListener(_rebuild);
    if (widget.pairing == null) _pairing.start();
  }

  @override
  void dispose() {
    _registeredTimer?.cancel();
    _pairing.removeListener(_onPairingChanged);
    if (widget.pairing == null) _pairing.dispose();
    _pin.dispose();
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onPairingChanged() {
    if (!mounted) return;
    final state = _pairing.state;
    if (state is SensorPairingChoosePlant && _page == _Page.flow) {
      _page = _Page.registered;
      _registeredTimer = Timer(widget.registeredHold, () {
        if (mounted) setState(() => _page = _Page.done);
      });
    } else if (state is SensorPairingDone) {
      if (state.wifiOnly) {
        _page = _Page.done;
      } else {
        Navigator.of(context).pop(true);
        return;
      }
    } else if (state is SensorPairingNeedPin && state.wrongPin) {
      _pin.clear();
    }
    setState(() {});
  }

  // ---- 동작 ----

  void _selectDevice(SensorBleDevice device) {
    _pin.clear();
    _pairing.selectDevice(device);
  }

  void _submitPin() {
    FocusScope.of(context).unfocus();
    _wifiSent = false;
    _sentSsid = null;
    _pairing.submitPin(_pin.text);
  }

  void _submitWifi() {
    FocusScope.of(context).unfocus();
    _sentSsid = _ssid.text;
    _wifiSent = true;
    _pairing.submitWifi(ssid: _ssid.text, password: _password.text);
  }

  Future<void> _pickNetwork(List<SensorWifiNetwork> networks) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: kModalBarrier,
      builder: (_) => _WifiListSheet(networks: networks),
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (picked == _WifiListSheet.manual) {
        _manualSsid = true;
        _ssid.clear();
      } else {
        _manualSsid = false;
        _ssid.text = picked;
      }
    });
  }

  Future<void> _openPlantPicker() async {
    setState(() {
      _page = _Page.choosePlant;
      _plantError = null;
    });
    try {
      final results = await Future.wait([
        _plants.listPlants(),
        _sensors.listDevices(),
      ]);
      if (!mounted) return;
      final plants = results[0] as List<ManagedPlant>;
      final devices = results[1] as List<SensorDeviceListItem>;
      setState(() {
        _plantList = plants;
        _deviceByPlant = {
          for (final device in devices)
            if (device.plantId != null) device.plantId!: device.deviceId,
        };
      });
    } on LeafieApiException catch (error) {
      if (mounted) setState(() => _plantError = error);
    }
  }

  void _finishWithoutPlant() {
    final state = _pairing.state;
    if (state is SensorPairingDone) {
      Navigator.of(context).pop(true);
    } else {
      _pairing.skipPlant();
    }
  }

  // ---- 화면 ----

  @override
  Widget build(BuildContext context) {
    return switch (_page) {
      _Page.registered => _progress(registered: true),
      _Page.done => _done(),
      _Page.choosePlant => _choosePlant(),
      _Page.flow => _flow(_pairing.state),
    };
  }

  Widget _flow(SensorPairingState state) {
    return switch (state) {
      SensorPairingIdle() => _scanning(const [], done: false),
      SensorPairingBluetoothUnavailable(:final availability) => _bluetooth(
        availability,
      ),
      SensorPairingScanning(:final devices, :final done) =>
        done && devices.isEmpty ? _notFound() : _scanning(devices, done: done),
      SensorPairingNeedPin(:final device, :final wrongPin) => _confirmDevice(
        device,
        wrongPin: wrongPin,
      ),
      SensorPairingConnecting() => _progress(),
      SensorPairingWifiInput(:final lastFailure)
          when lastFailure != null && !identical(state, _dismissedFailure) =>
        _wifiFailed(state),
      SensorPairingWifiInput(:final networks) => _wifiForm(networks),
      SensorPairingWifiConnecting() => _progress(),
      SensorPairingClaiming() => _progress(),
      SensorPairingClaimFailed(:final failure, :final suggestWifiReset) =>
        failure == SensorClaimFailure.deviceNotFound
            ? _lostDevice(suggestWifiReset)
            : _serverFailed(suggestWifiReset),
      SensorPairingAlreadyClaimed(:final ownedByMe) => _alreadyClaimed(
        ownedByMe,
      ),
      SensorPairingChoosePlant() => _progress(registered: true),
      SensorPairingDone() => _done(),
      SensorPairingError(:final error) => _error(error),
    };
  }

  /// 1 1 (4534:21005) 주변 기기를 찾고 있어요.
  Widget _scanning(List<SensorBleDevice> devices, {required bool done}) {
    return SensorStepScaffold(
      title: '주변 기기를 찾고 있어요',
      subtitle: done ? '연결할 기기를 선택하세요' : '검색 중...',
      subtitleStyle: kSensorHintStyle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SensorBodyGap(),
          for (final (index, device) in devices.indexed) ...[
            if (index > 0) const SizedBox(height: 15),
            SensorDeviceRow(
              key: ValueKey('sensor_device_${device.deviceId}'),
              device: device,
              trailing: sensorSignalLabel(device.rssi),
              onTap: () => _selectDevice(device),
            ),
          ],
        ],
      ),
      bottom: _primary('다시 검색', _pairing.start),
    );
  }

  /// 11 (4534:21039) 기기를 찾지 못했어요.
  Widget _notFound() {
    return SensorStepScaffold(
      title: '기기를 찾지 못했어요',
      subtitle: '다시 시도하세요',
      subtitleStyle: kSensorHintStyle,
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SensorBodyGap(),
          SensorTipBox(
            tips: [
              '센서 전원이 켜져 있는지 확인해주세요.',
              '스마트폰과 센서를 가까이 두세요.',
              // Wi-Fi 정보는 있는데 공유기에 못 붙은 기기는 BLE를 켜지 않는다.
              '공유기를 바꿨다면 기기 버튼을 3초 눌렀다 떼주세요.',
            ],
          ),
        ],
      ),
      bottom: _primary('다시 검색', _pairing.start),
    );
  }

  /// 블루투스가 꺼졌거나 권한이 없다. 시안이 없어 11의 구성을 쓴다.
  Widget _bluetooth(SensorBleAvailability availability) {
    final (title, tip) = switch (availability) {
      SensorBleAvailability.unauthorized => (
        '블루투스 권한이 필요해요',
        '설정 > Leafie에서 블루투스를 허용해주세요.',
      ),
      SensorBleAvailability.unsupported => (
        '블루투스를 쓸 수 없어요',
        '이 기기에서는 블루투스를 지원하지 않아요.',
      ),
      _ => ('블루투스를 켜주세요', '설정 > Bluetooth를 켜주세요.'),
    };
    return SensorStepScaffold(
      title: title,
      subtitle: '센서와 연결하려면 블루투스가 필요해요',
      subtitleStyle: kSensorHintStyle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SensorBodyGap(),
          SensorTipBox(tips: [tip]),
        ],
      ),
      bottom: _primary('다시 시도', _pairing.start),
    );
  }

  /// 20·19 (5728:5849 / 5728:5711) 이 기기가 맞나요? + 기기 PIN.
  Widget _confirmDevice(SensorBleDevice device, {required bool wrongPin}) {
    final ready = isValidSensorPin(_pin.text);
    return SensorStepScaffold(
      title: '이 기기가 맞나요?',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SensorBodyGap(hasSubtitle: false),
          SensorDeviceRow(device: device, trailing: '기기번호 ${device.deviceId}'),
          // 기기 행 bottom 288 → 라벨 top 303.
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: RoundedInputField(
              key: const ValueKey('sensor_pin'),
              label: '기기 PIN',
              labelColor: kOrangeMain,
              // 라벨 top 303 → 칸 top 330(라벨 상자 23 + 4).
              labelGap: 4,
              controller: _pin,
              hintText: '기기 라벨의 숫자 8자리를 입력하세요.',
              obscureText: true,
              obscuringCharacter: '●',
              textStyle: _kMaskedStyle,
              height: 51,
              errorText: wrongPin ? 'PIN이 맞지 않아요. 라벨을 다시 확인해주세요.' : null,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => ready ? _submitPin() : null,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
      bottom: _pairButtons(
        primaryLabel: '맞아요',
        onPrimary: ready ? _submitPin : null,
        secondaryLabel: '다른 기기 선택',
        onSecondary: _pairing.start,
      ),
    );
  }

  /// 12 (4534:21073) Wi-Fi 연결.
  Widget _wifiForm(List<SensorWifiNetwork> networks) {
    return SensorStepScaffold(
      title: 'WI-FI 연결',
      subtitle: '센서가 데이터를 전송할 Wi-Fi를 입력해주세요',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SensorBodyGap(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: RoundedInputField(
              key: const ValueKey('sensor_ssid'),
              label: 'Wi-Fi',
              labelColor: kOrange,
              controller: _ssid,
              hintText: _manualSsid ? 'Wi-Fi 이름을 입력하세요' : 'Wi-Fi를 선택하세요',
              readOnly: !_manualSsid,
              onTap: _manualSsid ? null : () => _pickNetwork(networks),
              height: 51,
              // 라벨 top 237 → 칸 top 261. Flutter 라벨 상자가 23이라 1만 띄운다.
              labelGap: 1,
              overlaySuffix: true,
              // 단추 오른쪽 끝이 칸 오른쪽에서 26 안쪽(x282 + 26 = 308)이다.
              // overlaySuffix가 이미 10을 띄운다.
              suffix: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  key: const ValueKey('sensor_ssid_dropdown'),
                  onTap: () => _pickNetwork(networks),
                  child: const SensorDropdownButton(),
                ),
              ),
            ),
          ),
          // Wi-Fi 칸 bottom 312 → 라벨 top 327.
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: RoundedInputField(
              key: const ValueKey('sensor_wifi_password'),
              label: '비밀번호',
              // 라벨 top 327 → 칸 top 354(라벨 상자 23 + 4).
              labelGap: 4,
              controller: _password,
              hintText: '비밀번호를 입력하세요',
              obscureText: true,
              obscuringCharacter: '●',
              textStyle: _kMaskedStyle,
              height: 51,
              textInputAction: TextInputAction.done,
            ),
          ),
          // 비밀번호 칸 bottom 405 → 안내 top 427.
          const SizedBox(height: 22),
          const _WifiNotice(),
        ],
      ),
      bottom: _primary('연결', _ssid.text.isEmpty ? null : _submitWifi),
    );
  }

  /// 6-1 (4534:21257) Wi-Fi 연결에 실패했어요.
  Widget _wifiFailed(SensorPairingWifiInput state) {
    final subtitle = switch (state.lastFailure) {
      SensorWifiStatus.networkNotFound => 'Wi-Fi를 찾지 못했어요. 이름을 확인해주세요.',
      SensorWifiStatus.authError => '비밀번호가 올바른지 확인해주세요.',
      _ => '공유기가 2.4GHz인지, 비밀번호가 맞는지 확인해주세요.',
    };
    return SensorStepScaffold(
      title: 'WI-FI 연결에 실패했어요',
      subtitle: subtitle,
      subtitleStyle: kSensorHintStyle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SensorBodyGap(),
          const SensorFieldLabel('Wi-Fi', color: kOrange),
          SensorPillRow(
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _sentSsid ?? '',
                  style: kSmallStyle.copyWith(
                    color: kTextDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottom: _primary('다시 시도', () {
        _password.clear();
        setState(() => _dismissedFailure = state);
      }),
    );
  }

  /// 13 (4534:21156) 진행 중, 14 (4534:21208) 서버 등록 완료.
  Widget _progress({bool registered = false}) {
    final state = _pairing.state;
    final stage = switch (state) {
      _ when registered => 4,
      SensorPairingConnecting() => 0,
      SensorPairingWifiConnecting() => 2,
      SensorPairingClaiming() => 3,
      _ => 0,
    };
    SensorStepMark mark(int index) => index < stage
        ? SensorStepMark.done
        : index == stage
        ? SensorStepMark.current
        : SensorStepMark.pending;
    final steps = [
      ('센서에 연결됨', mark(0)),
      ('Wi-Fi 정보 전달', mark(1)),
      (stage > 2 ? 'Wi-Fi 연결 됨' : 'Wi-Fi 연결 중..', mark(2)),
      (registered ? '서버 등록 완료' : '서버 등록', mark(3)),
      if (!registered) ('설정 완료', mark(4)),
    ];
    return SensorStepScaffold(
      title: '기기를 설정하고 있어요',
      subtitle: '잠시만 기다려주세요.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 진행 목록은 top 234로 다른 본문보다 3 위다.
          const SensorBodyGap(),
          Transform.translate(
            offset: const Offset(0, -3),
            child: SensorProgressList(steps: steps),
          ),
          if (state is SensorPairingClaiming &&
              state.stage == SensorClaimStage.waitingServer) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 45),
              child: Text('서버 등록은 최대 2분 정도 걸려요.', style: kSensorHintStyle),
            ),
          ],
        ],
      ),
    );
  }

  /// 15 (4534:21312) 기기 등록 완료.
  Widget _done() {
    final wifiOnly = _pairing.state is SensorPairingDone;
    return SensorStepScaffold(
      title: wifiOnly ? 'Wi-Fi 설정 완료' : '기기 등록 완료',
      subtitle: wifiOnly
          ? 'Leafie가 새 Wi-Fi로 다시 연결돼요.'
          : 'Leafie가 정상적으로 등록 되었습니다.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SensorBodyGap(),
          if (_wifiSent && _sentSsid != null) ...[
            const SensorFieldLabel('Wi-Fi', color: kOrange),
            SensorPillRow(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sentSsid!,
                        style: kSmallStyle.copyWith(
                          color: kTextDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Text('상태: 정상', style: kCaptionStyle),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      bottom: _primary(
        '완료',
        wifiOnly ? () => Navigator.of(context).pop(true) : _openPlantPicker,
      ),
    );
  }

  /// 17 (4534:21416) 연결할 식물 선택.
  Widget _choosePlant() {
    final deviceId = (_pairing.state is SensorPairingChoosePlant)
        ? (_pairing.state as SensorPairingChoosePlant).deviceId
        : null;
    final plants = _plantList;
    final failed = _pairing.state is SensorPairingError;
    Widget body;
    if (_plantError != null) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(45, 24, 45, 0),
        child: Text('식물 목록을 불러오지 못했어요.', style: kSensorHintStyle),
      );
    } else if (plants == null) {
      body = const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator(color: kOrangeMain)),
      );
    } else if (plants.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.fromLTRB(45, 24, 45, 0),
        child: Text('아직 등록한 식물이 없어요.', style: kSensorHintStyle),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, plant) in plants.indexed) ...[
            if (index > 0) const SizedBox(height: 15),
            SensorPlantRow(
              key: ValueKey('sensor_plant_${plant.id}'),
              nickname: plant.nickname,
              selected: plant.id == _selectedPlantId,
              connectedLabel: switch (_deviceByPlant[plant.id]) {
                final id? => '${sensorDeviceName(id)}에 연결됨',
                null => null,
              },
              onTap: () => setState(() => _selectedPlantId = plant.id),
              character: PlantCharacterArt(
                width: 25,
                body: plantBodyFromId(plant.bodyId),
                colorId: plant.colorId,
                hairId: plant.hairId,
              ),
            ),
          ],
        ],
      );
    }
    final selected = _selectedPlantId;
    return SensorStepScaffold(
      appBarTitle: '식물 연결',
      title: '연결할 식물 선택',
      subtitle: deviceId == null
          ? '기기와 연결할 식물을 선택하세요.'
          : '${sensorDeviceName(deviceId)} 기기와 연결할 식물을 선택하세요.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 식물 행은 top 219(본문보다 18 위)부터 시작한다.
          const SizedBox(height: 219 - 198),
          body,
          if (failed)
            const Padding(
              padding: EdgeInsets.fromLTRB(45, 16, 45, 0),
              child: Text(
                '식물과 연결하지 못했어요. 다시 시도해주세요.',
                style: TextStyle(color: kErrorRed, fontSize: 12),
              ),
            ),
        ],
      ),
      bottom: _primary(
        '완료',
        selected == null
            ? _finishWithoutPlant
            : () => _pairing.linkPlant(selected),
      ),
    );
  }

  /// Wi-Fi 연결 뒤 기기를 다시 찾지 못했다. 11의 구성을 쓴다.
  Widget _lostDevice(bool suggestWifiReset) {
    return SensorStepScaffold(
      title: '기기를 다시 찾지 못했어요',
      subtitle: '다시 시도하세요',
      subtitleStyle: kSensorHintStyle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SensorBodyGap(),
          SensorTipBox(
            tips: [
              '스마트폰과 센서를 가까이 두세요.',
              '기기가 Wi-Fi에 연결하는 데 시간이 걸릴 수 있어요.',
              if (suggestWifiReset) '공유기를 바꿨다면 기기 버튼을 3초 눌렀다 떼주세요.',
            ],
          ),
        ],
      ),
      bottom: _primary('다시 시도', _pairing.retry),
    );
  }

  /// 6-2 (4534:21287) 서버 등록 실패.
  Widget _serverFailed(bool suggestWifiReset) {
    return _centerMessage(
      lines: const ['인터넷에는 연결되었지만', '서버등록에 실패했어요'],
      tips: suggestWifiReset
          ? const [
              'Wi-Fi 설정이 바뀌었을 수 있어요.',
              '기기 버튼을 3초 눌렀다 떼고 Wi-Fi를 다시 설정해주세요.',
            ]
          : null,
      button: _primary(
        suggestWifiReset ? '처음부터 다시' : '다시 시도',
        suggestWifiReset ? _pairing.start : _pairing.retry,
      ),
    );
  }

  /// 409. 시안이 없어 6-2의 구성을 쓴다.
  Widget _alreadyClaimed(bool ownedByMe) {
    return _centerMessage(
      lines: const ['이미 등록된 기기예요'],
      tips: ownedByMe
          ? const [
              '내 기기 목록에서 이 기기를 삭제해주세요.',
              '그다음 기기 버튼을 10초 눌러 초기화해주세요.',
              '버튼은 전원이 켜진 뒤에 눌러주세요.',
            ]
          : const [
              '기존 사용자가 앱에서 기기를 삭제해야 해요.',
              '그다음 기기 버튼을 10초 눌러 초기화해주세요.',
              '버튼은 전원이 켜진 뒤에 눌러주세요.',
            ],
      button: _primary('확인', () => Navigator.of(context).maybePop()),
    );
  }

  /// 연결 끊김 등 다시 시도할 수 있는 오류. 6-2의 구성을 쓴다.
  Widget _error(Object error) {
    final lines = switch (error) {
      LeafieApiException() => const ['서버와 연결하지 못했어요'],
      SensorBleException(error: SensorBleError.timeout) => const [
        '기기가 응답하지 않아요',
      ],
      _ => const ['기기와 연결이 끊겼어요'],
    };
    return _centerMessage(
      lines: [...lines, '다시 시도해주세요'],
      button: _primary('다시 시도', _pairing.retry),
    );
  }

  Widget _centerMessage({
    required List<String> lines,
    List<String>? tips,
    required Widget button,
  }) {
    return SensorStepScaffold(
      body: SizedBox(
        // 6-2 문구 중심은 top 414(프레임 중심 - 23)다. 본문 시작(92) 기준 322.
        height: 690,
        child: Column(
          children: [
            const SizedBox(height: 292),
            for (final line in lines)
              Text(
                line,
                textAlign: TextAlign.center,
                style: kTitleStyle.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 30 / 21,
                ),
              ),
            if (tips != null) ...[
              const SizedBox(height: 28),
              SensorTipBox(tips: tips),
            ],
          ],
        ),
      ),
      bottom: button,
    );
  }

  Widget _primary(String label, VoidCallback? onPressed) {
    return PrimaryButton(
      label: label,
      height: 51,
      variant: onPressed == null
          ? PrimaryButtonVariant.disabled
          : PrimaryButtonVariant.enabled,
      onPressed: onPressed,
    );
  }

  /// 18·19·20 하단 두 버튼(149.28 x 44, 좌 38 / 우 214.72).
  Widget _pairButtons({
    required String primaryLabel,
    required VoidCallback? onPrimary,
    required String secondaryLabel,
    required VoidCallback onSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PrimaryButton(
            key: const ValueKey('sensor_confirm'),
            label: primaryLabel,
            width: 149.28,
            height: 44,
            showShadow: false,
            variant: onPrimary == null
                ? PrimaryButtonVariant.disabled
                : PrimaryButtonVariant.enabled,
            onPressed: onPrimary,
          ),
          PrimaryButton(
            label: secondaryLabel,
            width: 149.28,
            height: 44,
            showShadow: false,
            background: kGrayLightest,
            variant: PrimaryButtonVariant.enabled,
            onPressed: onSecondary,
          ),
        ],
      ),
    );
  }
}

/// 가려진 PIN·비밀번호(5728:5760): 연한 텍스트 12 Regular 점.
const TextStyle _kMaskedStyle = TextStyle(
  fontFamily: 'Paperlogy',
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: kTextLight,
);

/// 12의 안내 두 줄(top 427·453, 연한 텍스트 14 Medium, "i"는 Bold).
class _WifiNotice extends StatelessWidget {
  const _WifiNotice();

  static const _style = TextStyle(
    fontFamily: 'Paperlogy',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: kTextLight,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 45, right: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: _style,
              children: [
                TextSpan(
                  text: 'i   ',
                  style: _style.copyWith(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '2.4 GHZ Wi-Fi를 사용해주세요.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 13),
            child: Text(
              'Wi-Fi 정보는 스마트폰에서 센서로 직접 전달됩니다.',
              style: _style.copyWith(height: 20 / 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// 기기가 찾은 Wi-Fi 목록. 시안 4-2("현재 Wi-Fi 사용") 대신 쓴다.
class _WifiListSheet extends StatelessWidget {
  const _WifiListSheet({required this.networks});

  static const manual = '\u0000manual';

  final List<SensorWifiNetwork> networks;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kBackgroundWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: EdgeInsets.fromLTRB(
        0,
        24,
        0,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SensorFieldLabel('Wi-Fi 선택', color: kOrange),
          const Padding(
            padding: EdgeInsets.only(left: 45, bottom: 16),
            child: Text('센서가 찾은 2.4GHz Wi-Fi예요.', style: kSensorHintStyle),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final network in networks) ...[
                  SensorPillRow(
                    key: ValueKey('sensor_wifi_${network.ssid}'),
                    onTap: () => Navigator.of(context).pop(network.ssid),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              network.ssid,
                              style: kSmallStyle.copyWith(
                                color: kTextDark,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            sensorSignalLabel(network.rssi),
                            style: kCaptionStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SensorPillRow(
                  key: const ValueKey('sensor_wifi_manual'),
                  onTap: () => Navigator.of(context).pop(manual),
                  child: Center(
                    child: Text(
                      networks.isEmpty ? '찾은 Wi-Fi가 없어요 · 직접 입력' : '직접 입력',
                      style: kSmallStyle.copyWith(
                        color: kTextDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.bottomPadding),
        ],
      ),
    );
  }
}
