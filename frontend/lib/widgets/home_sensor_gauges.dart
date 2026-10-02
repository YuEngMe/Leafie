import 'package:yeso_plant/services/sensor_api.dart';

/// 홈 게이지 한 줄에 그릴 값. [EnvironmentGauge]가 그대로 받는다.
class SensorGaugeContent {
  const SensorGaugeContent({
    required this.description,
    required this.currentRatio,
    required this.comfortRatio,
    required this.currentLabel,
    required this.maxLabel,
  });

  final String description;
  final double currentRatio;
  final double comfortRatio;
  final String currentLabel;
  final String maxLabel;
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
  );
}

/// 조도 게이지. 서버는 **어제 하루**(완결된 전일) 누적 조도(lux·h)와 종별 하루
/// 기준(하한, 반그늘 종은 상한도)을 준다. 디자이너 확인에 따라 "하루 기준 대비
/// %"로 바꿔 보여 준다(예: 72,000 / 60,000 → 어제 120%). 막대는 기준(100%)에서
/// 꽉 찬다. 판정이 UNKNOWN이면 값이 와도 숫자를 보여 주지 않는다.
SensorGaugeContent lightGaugeContent(
  SensorMetricAssessment light,
  String plantName,
) {
  final target = light.lower;
  final upper = light.upper;
  final value = light.state == SensorLevel.unknown ? null : light.value;
  final percent = (value != null && target != null && target > 0)
      ? (value / target * 100).round()
      : null;
  final upperPercent = (upper != null && target != null && target > 0)
      ? (upper / target * 100).round()
      : null;
  return SensorGaugeContent(
    description: switch ((target, upperPercent)) {
      (null, _) => '${_topic(plantName)} 좋아하는 빛의 양을 아직 몰라요',
      (_, final u?) => '${_topic(plantName)} 하루 기준의 100 - $u% 빛을 좋아해요',
      _ => '${_topic(plantName)} 하루 기준의 100% 이상 빛을 좋아해요',
    },
    currentRatio: percent == null ? 0 : (percent / 100).clamp(0.0, 1.0),
    comfortRatio: 1,
    currentLabel: percent == null
        ? _unknownLabel(light.reason)
        : '어제 $percent%',
    maxLabel: '100%',
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
