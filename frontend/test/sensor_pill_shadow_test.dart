// 기기연결 알약 행 그림자가 Material에 잘리지 않는 구조인지 잠근다.
//
// flutter_test는 debugDisableShadows로 흐림을 끄므로 골든만으로는 그림자가
// Material에 잘려 사라진 것을 잡지 못한다. 그래서 위젯 구조와 값을 본다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/sensor_ble.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/sensor_pairing_components.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: kFontFamily),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

bool _hasShadow(Widget widget, List<BoxShadow> shadow) {
  if (widget is! DecoratedBox) return false;
  final decoration = widget.decoration;
  return decoration is BoxDecoration &&
      decoration.boxShadow != null &&
      decoration.boxShadow!.length == shadow.length &&
      [
        for (var i = 0; i < shadow.length; i++)
          decoration.boxShadow![i] == shadow[i],
      ].every((same) => same);
}

/// [row] 안에서 그림자가 Material 밖에 그려지는지 확인한다.
///
/// Material은 잉크를 자기 크기로 잘라 그리므로, 그림자를 Material 안의 Ink로
/// 그리면 상자 밖으로 번지는 부분이 사라진다.
void _expectShadowOutsideMaterial(Finder row, List<BoxShadow> shadow) {
  expect(find.descendant(of: row, matching: find.byType(Ink)), findsNothing);
  final shadowBox = find.descendant(
    of: row,
    matching: find.byWidgetPredicate((w) => _hasShadow(w, shadow)),
  );
  expect(shadowBox, findsOneWidget);
  final innerMaterial = find.descendant(
    of: row,
    matching: find.byType(Material),
  );
  expect(innerMaterial, findsOneWidget);
  // 그림자 상자가 Material을 감싸야 한다(반대면 잘린다).
  expect(
    find.descendant(of: shadowBox, matching: innerMaterial),
    findsOneWidget,
  );
}

void main() {
  group('기기연결 알약 행 그림자가 Material에 잘리지 않는다', () {
    testWidgets('기기 행(4534:21031, drop-shadow 0 0 2 0.18)', (tester) async {
      await _pump(
        tester,
        SensorDeviceRow(
          device: const SensorBleDevice(deviceId: 'D40592E7D168', bleId: 'b'),
          trailing: '신호세기: 강함',
          onTap: () {},
        ),
      );
      _expectShadowOutsideMaterial(
        find.byType(SensorPillRow),
        kSensorFieldShadow,
      );
    });

    testWidgets('식물 행(4904:24, shadow 0 0 4 0 0.18)', (tester) async {
      await _pump(
        tester,
        SensorPlantRow(
          nickname: '새싹이',
          character: const PlantCharacterArt(width: 24),
          selected: false,
          onTap: () {},
        ),
      );
      _expectShadowOutsideMaterial(find.byType(SensorPlantRow), const [
        BoxShadow(color: Color(0x2E000000), blurRadius: 4),
      ]);
    });

    testWidgets('눌러도 물결이 뜬다', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        SensorPillRow(onTap: () => taps++, child: const Text('행')),
      );
      await tester.tap(find.text('행'));
      expect(taps, 1);
    });
  });
}
