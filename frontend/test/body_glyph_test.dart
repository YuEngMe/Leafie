import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/body_glyph.dart';

Future<void> _pump(WidgetTester tester, Widget glyph) => tester.pumpWidget(
  MaterialApp(home: Center(child: glyph)),
);

void main() {
  // 시안 5028:1240의 벡터 크기. 동그라미는 살짝 납작하고 통통이는 발이 있다.
  const designSizes = {
    'body_circle': Size(22.8359, 21.0352),
    'body_thumb': Size(21.4324, 20.4654),
    'body_square': Size(22.4394, 19.6566),
  };

  for (final MapEntry(key: id, value: design) in designSizes.entries) {
    testWidgets('$id 글리프는 시안 벡터를 시안 크기로 그린다', (tester) async {
      await _pump(tester, BodyGlyph(id: id, selected: false));

      final size = tester.getSize(find.byType(BodyGlyph));
      expect(size.width, closeTo(design.width, 0.01));
      expect(size.height, closeTo(design.height, 0.01));
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (svg.bytesLoader as SvgAssetLoader).assetName,
        'assets/images/${id.replaceFirst('body_', 'body_glyph_')}.svg',
      );
    });
  }

  testWidgets('size는 22 기준 배율이다(편집 화면 1.222배)', (tester) async {
    await _pump(
      tester,
      const BodyGlyph(id: 'body_circle', selected: false, size: 22 * 1.222),
    );

    final size = tester.getSize(find.byType(BodyGlyph));
    expect(size.width, closeTo(27.91, 0.02));
    expect(size.height, closeTo(25.71, 0.02));
  });

  testWidgets('선택은 주황, 미선택은 회색으로 칠한다', (tester) async {
    await _pump(tester, const BodyGlyph(id: 'body_thumb', selected: true));
    expect(
      tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter,
      const ColorFilter.mode(kOrangeMain, BlendMode.srcIn),
    );

    await _pump(tester, const BodyGlyph(id: 'body_thumb', selected: false));
    expect(
      tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter,
      const ColorFilter.mode(kProgressInactive, BlendMode.srcIn),
    );
  });
}
