// 식물 등록 1~3단계의 시안 좌표를 잠근다. 이 화면들은 한동안 시안 대조를
// 거치지 않아 좌우 여백이 13px, 하단 버튼이 40px 어긋나 있었다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_progress_bar.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

/// 시안이 그려진 기기와 같은 조건. 상단 46 / 하단 34.
const _mockInsets = FakeViewPadding(top: 46, bottom: 34);

void _setUpView(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = _mockInsets;
  addTearDown(tester.view.reset);
}

void _expectAt(
  WidgetTester tester,
  String label,
  Finder f,
  double? x,
  double? y,
) {
  final rect = tester.getRect(f.first);
  if (x != null) expect(rect.left, closeTo(x, 1), reason: '$label x');
  if (y != null) expect(rect.top, closeTo(y, 1), reason: '$label y');
}

PlantRegistrationDraft _draft() => PlantRegistrationDraft(
  name: '씩씩이',
  species: const PlantSpeciesCandidate(
    referenceId: 'catalog:ocimum-basilicum',
    displayName: '바질',
    scientificName: 'Ocimum basilicum',
    categorySuggestion: 'HERB',
  ),
);

void main() {
  group('1단계 이름 (2315:2189)', () {
    testWidgets('좌표를 지킨다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        const MaterialApp(home: PlantRegisterNameScreen()),
      );
      await tester.pumpAndSettle();

      // 물결은 프레임(238x15)보다 넘쳐 243x21.425로 그려진다.
      _expectAt(tester, '진행 물결', find.byType(RegisterProgressBar), 79.5, 91.79);
      _expectAt(tester, '헤드라인', find.text('식물의 이름을 지어주세요!'), 45, 140);
      _expectAt(tester, '부제', find.text('당신의 식물을 뭐라고 부를까요?'), 45, 175);
      _expectAt(tester, '다음 버튼', find.byType(PrimaryButton), 34, 790);

      final button = tester.getRect(find.byType(PrimaryButton));
      expect(button.width, closeTo(334, 1));
    });

    testWidgets('시안대로 애칭 한 칸만 받는다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PlantRegisterNameScreen()),
      );

      // 식물 명칭은 다음 화면에서 고른다.
      expect(find.byType(RoundedInputField), findsOneWidget);
      expect(find.text('애칭'), findsOneWidget);
      expect(find.text('식물 명칭'), findsNothing);
    });
  });

  group('2단계 식물 찾기 (2315:2515)', () {
    testWidgets('좌표를 지킨다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        const MaterialApp(home: PlantSpeciesSearchScreen(name: '씩씩이')),
      );
      await tester.pumpAndSettle();

      _expectAt(tester, '헤드라인', find.text('내 식물을 찾아주세요!'), 45, 140);
      _expectAt(tester, '식물 명칭 라벨', find.text('식물 명칭'), 45, 237);
      _expectAt(tester, '다음 버튼', find.byType(PrimaryButton), 34, 790);
    });

    testWidgets('고르기 전에는 다음이 잠겨 있다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PlantSpeciesSearchScreen(name: '씩씩이')),
      );
      await tester.pumpAndSettle();

      PrimaryButtonVariant variant() =>
          tester.widget<PrimaryButton>(find.byType(PrimaryButton)).variant;

      expect(variant(), PrimaryButtonVariant.disabled);

      await tester.tap(find.text('바질'));
      await tester.pump();

      expect(variant(), PrimaryButtonVariant.enabled);
    });
  });

  group('3단계 식물 정보 (2318:2981)', () {
    testWidgets('좌표를 지킨다 — 라벨 사이가 110이다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(home: PlantRegisterEnvironmentScreen(draft: _draft())),
      );
      await tester.pumpAndSettle();

      _expectAt(tester, '헤드라인', find.text('내 식물을 챙긴 날은 언제인가요?'), 45, 140);
      _expectAt(tester, '라벨1', find.text('장소(별명)'), 45, 214);
      _expectAt(tester, '라벨2', find.text('마지막 물 준 날'), 45, 324);
      _expectAt(tester, '라벨3', find.text('분갈이 한 날'), 45, 434);
      _expectAt(tester, '다음 버튼', find.byType(PrimaryButton), 34, 790);
    });

    testWidgets('시안 문구를 쓴다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PlantRegisterEnvironmentScreen(draft: _draft())),
      );

      expect(find.text('식물 정보'), findsOneWidget);
      expect(find.text('예: 베란다'), findsOneWidget);
      expect(find.text('선택하기'), findsNWidgets(2));

      // 시안 대조 전 문구가 남아 있으면 안 된다.
      expect(find.text('키우는 장소'), findsNothing);
      expect(find.text('장소 (별명)'), findsNothing);
    });
  });

  testWidgets('진행 단계가 1, 2, 3으로 이어진다', (tester) async {
    // 검색이 1번을 쓰고 2번이 비어 있어 물결이 이름 화면과 같아 보였다.
    for (final (screen, want) in <(Widget, int)>[
      (const PlantRegisterNameScreen(), 1),
      (const PlantSpeciesSearchScreen(name: '씩씩이'), 2),
      (PlantRegisterEnvironmentScreen(draft: _draft()), 3),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      final bar = tester.widget<RegisterProgressBar>(
        find.byType(RegisterProgressBar),
      );
      expect(bar.step, want, reason: screen.runtimeType.toString());
    }
  });

  // 시뮬레이터에서 키보드를 열면 "BOTTOM OVERFLOWED BY 123 PIXELS"가 떴다.
  // iPhone 16 Pro 키보드 높이(336)를 viewInsets로 올려 같은 조건을 만든다.
  group('키보드가 열려도 넘치지 않는다', () {
    Future<void> openKeyboard(WidgetTester tester, Widget screen) async {
      _setUpView(tester);
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pumpAndSettle();
    }

    testWidgets('1단계 이름', (tester) async {
      await openKeyboard(tester, const PlantRegisterNameScreen());
      expect(tester.takeException(), isNull);
      expect(find.byType(PrimaryButton), findsOneWidget);
    });

    testWidgets('3단계 환경', (tester) async {
      await openKeyboard(tester, PlantRegisterEnvironmentScreen(draft: _draft()));
      expect(tester.takeException(), isNull);
    });
  });
}
