// 식물 등록 마법사가 화면 사이로 값을 잃지 않고 전달하는지 확인한다.
// (POST /plants는 마지막 화면에서 한 번에 보내므로 값 유실이 곧 등록 실패다.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/screens/plant_register_personality_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';

PlantRegistrationDraft _sampleDraft() => PlantRegistrationDraft(
  name: '씩씩이',
  species: const PlantSpeciesCandidate(
    referenceId: 'catalog:ocimum-basilicum',
    displayName: '바질',
    scientificName: 'Ocimum basilicum',
    categorySuggestion: 'HERB',
  ),
);

void main() {
  testWidgets('애칭과 식물명칭을 채우면 환경 화면으로 draft가 전달된다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PlantRegisterNameScreen()));

    await tester.enterText(find.byType(TextField).first, '씩씩이');

    // 식물명칭 칸은 AbsorbPointer로 덮여 있어 이를 감싼 GestureDetector를 눌러야 한다
    await tester.tap(
      find.ancestor(
        of: find.byType(AbsorbPointer),
        matching: find.byType(GestureDetector),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('바질'));
    await tester.pumpAndSettle();

    // AppBar 제목과 버튼에 같은 문구가 있어 버튼 쪽만 지정
    final submitButton = find.descendant(
      of: find.byType(ElevatedButton),
      matching: find.text('내 식물 등록하기'),
    );
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    final envScreen = tester.widget<PlantRegisterEnvironmentScreen>(
      find.byType(PlantRegisterEnvironmentScreen),
    );
    expect(envScreen.draft.name, '씩씩이');
    expect(envScreen.draft.species.displayName, '바질');
  });

  testWidgets('환경 화면에서 필수값을 비우면 다음으로 넘어가지 않는다', (WidgetTester tester) async {
    final draft = _sampleDraft();

    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterEnvironmentScreen(draft: draft)),
    );

    final nextButton = find.text('다음');
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pump();

    expect(find.text('장소별명, 화분, 위치를 입력해주세요'), findsOneWidget);
    expect(draft.placeName, isNull); // 검증 실패 시 draft를 건드리지 않는다
  });

  testWidgets('성격 화면에서 스와이프로 고른 성격이 draft에 반영되어 꾸미기 화면으로 전달된다', (
    WidgetTester tester,
  ) async {
    final draft = _sampleDraft();

    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterPersonalityScreen(draft: draft)),
    );

    // 기본 첫 페이지는 '활발한 성격'(OUTGOING) — 왼쪽으로 스와이프해 다음 카드('시크한 성격')로
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(draft.personalityType, 'CHIC');
    expect(find.byType(PlantRegisterAppearanceScreen), findsOneWidget);
  });

  testWidgets('꾸미기 화면에서 컬러를 선택하지 않으면 막히고, 선택하면 draft에 반영된다', (
    WidgetTester tester,
  ) async {
    final draft = _sampleDraft();

    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterAppearanceScreen(draft: draft)),
    );

    await tester.tap(find.text('다음'));
    await tester.pump();
    expect(find.text('컬러를 선택해주세요'), findsOneWidget);
    expect(draft.bodyColorId, isNull);

    // 컬러 그리드의 첫 스와치를 선택 (색상 ID로 정확히 지목)
    await tester.tap(find.byKey(const ValueKey('color_orange_01')));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(draft.bodyColorId, isNotNull);
    expect(find.byType(PlantRegisterCompleteScreen), findsOneWidget);
  });

  testWidgets('완성 화면에서 다음을 누르면 등록 스택을 걷어내고 홈으로 이동한다', (
    WidgetTester tester,
  ) async {
    final draft = _sampleDraft()
      ..placeName = '학교'
      ..potType = '플라스틱 화분'
      ..placement = '베란다'
      ..personalityType = 'OUTGOING'
      ..bodyColorId = 'color_orange_01';

    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterCompleteScreen(draft: draft)),
    );

    await tester.tap(find.text('다음'));
    await tester.pump(); // 로딩 상태('등록 중...') 반영
    expect(find.text('등록 중...'), findsOneWidget);

    await tester.pumpAndSettle(); // Future.delayed(400ms) 완료 대기
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('씩씩이의 방'), findsOneWidget);
    expect(find.text('씩씩이의 등록이 완료됐어요'), findsOneWidget);
  });
}
