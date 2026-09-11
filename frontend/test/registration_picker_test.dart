import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/models/plant_species_candidate.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/widgets/plant_search_components.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

PlantRegistrationDraft draft() => PlantRegistrationDraft(
  name: '테스트',
  species: const PlantSpeciesCandidate(
    referenceId: 'catalog:test',
    displayName: '테스트',
    scientificName: 'Test',
    categorySuggestion: 'HERB',
  ),
);

void main() {
  testWidgets('컬러를 밀어 선택하고 헤어 탭 왕복 후에도 값을 저장한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
    final value = draft();
    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterAppearanceScreen(draft: value)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).variant,
      PrimaryButtonVariant.disabled,
    );
    await tester.drag(find.byType(PageView), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).variant,
      PrimaryButtonVariant.enabled,
    );
    final selection = tester.widget<Text>(find.textContaining('선택됨')).data;
    await tester.tap(find.text('헤어'));
    await tester.pumpAndSettle();
    expect(find.text('밀거나 눌러 헤어를 선택해주세요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hair_cactus_heart_01')));
    await tester.pumpAndSettle();
    expect(find.text('하트 선인장 선택됨'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(find.text('분홍 꽃 선인장 선택됨'), findsOneWidget);
    await tester.tap(find.text('컬러'));
    await tester.pumpAndSettle();
    expect(find.text(selection!), findsOneWidget);
    await tester.tap(find.text('헤어'));
    await tester.pumpAndSettle();
    expect(find.text('분홍 꽃 선인장 선택됨'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('appearance_confirm')));
    await tester.pumpAndSettle();
    expect(value.bodyColorId, isNotNull);
    expect(value.headItem, 'hair_cactus_pink_flower_01');
    expect(find.byType(PlantRegisterCompleteScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기존 헤어 선택을 복원하고 원본 에셋을 표시한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PlantRegisterAppearanceScreen(
          draft: draft()
            ..bodyColorId = 'color_mint_01'
            ..headItem = 'hair_cactus_heart_01',
        ),
      ),
    );
    await tester.tap(find.text('헤어'));
    await tester.pumpAndSettle();
    expect(find.text('하트 선인장 선택됨'), findsOneWidget);
    final context = tester.element(find.byType(PlantRegisterAppearanceScreen));
    await tester.runAsync(() async {
      for (final asset in ['leafie_character', 'plant_hair_catalog']) {
        await precacheImage(AssetImage('assets/images/$asset.png'), context);
      }
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PlantRegisterAppearanceScreen),
      matchesGoldenFile('goldens/appearance_hair_picker_402.png'),
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(402, 874)]) {
    testWidgets('꾸미기 컨트롤이 화면 밖으로 잘리지 않는다 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: PlantRegisterAppearanceScreen(draft: draft())),
      );
      await tester.pumpAndSettle();
      final button = tester.getRect(
        find.byKey(const ValueKey('appearance_confirm')),
      );
      expect(button.bottom, lessThanOrEqualTo(size.height - 34));
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(size.width));
      await tester.ensureVisible(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width == 402) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/leafie_character.png'),
            tester.element(find.byType(PlantRegisterAppearanceScreen)),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(PlantRegisterAppearanceScreen),
          matchesGoldenFile('goldens/appearance_scroll_picker_402.png'),
        );
      }
    });
    testWidgets('날짜창 다음 버튼이 화면 폭에 맞는다 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PlantDatePickerSheet(initialDate: DateTime(2026, 9, 10)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(PrimaryButton));
      expect(rect.left, 34);
      expect(rect.right, size.width - 34);
      expect(tester.takeException(), isNull);
    });
  }
}
