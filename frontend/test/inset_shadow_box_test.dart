// 시안의 안쪽 그림자(CSS inset)가 상자 안쪽에 그려지는지 잠근다.
//
// flutter_test는 debugDisableShadows로 흐림을 끄므로 골든만으로는 그림자가
// 바깥/안쪽이 뒤바뀐 것을 잡기 어렵다. 쓰는 곳의 값을 확인하고, 그리는
// 방식은 흐림을 켠 채 픽셀로 확인한다.

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/withdraw_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/diagnosis_components.dart';
import 'package:yeso_plant/widgets/inset_shadow_box.dart';
import 'package:yeso_plant/widgets/sensor_pairing_components.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: kFontFamily),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('안쪽 그림자', () {
    testWidgets('회원 탈퇴 안내 상자(4534:2998)는 inset 0 0 4 0.2다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WithdrawScreen()));

      final box = tester.widget<InsetShadowBox>(
        find.ancestor(
          of: find.text(WithdrawScreen.notices[0]),
          matching: find.byType(InsetShadowBox),
        ),
      );
      expect(box.shadows, const [
        BoxShadow(color: Color(0x33000000), blurRadius: 4),
      ]);
      // 바깥 그림자가 남아 있으면 상자 밖이 어두워진다.
      final outer = tester.widgetList<DecoratedBox>(
        find.ancestor(
          of: find.text(WithdrawScreen.notices[0]),
          matching: find.byType(DecoratedBox),
        ),
      );
      for (final decorated in outer) {
        final decoration = decorated.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.boxShadow, isNull);
        }
      }
    });

    testWidgets('기기 못 찾음 팁 상자(4534:21065)는 inset 0 0 4 0.2다', (tester) async {
      await _pump(tester, const SensorTipBox(tips: ['센서 전원이 켜져 있는지 확인해주세요.']));
      final box = tester.widget<InsetShadowBox>(find.byType(InsetShadowBox));
      expect(box.color, kBackgroundWhite);
      expect(box.shadows, const [
        BoxShadow(color: Color(0x33000000), blurRadius: 4),
      ]);
    });

    testWidgets('처방전 노란 카드(4534:19735)는 inset -3 -3 1 0.25다', (tester) async {
      tester.view.physicalSize = const Size(379, 643);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        PrescriptionCard(
          photo: MemoryImage(_pixelPng),
          statusLabel: '조금 관리가 필요해요',
          patientRows: const [('환자성명', '새싹이')],
          symptoms: const ['잎 처짐'],
          causes: const [],
          recommendations: const ['물을 충분히 주세요.'],
          onClose: () {},
        ),
      );
      final card = tester.widget<InsetShadowBox>(find.byType(InsetShadowBox));
      expect(card.color, const Color(0xFFFFDB86));
      expect(card.borderRadius, BorderRadius.circular(20.733));
      expect(card.shadows, const [
        BoxShadow(
          color: Color(0x40765E3C),
          blurRadius: 1,
          offset: Offset(-3, -3),
        ),
      ]);
    });

    // 흐림을 켜고 그려 그림자가 상자 안쪽 가장자리에만 생기는지 본다.
    Future<ui.Image> paintBox(WidgetTester tester, List<BoxShadow> shadows) {
      return tester
          .runAsync(() async {
            debugDisableShadows = false;
            try {
              final recorder = ui.PictureRecorder();
              final canvas = Canvas(recorder);
              canvas.drawColor(const Color(0xFF00FF00), BlendMode.src);
              canvas.translate(20, 20);
              InsetShadowPainter(
                color: kBackgroundWhite,
                shadows: shadows,
                borderRadius: BorderRadius.zero,
              ).paint(canvas, const Size(100, 60));
              return recorder.endRecording().toImage(140, 100);
            } finally {
              debugDisableShadows = true;
            }
          })
          .then((image) => image!);
    }

    Future<Color> pixel(WidgetTester tester, ui.Image image, int x, int y) {
      return tester
          .runAsync(() async {
            final data = await image.toByteData();
            final i = (y * image.width + x) * 4;
            return Color.fromARGB(
              data!.getUint8(i + 3),
              data.getUint8(i),
              data.getUint8(i + 1),
              data.getUint8(i + 2),
            );
          })
          .then((color) => color!);
    }

    testWidgets('번짐 없는 inset은 네 가장자리 안쪽만 어둡게 한다', (tester) async {
      final image = await paintBox(tester, const [
        BoxShadow(color: Color(0x33000000), blurRadius: 4),
      ]);
      // 상자 밖(19,50)은 배경 그대로 — 바깥 그림자가 아니다.
      expect(await pixel(tester, image, 19, 50), const Color(0xFF00FF00));
      expect(await pixel(tester, image, 70, 19), const Color(0xFF00FF00));
      // 가장자리 안쪽은 가운데보다 어둡다.
      final center = await pixel(tester, image, 70, 50);
      expect(center, kBackgroundWhite);
      for (final (x, y) in [(20, 50), (119, 50), (70, 20), (70, 79)]) {
        final edge = await pixel(tester, image, x, y);
        expect(edge.r, lessThan(center.r), reason: '($x, $y)');
      }
    });

    testWidgets('왼쪽·위로 옮긴 inset은 오른쪽·아래 안쪽만 어둡게 한다', (tester) async {
      final image = await paintBox(tester, const [
        BoxShadow(
          color: Color(0x40765E3C),
          blurRadius: 1,
          offset: Offset(-3, -3),
        ),
      ]);
      expect(await pixel(tester, image, 21, 50), kBackgroundWhite);
      expect(await pixel(tester, image, 70, 21), kBackgroundWhite);
      final right = await pixel(tester, image, 118, 50);
      final bottom = await pixel(tester, image, 70, 78);
      expect(right.r, lessThan(kBackgroundWhite.r));
      expect(bottom.r, lessThan(kBackgroundWhite.r));
      // 카드 밖으로는 번지지 않는다.
      expect(await pixel(tester, image, 121, 50), const Color(0xFF00FF00));
      expect(await pixel(tester, image, 18, 18), const Color(0xFF00FF00));
    });
  });
}

final _pixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);
