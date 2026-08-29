import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

// 새 시안이 실제로 그려지는지 눈으로 확인하기 위한 스냅샷.
// 값 비교는 하지 않고 렌더 결과만 파일로 남긴다.
void main() {
  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kOrangeMain,
      surface: kBackgroundWhite,
    ),
    scaffoldBackgroundColor: kBackgroundWhite,
    fontFamily: kFontFamily,
  );

  testWidgets('등록1_이름 화면 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const PlantRegisterNameScreen()),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PlantRegisterNameScreen),
      matchesGoldenFile('goldens/register_name.png'),
    );
  });

  testWidgets('등록2_식물찾기 화면 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const PlantSpeciesSearchScreen()),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PlantSpeciesSearchScreen),
      matchesGoldenFile('goldens/register_search.png'),
    );
  });
}
