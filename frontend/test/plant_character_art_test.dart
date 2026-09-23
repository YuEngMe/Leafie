import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/widgets/plant_appearance_colors.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';

void main() {
  group('캐릭터 애셋 파일', () {
    test('10색 × 3바디 몸통 PNG가 모두 있다', () {
      final paths = {
        for (final body in PlantBody.values)
          for (final color in kPlantAppearanceColors)
            plantBodyAssetFor(body, color.id),
      };
      expect(paths, hasLength(30));
      for (final path in paths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('4표정 × 3바디 얼굴 PNG가 모두 있다', () {
      final paths = {
        for (final body in PlantBody.values)
          for (final expression in PlantExpression.values)
            plantFaceAssetFor(body, expression),
      };
      expect(paths, hasLength(12));
      for (final path in paths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });
  });

  group('애셋 경로 매핑', () {
    test('colorId는 color_ 접두사를 뗀 색 이름으로 간다', () {
      expect(
        plantBodyAssetFor(PlantBody.circle, 'color_red'),
        'assets/images/character/body_circle_red.png',
      );
      expect(
        plantBodyAssetFor(PlantBody.thumb, 'color_light_green'),
        'assets/images/character/body_thumb_light_green.png',
      );
      expect(
        plantBodyAssetFor(PlantBody.square, 'color_white'),
        'assets/images/character/body_square_white.png',
      );
    });

    test('colorId가 없거나 모르는 값이면 옐로 몸통이다', () {
      for (final colorId in [null, '', 'color_black', 'red']) {
        expect(
          plantBodyAssetFor(PlantBody.circle, colorId),
          'assets/images/character/body_circle_yellow.png',
          reason: '$colorId',
        );
      }
    });

    test('표정은 default/happy/neutral/sad 얼굴로 간다', () {
      const expected = {
        PlantExpression.none: 'default',
        PlantExpression.defaultFace: 'default',
        PlantExpression.happy: 'happy',
        PlantExpression.blank: 'neutral',
        PlantExpression.sad: 'sad',
      };
      for (final entry in expected.entries) {
        expect(
          plantFaceAssetFor(PlantBody.square, entry.key),
          'assets/images/character/face_square_${entry.value}.png',
        );
      }
    });
  });

  testWidgets('몸통 위에 같은 캔버스로 얼굴을 겹쳐 그린다', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PlantCharacterArt(
            width: 200,
            body: PlantBody.thumb,
            expression: PlantExpression.sad,
            colorId: 'color_blue',
          ),
        ),
      ),
    );

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    final assets = [
      for (final image in images) (image.image as AssetImage).assetName,
    ];
    expect(assets, [
      'assets/images/character/body_thumb_blue.png',
      'assets/images/character/face_thumb_sad.png',
    ]);
    final rects = [
      for (final f in find.byType(Image).evaluate())
        tester.getRect(find.byWidget(f.widget)),
    ];
    expect(rects[0], rects[1]);
    // 위젯 박스는 바디와 무관하게 width × 649/698이다.
    final box = tester.getRect(find.byType(PlantCharacterArt));
    expect(box.width, 200);
    expect(box.height, closeTo(200 * 649 / 698, 0.001));
    // 1 unit = width × 0.897 / 155.23. thumb 캔버스는 171.49 unit 폭, 가로
    // 가운데. 몸통 바닥은 박스 바닥에서 0.05301 × width 위보다 0.27 unit
    // 아래이고, 캔버스 바닥은 거기서 그림자 여백 10.745 unit 더 아래다.
    const u = 200 * 0.897 / 155.23;
    expect(rects[0].width, closeTo(171.49 * u, 0.01));
    expect(rects[0].center.dx, closeTo(box.center.dx, 0.01));
    expect(
      rects[0].bottom,
      closeTo(box.bottom - 200 * 37 / 698 + 0.27 * u + 10.745 * u, 0.01),
    );
  });
}
