import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/models/plant_species_candidate.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/screens/plant_register_personality_screen.dart';
import 'package:yeso_plant/services/registration_draft_store.dart';

PlantRegistrationDraft _draft() =>
    PlantRegistrationDraft(
        name: '씩씩이',
        species: const PlantSpeciesCandidate(
          referenceId: 'catalog:ocimum-basilicum',
          displayName: '바질',
          scientificName: 'Ocimum basilicum',
          categorySuggestion: 'HERB',
        ),
        clientRegistrationId: 'reg-1',
        startedOn: DateTime(2026, 9, 20),
        speciesIdentificationId: 'ident-1',
      )
      ..placeName = '베란다'
      ..lastWateredOn = DateTime(2026, 9, 18)
      ..personalityType = 'OUTGOING'
      ..bodyId = 'body_square'
      ..bodyColorId = 'color_yellow'
      ..headItem = 'hair_sprout';

void main() {
  const store = RegistrationDraftStore();

  test('저장한 단계와 입력값을 그대로 되살린다', () async {
    await store.save(RegistrationStep.body, _draft());

    final saved = await store.load();

    expect(saved!.step, RegistrationStep.body);
    final draft = saved.draft!;
    expect(draft.name, '씩씩이');
    expect(draft.species.referenceId, 'catalog:ocimum-basilicum');
    expect(draft.species.categorySuggestion, 'HERB');
    expect(draft.clientRegistrationId, 'reg-1');
    // 아직 보낸 적 없으면 이어하는 날을 1일차로 삼는다.
    final today = DateTime.now();
    expect(draft.startedOn.year, today.year);
    expect(draft.startedOn.month, today.month);
    expect(draft.startedOn.day, today.day);
    expect(draft.submissionSnapshot, isNull);
    expect(draft.speciesIdentificationId, 'ident-1');
    expect(draft.placeName, '베란다');
    expect(draft.lastWateredOn, DateTime(2026, 9, 18));
    expect(draft.lastRepottedOn, isNull);
    expect(draft.personalityType, 'OUTGOING');
    expect(draft.bodyId, 'body_square');
    expect(draft.bodyColorId, 'color_yellow');
    expect(draft.headItem, 'hair_sprout');
  });

  test('한 번 보낸 등록은 그 요청 본문을 그대로 되살린다', () async {
    final draft = _draft();
    draft.freezeForSubmission();
    // 응답을 못 받은 뒤 사용자가 색을 바꿨다.
    draft.bodyColorId = 'color_pink';
    await store.save(RegistrationStep.complete, draft);

    final restored = (await store.load())!.draft!;
    final snapshot = restored.freezeForSubmission();

    expect(snapshot.clientRegistrationId, 'reg-1');
    expect(snapshot.bodyColorId, 'color_yellow');
    expect(snapshot.startedOn, DateTime(2026, 9, 20));
    expect(snapshot.lastWateredOn, DateTime(2026, 9, 18));
    expect(snapshot.speciesIdentificationId, 'ident-1');
    expect(restored.startedOn, DateTime(2026, 9, 20));
  });

  test('종을 고르기 전이면 애칭만 되살린다', () async {
    await store.saveName('쑥쑥이');

    final saved = await store.load();

    expect(saved!.step, RegistrationStep.species);
    expect(saved.name, '쑥쑥이');
    expect(saved.draft, isNull);
  });

  test('저장 형식이 깨졌으면 버리고 처음부터 하게 한다', () async {
    SharedPreferences.setMockInitialValues({
      'plant_registration_draft_v1': '{not json',
    });

    expect(await store.load(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('plant_registration_draft_v1'), isNull);
  });

  group('이름 화면에서 이어하기를 묻는다', () {
    Future<void> openNameScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await store.save(RegistrationStep.personality, _draft());
      await tester.pumpWidget(
        const MaterialApp(home: PlantRegisterNameScreen()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('이어서 하기를 누르면 멈춘 단계로 간다', (tester) async {
      await openNameScreen(tester);
      expect(find.text('작성하던 식물 등록이 있어요'), findsOneWidget);

      await tester.tap(find.text('이어서 하기'));
      await tester.pumpAndSettle();

      expect(find.byType(PlantRegisterPersonalityScreen), findsOneWidget);
    });

    testWidgets('새로 시작을 누르면 저장한 내용을 지운다', (tester) async {
      await openNameScreen(tester);

      await tester.tap(find.text('새로 시작'));
      await tester.pumpAndSettle();

      expect(find.byType(PlantRegisterPersonalityScreen), findsNothing);
      expect(await store.load(), isNull);
    });

    testWidgets('저장한 내용이 없으면 묻지 않는다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PlantRegisterNameScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('작성하던 식물 등록이 있어요'), findsNothing);
    });
  });

  testWidgets('등록이 끝나면 저장한 내용을 지운다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PlantRegisterCompleteScreen(
          draft: _draft(),
          submit: (_) async => 'plant-1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect((await store.load())!.step, RegistrationStep.complete);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(await store.load(), isNull);
  });
}
