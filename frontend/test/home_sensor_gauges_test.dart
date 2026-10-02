import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/sensor_api.dart';
import 'package:yeso_plant/widgets/home_sensor_gauges.dart';

SensorMetricAssessment _metric({
  SensorLevel state = SensorLevel.ok,
  required String unit,
  double? value,
  double? lower,
  double? upper,
}) => SensorMetricAssessment(
  state: state,
  unit: unit,
  value: value,
  lower: lower,
  upper: upper,
);

SensorAssessment _assessment(SensorConnection connection) => SensorAssessment(
  connection: connection,
  soil: _metric(unit: 'relative_percent'),
  light: _metric(unit: 'lux_hours'),
);

void main() {
  test('기기·측정 상태에 맞는 안내를 고르고, 정상이면 게이지를 그린다', () {
    expect(sensorPanelMessage(null), '기기연결이 필요합니다');
    expect(
      sensorPanelMessage(_assessment(SensorConnection.noDevice)),
      '기기연결이 필요합니다',
    );
    expect(
      sensorPanelMessage(_assessment(SensorConnection.noData)),
      '센서 측정값을 기다리고 있어요',
    );
    expect(sensorPanelMessage(_assessment(SensorConnection.stale)), isNotNull);
    expect(sensorPanelMessage(_assessment(SensorConnection.active)), isNull);
  });

  test('토양 수분은 값과 종별 범위를 %로 보여 준다', () {
    final content = soilGaugeContent(
      _metric(unit: 'relative_percent', value: 20, lower: 40, upper: 90),
      '새싹이',
    );

    expect(content.description, '새싹이는 40 - 90% 습도를 좋아해요');
    expect(content.currentLabel, '현재습도 20%');
    expect(content.currentRatio, closeTo(0.2, 1e-9));
    expect(content.comfortRatio, closeTo(0.9, 1e-9));
    expect(content.maxLabel, '90%');
  });

  test('조도는 하루 기준 대비 %로 바꾸고 막대는 100%에서 꽉 찬다', () {
    final over = lightGaugeContent(
      _metric(unit: 'lux_hours', value: 72000, lower: 60000),
      '바질',
    );
    expect(over.description, '바질은 하루 기준의 100% 이상 빛을 좋아해요');
    expect(over.currentLabel, '현재조도 120%');
    expect(over.currentRatio, 1);

    final under = lightGaugeContent(
      _metric(unit: 'lux_hours', value: 15000, lower: 60000),
      '바질',
    );
    expect(under.currentLabel, '현재조도 25%');
    expect(under.currentRatio, closeTo(0.25, 1e-9));
  });

  test('값이나 기준이 없으면 숫자를 지어내지 않는다', () {
    final soil = soilGaugeContent(_metric(unit: 'relative_percent'), '새싹이');
    expect(soil.currentLabel, '측정 중');
    expect(soil.currentRatio, 0);
    expect(soil.description, '새싹이는 좋아하는 습도를 아직 몰라요');

    final light = lightGaugeContent(
      _metric(unit: 'lux_hours', value: 1000),
      '새싹이',
    );
    expect(light.currentLabel, '측정 중');
    expect(light.description, '새싹이는 좋아하는 빛의 양을 아직 몰라요');
  });
}
