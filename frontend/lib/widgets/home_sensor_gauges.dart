import 'package:yeso_plant/services/sensor_api.dart';

/// 홈 게이지 한 줄에 그릴 값. [EnvironmentGauge]가 그대로 받는다.
class SensorGaugeContent {
  const SensorGaugeContent({
    required this.description,
    required this.currentRatio,
    required this.comfortRatio,
    required this.currentLabel,
    required this.maxLabel,
    this.alert = false,
  });

  final String description;
  final double currentRatio;
  final double comfortRatio;
  final String currentLabel;
  final String maxLabel;

  /// 판정이 부족(LOW)이면 마커 글자 앞에 빨간 점을 찍는다(시안 4534:7952).
  final bool alert;
}

/// 판정이 없거나 기기가 없으면 게이지 대신 띄울 안내. 게이지를 그리면 null.
String? sensorPanelMessage(SensorAssessment? sensor) {
  return switch (sensor?.connection) {
    null || SensorConnection.noDevice => '기기연결이 필요합니다',
    SensorConnection.noData => '센서 측정값을 기다리고 있어요',
    SensorConnection.stale => '센서 신호가 끊겼어요. 기기를 확인해 주세요',
    SensorConnection.active => null,
  };
}

/// 판정이 UNKNOWN일 때 마커에 숫자 대신 띄울 짧은 사유. 값이 와도 판정이
/// 없으면 숫자를 보여 주지 않는다(측정이 덜 된 값이 경고처럼 보이지 않게).
String _unknownLabel(String? reason) => switch (reason) {
  'THRESHOLDS_UNAVAILABLE' => '기준 준비 중',
  'NO_DEVICE' || 'NO_DATA' || 'NO_RECENT_DATA' => '측정값 없음',
  _ => '측정 중',
};

/// 토양 수분 게이지. 값은 0~100 상대 %이고 막대도 0~100%로 그린다.
/// 시안(4534:7570)처럼 오른쪽 끝에는 좋아하는 범위의 상한을 쓴다.
SensorGaugeContent soilGaugeContent(
  SensorMetricAssessment soil,
  String plantName,
) {
  final lower = soil.lower;
  final upper = soil.upper;
  final range = switch ((lower, upper)) {
    (final l?, final u?) => '${_number(l)} - ${_number(u)}%',
    (final l?, null) => '${_number(l)}% 이상',
    (null, final u?) => '${_number(u)}% 이하',
    (null, null) => null,
  };
  // 기준이 없을 뿐 측정값은 믿을 수 있으면(THRESHOLDS_UNAVAILABLE) 값은 보여 준다.
  final value =
      soil.state != SensorLevel.unknown ||
          soil.reason == 'THRESHOLDS_UNAVAILABLE'
      ? soil.value
      : null;
  return SensorGaugeContent(
    description: range == null
        ? '${_topic(plantName)} 좋아하는 습도를 아직 몰라요'
        : '${_topic(plantName)} $range 습도를 좋아해요',
    currentRatio: value == null ? 0 : (value / 100).clamp(0.0, 1.0),
    comfortRatio: ((upper ?? 100) / 100).clamp(0.0, 1.0),
    currentLabel: value == null
        ? _unknownLabel(soil.reason)
        : '현재습도 ${_number(value)}%',
    maxLabel: '${_number(upper ?? 100)}%',
    alert: value != null && soil.state == SensorLevel.low,
  );
}

/// 조도 게이지가 막대 끝(100%)으로 치는 순간 조도(lx).
const double lightGaugeMaxLux = 2000;

/// 조도 게이지. 하루 누적이 아니라 센서가 방금 잰 순간 조도(lx)를 0~2000 lx
/// 막대에 그린다. 종별 하루 기준(lux·h)과는 단위가 달라 견줄 수 없어 부족
/// 표시(alert)는 하지 않는다. 아직 값이 없으면 숫자를 보여 주지 않는다.
SensorGaugeContent lightGaugeContent(double? lux, String plantName) {
  return SensorGaugeContent(
    description: '${_topic(plantName)} 지금 이만큼의 빛을 받고 있어요',
    currentRatio: lux == null
        ? 0
        : (lux / lightGaugeMaxLux).clamp(0.0, 1.0),
    comfortRatio: 1,
    currentLabel: lux == null ? '측정 중' : '현재조도 ${lux.round()}lx',
    maxLabel: '${lightGaugeMaxLux.round()}',
  );
}

String _number(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

/// "새싹이는", "토마토는", "바질은"처럼 받침에 맞는 주제 조사를 붙인다.
String _topic(String name) {
  if (name.isEmpty) return name;
  final code = name.runes.last;
  const hangulStart = 0xAC00;
  const hangulEnd = 0xD7A3;
  if (code < hangulStart || code > hangulEnd) return '$name은(는)';
  final hasFinal = (code - hangulStart) % 28 != 0;
  return '$name${hasFinal ? '은' : '는'}';
}
