import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/models/plant_species_candidate.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/widgets/color_wheel_picker.dart';
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
  testWidgets('컬러 휠을 밀어 선택하면 헤어는 종 자동 매핑값으로 draft에 저장된다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
    final value = draft();
    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterAppearanceScreen(draft: value)),
    );
    await tester.pumpAndSettle();
    // 시안 4534:507에는 하단 버튼이 없고 휠의 체크 배지가 확정 버튼이다.
    expect(find.byType(PrimaryButton), findsNothing);
    // 헤어 탭은 없고, 시안의 '컬러' 라벨만 휠 위에 있다.
    expect(find.text('헤어'), findsNothing);
    expect(find.text('컬러'), findsOneWidget);
    // 왼쪽으로 한 칸(88px) 밀면 오른쪽 옆 색(옐로 → 라이트 그린)이 꼭대기로 온다.
    await tester.drag(find.byType(ColorWheelPicker), const Offset(-88, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance_confirm')));
    await tester.pumpAndSettle();
    expect(value.bodyColorId, 'color_light_green');
    // HERB 카테고리 초안이라 자동 매칭 기본값(바질)이 사용자 개입 없이 저장된다.
    expect(value.headItem, 'hair_sprout');
    expect(find.byType(PlantRegisterCompleteScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기존 헤어 데이터는 미리보기에 얹히고 draft에도 그대로 보존된다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
    final value = draft()
      ..bodyColorId = 'color_green'
      ..headItem = 'hair_monstera';
    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterAppearanceScreen(draft: value)),
    );
    await tester.pumpAndSettle();
    // 헤어는 고를 수 없지만 기존 값(hair_monstera)이 미리보기에 얹히고
    // draft 데이터로도 그대로 유지된다.
    final context = tester.element(find.byType(PlantRegisterAppearanceScreen));
    await tester.runAsync(
      () => Future.wait([
        precacheImage(
          const AssetImage('assets/images/character/body_circle_green.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/character/face_circle_default.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/hair_monstera.png'),
          context,
        ),
      ]),
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
      expect(tester.takeException(), isNull);
      if (size.width == 402) {
        await tester.runAsync(
          () => Future.wait([
            for (final asset in const [
              'assets/images/character/body_circle_yellow.png',
              'assets/images/character/face_circle_default.png',
            ])
              precacheImage(
                AssetImage(asset),
                tester.element(find.byType(PlantRegisterAppearanceScreen)),
              ),
          ]),
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

  testWidgets('연도 범위 밖 날짜는 휠을 건드리지 않고 확정하면 그대로 돌려준다', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showModalBottomSheet<DateTime>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => PlantDatePickerSheet(
                    initialDate: DateTime(2005, 6, 15),
                    buttonLabel: '수정하기',
                    firstYear: 2006,
                    lastYear: 2026,
                  ),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('2005년'), findsOneWidget);
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2005, 6, 15));
  });
  group('최대 날짜 뒤는 휠에 아예 없다', () {
    Future<DateTime? Function()> openSheet(
      WidgetTester tester, {
      required DateTime initialDate,
    }) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      DateTime? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  picked = await showModalBottomSheet<DateTime>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => PlantDatePickerSheet(
                      initialDate: initialDate,
                      maximumDate: DateTime(2026, 10, 16, 15, 30),
                    ),
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      return () => picked;
    }

    Future<void> scrollRows(WidgetTester tester, String wheel, int rows) async {
      // 위로 끌면 다음 줄로 간다. 드래그 인식 여유만큼 더 끈다.
      final sign = rows.sign.toDouble();
      await tester.drag(
        find.byKey(ValueKey(wheel)),
        Offset(
          0,
          -sign *
              (PlantDatePickerSheet.rowExtent * rows.abs() + kDragSlopDefault),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('최대 연·월·일 뒤의 줄을 그리지 않는다', (tester) async {
      await openSheet(tester, initialDate: DateTime(2026, 10, 15));

      expect(find.text('2026년'), findsOneWidget);
      expect(find.text('2027년'), findsNothing);
      expect(find.text('10월'), findsOneWidget);
      expect(find.text('11월'), findsNothing);
      expect(find.text('16일'), findsOneWidget);
      expect(find.text('17일'), findsNothing);
    });

    testWidgets('지난 해로 옮기면 12월·31일까지 다시 고를 수 있다', (tester) async {
      await openSheet(tester, initialDate: DateTime(2026, 10, 15));

      await scrollRows(tester, 'date_year_wheel', -1);

      expect(find.text('2025년'), findsOneWidget);
      expect(find.text('11월'), findsOneWidget);
      expect(find.text('17일'), findsOneWidget);
    });

    testWidgets('최대 날짜보다 늦은 월·일을 든 채 최대 연도로 오면 최대 날짜로 당긴다', (tester) async {
      final picked = await openSheet(
        tester,
        initialDate: DateTime(2025, 12, 31),
      );

      await scrollRows(tester, 'date_year_wheel', 1);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(picked(), DateTime(2026, 10, 16));
    });

    testWidgets('최대 날짜보다 늦은 날로 열려도 최대 날짜로 시작한다', (tester) async {
      final picked = await openSheet(tester, initialDate: DateTime(2027, 3, 3));

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(picked(), DateTime(2026, 10, 16));
    });
  });

  group('컬러 휠 관성', () {
    Future<List<int>> pumpWheel(WidgetTester tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final selected = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: ColorWheelPicker.top,
                  height: ColorWheelPicker.height,
                  child: ColorWheelPicker(
                    initialIndex: 0,
                    onSelected: selected.add,
                    confirmLabel: '선택 완료',
                    onConfirm: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return selected;
    }

    testWidgets('세게 튕기면 손을 뗀 뒤에도 몇 칸 더 돌다 칸에 멈춘다', (tester) async {
      final selected = await pumpWheel(tester);

      // 150px(1.7칸)만 밀고 빠르게 놓는다. 관성이 없으면 2칸에서 멈추고,
      // 관성이 있으면 1200px/s × 0.3초 ≈ 4칸을 더 돌아 6칸쯤에 멈춘다
      // (10칸을 넘기면 한 바퀴 돌아 처음 색으로 오므로 그 아래로 잡는다).
      await tester.fling(
        find.byType(ColorWheelPicker),
        const Offset(-150, 0),
        1200,
      );
      await tester.pumpAndSettle();

      expect(selected.last, greaterThanOrEqualTo(4));
      // 도는 동안에도 칸을 지날 때마다 알린다(햅틱이 울린다). 되돌아가지 않는다.
      expect(selected.length, greaterThan(2));
      for (var i = 1; i < selected.length; i++) {
        expect(selected[i], greaterThan(selected[i - 1]));
      }
    });

    testWidgets('천천히 밀고 놓으면 관성 없이 가까운 칸에 멈춘다', (tester) async {
      final selected = await pumpWheel(tester);

      await tester.drag(find.byType(ColorWheelPicker), const Offset(-88, 0));
      await tester.pumpAndSettle();

      expect(selected, [1]);
    });
  });
}
