// 식물 등록 마법사가 화면 사이로 값을 잃지 않고 전달하는지 확인한다.
// (POST /plants는 마지막 화면에서 한 번에 보내므로 값 유실이 곧 등록 실패다.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';
import 'package:yeso_plant/widgets/plant_search_components.dart';
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

    // 식물명칭 칸은 readOnly라 탭하면 검색 화면으로 넘어간다
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('바질'));
    await tester.pumpAndSettle();

    final submitButton = find.descendant(
      of: find.byType(ElevatedButton),
      matching: find.text('다음'),
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

  testWidgets('물 준 날을 누르면 시안 휠 피커가 뜨고 고른 날짜가 입력칸에 들어간다', (
    WidgetTester tester,
  ) async {
    final draft = _sampleDraft();

    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterEnvironmentScreen(draft: draft)),
    );

    final field = find.byType(RoundedInputField).at(1);
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();

    // Material 캘린더가 아니라 시안 바텀시트가 떠야 한다.
    expect(find.byType(PlantDatePickerSheet), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);

    // 화면 하단에도 '다음'이 있으므로 시트 안의 것만 누른다.
    await tester.tap(
      find.descendant(
        of: find.byType(PlantDatePickerSheet),
        matching: find.text('다음'),
      ),
    );
    await tester.pumpAndSettle();

    final today = DateTime.now();
    expect(
      find.text('${today.year}년 ${today.month}월 ${today.day}일'),
      findsOneWidget,
    );
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

  testWidgets('꾸미기 화면에서 컬러를 선택하고 중앙 완료점을 누르면 draft에 반영된다', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = _sampleDraft();

    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterAppearanceScreen(draft: draft)),
    );

    expect(draft.bodyColorId, isNull);

    // 반원 팔레트의 첫 스와치를 선택한 뒤 중앙 흰색 완료점으로 확정한다.
    await tester.tap(find.byKey(const ValueKey('color_orange_01')));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('선택 완료'));
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
    expect(find.text('씩씩이 방'), findsOneWidget);
    expect(find.text('좋은 하루야!'), findsOneWidget);
  });
}
