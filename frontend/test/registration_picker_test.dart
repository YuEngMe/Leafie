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
  testWidgets('컬러를 밀어 선택하면 헤어는 종 자동 매핑값으로 draft에 저장된다', (tester) async {
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
    // 헤어 선택 UI는 없다 — 컬러 탭/헤어 탭 구분도, 헤어 피커도 없어졌다.
    expect(find.text('헤어'), findsNothing);
    expect(find.text('컬러'), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).variant,
      PrimaryButtonVariant.enabled,
    );
    await tester.tap(find.byKey(const ValueKey('appearance_confirm')));
    await tester.pumpAndSettle();
    expect(value.bodyColorId, isNotNull);
    // HERB 카테고리 초안이라 자동 매칭 기본값(바질)이 사용자 개입 없이 저장된다.
    expect(value.headItem, 'hair_sprout');
    expect(find.byType(PlantRegisterCompleteScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기존 헤어 선택 데이터는 UI에 얹지 않아도 그대로 보존된다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
    final value = draft()
      ..bodyColorId = 'color_mint_01'
      ..headItem = 'hair_monstera';
    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterAppearanceScreen(draft: value)),
    );
    await tester.pumpAndSettle();
    // 헤어는 고를 수 없고 화면에도 얹지 않지만 기존 값(hair_monstera)은
    // draft 데이터로 그대로 유지된다(나중에 헤어 렌더 재도입 대비).
    final context = tester.element(find.byType(PlantRegisterAppearanceScreen));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/body_circle.png'),
        context,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PlantRegisterAppearanceScreen),
      matchesGoldenFile('goldens/appearance_hair_picker_402.png'),
    );
    await tester.tap(find.byKey(const ValueKey('appearance_confirm')));
    await tester.pumpAndSettle();
    expect(value.headItem, 'hair_monstera');
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
            const AssetImage('assets/images/body_circle.png'),
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
