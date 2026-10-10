// 식물 등록 1~3단계의 시안 좌표를 잠근다. 이 화면들은 한동안 시안 대조를
// 거치지 않아 좌우 여백이 13px, 하단 버튼이 40px 어긋나 있었다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_register_body_screen.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
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

/// index번째 RoundedInputField의 흰 칸 상자(라벨 제외).
Rect _fieldBox(WidgetTester tester, int index) => tester.getRect(
  find
      .descendant(
        of: find.byType(RoundedInputField).at(index),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      )
      .first,
);

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
      _expectAt(tester, '헤드라인', find.text('리피의 이름을 지어주세요!'), 45, 140);
      _expectAt(tester, '부제', find.text('당신의 식물을 뭐라고 부를까요?'), 45, 175);
      _expectAt(tester, '다음 버튼', find.byType(PrimaryButton), 34, 790);

      // 4534:954: 애칭 라벨 top 493 → 칸 top 517. 라벨 자리는 따로 어긋나
      // 있어(AUTH-ISS-005) 라벨과 칸 사이만 잠근다.
      final label = tester.getRect(find.text('애칭'));
      expect(_fieldBox(tester, 0).top - label.top, closeTo(24, 0.5));

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
      // 4534:1007: 칸 top 261(라벨 top + 24).
      expect(_fieldBox(tester, 0).top, closeTo(261, 1));
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
      // 4534:85: 칸 top 238·348·458(라벨 top + 24). 예전엔 4px 아래였다.
      expect(_fieldBox(tester, 0).top, closeTo(238, 1));
      expect(_fieldBox(tester, 1).top, closeTo(348, 1));
      expect(_fieldBox(tester, 2).top, closeTo(458, 1));
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

  // 최신 시안(4534:22)은 등록을 5단계로 본다: 바디(5028:1193)와 컬러
  // (4534:507) 모두 진행선이 끝까지 주황이다. 예전 앱은 컬러를 6단계로
  // 따로 세어 바디 화면 물결 끝이 회색이었다.
  testWidgets('꾸미기(바디·컬러)는 5단계 중 마지막 단계다', (tester) async {
    for (final screen in <Widget>[
      PlantRegisterBodyScreen(draft: _draft()),
      PlantRegisterAppearanceScreen(draft: _draft()),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      final bar = tester.widget<RegisterProgressBar>(
        find.byType(RegisterProgressBar),
      );
      expect(bar.step, 5, reason: screen.runtimeType.toString());
      expect(bar.totalSteps, 5, reason: screen.runtimeType.toString());
      expect(find.text('캐릭터 꾸미기'), findsOneWidget);
    }
  });

  group('꾸미기 컬러 (4534:507)', () {
    testWidgets('문구·헤드라인 가운데·휠·체크 배지·캐릭터 좌표', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(home: PlantRegisterAppearanceScreen(draft: _draft())),
      );
      await tester.pumpAndSettle();

      // 4534:535 헤드라인은 가운데 정렬(중심 x 201).
      final title = find.text('리피를 꾸며주세요!');
      expect(tester.widget<Text>(title).textAlign, TextAlign.center);
      expect(tester.getRect(title).center.dx, closeTo(201, 1));
      expect(find.text('식물을 꾸며주세요!'), findsNothing);
      // 하단 '선택 완료' 버튼과 안내 문구는 없다.
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.text('밀거나 눌러 컬러를 선택해주세요'), findsNothing);

      // 처음 꼭대기 칸(중심 200, 655)은 옐로다(5038:6395 Ellipse 451).
      final top = tester.getRect(
        find.byKey(const ValueKey('appearance_color_yellow')),
      );
      expect(top.center.dx, closeTo(200, 1));
      expect(top.center.dy, closeTo(655, 1));
      // 체크 배지 5038:6407: 원 38x38이 x=181 y=777.
      final check = tester.getRect(
        find.byKey(const ValueKey('appearance_confirm')),
      );
      expect(check.center.dx, closeTo(181 + 19, 1));
      expect(check.center.dy, closeTo(777 + 19, 1));

      // 캐릭터는 편집 화면(5038:6460)과 같은 폭 182.4 · 박스 위 y=366.
      // 예전에는 폭 200으로 약 10% 크고 9px 위였다.
      final art = tester.getRect(find.byType(PlantCharacterArt));
      expect(art.width, closeTo(182.4, 1));
      expect(art.top, closeTo(366, 1));
    });
  });

  group('꾸미기 바디 (5028:1193)', () {
    testWidgets('헤드라인 가운데 정렬', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(home: PlantRegisterBodyScreen(draft: _draft())),
      );
      await tester.pumpAndSettle();
      // 5028:1221 헤드라인은 가운데(중심 x 200.5).
      final title = find.text('리피의 외형을 정해주세요!');
      expect(tester.widget<Text>(title).textAlign, TextAlign.center);
      expect(tester.getRect(title).center.dx, closeTo(201, 1));
    });
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
