// 식물 등록 마법사가 화면 사이로 값을 잃지 않고 전달하는지 확인한다.
// (POST /plants는 마지막 화면에서 한 번에 보내므로 값 유실이 곧 등록 실패다.)

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/plant_photo_identify_screen.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_register_body_screen.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';
import 'package:yeso_plant/widgets/plant_search_components.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/screens/plant_register_personality_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_api.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

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
  testWidgets('애칭을 넣고 종을 고르면 환경 화면으로 draft가 전달된다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PlantRegisterNameScreen()));

    // 시안 2315:2189는 애칭 한 칸만 받는다.
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '씩씩이');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // 종은 다음 화면에서 고른다(2315:2515).
    expect(find.byType(PlantSpeciesSearchScreen), findsOneWidget);
    await tester.tap(find.text('바질'));
    await tester.pump();

    // 고르기만 해서는 넘어가지 않고 '다음'을 눌러야 한다.
    expect(find.byType(PlantRegisterEnvironmentScreen), findsNothing);
    await tester.tap(find.text('다음'));
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

    expect(find.text('장소를 입력해주세요'), findsOneWidget);
    expect(draft.placeName, isNull); // 검증 실패 시 draft를 건드리지 않는다
  });

  testWidgets('물 준 날을 누르면 시안 휠 피커가 뜨고 고른 날짜가 입력칸에 들어간다', (
    WidgetTester tester,
  ) async {
    final draft = _sampleDraft();

    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterEnvironmentScreen(draft: draft)),
    );

    // Center가 들어가며 RoundedInputField 전체가 탭 영역이 아니게 됐다.
    final field = find.descendant(
      of: find.byType(RoundedInputField).at(1),
      matching: find.byType(TextField),
    );
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

  testWidgets('장소만 입력하고 물 준 날을 고르지 않으면 다음으로 넘어가지 않는다', (
    WidgetTester tester,
  ) async {
    final draft = _sampleDraft();
    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterEnvironmentScreen(draft: draft)),
    );
    await tester.enterText(find.byType(TextField).first, '학교');
    await tester.tap(find.text('다음'));
    await tester.pump();

    expect(find.text('마지막 물 준 날을 선택해주세요'), findsOneWidget);
    expect(find.byType(PlantRegisterPersonalityScreen), findsNothing);
  });

  testWidgets('늦게 끝난 이전 검색은 최신 검색 결과를 덮어쓰지 않는다', (WidgetTester tester) async {
    final first = Completer<List<PlantSpeciesCandidate>>();
    final second = Completer<List<PlantSpeciesCandidate>>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PlantSpeciesSearchScreen(
          search: (_) => calls++ == 0 ? first.future : second.future,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '첫검색');
    await tester.tap(find.byType(FigmaSearchIcon));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '둘검색');
    await tester.tap(find.byType(FigmaSearchIcon));
    second.complete(const [
      PlantSpeciesCandidate(
        referenceId: 'catalog:latest',
        displayName: '최신 결과',
        scientificName: 'Latest species',
        categorySuggestion: 'FOLIAGE',
      ),
    ]);
    await tester.pump();
    first.complete(const [
      PlantSpeciesCandidate(
        referenceId: 'catalog:stale',
        displayName: '이전 결과',
        scientificName: 'Stale species',
        categorySuggestion: 'FOLIAGE',
      ),
    ]);
    await tester.pump();

    expect(find.text('최신 결과'), findsOneWidget);
    expect(find.text('이전 결과'), findsNothing);
  });

  testWidgets('카메라 사진을 고르면 식물 인식 화면으로 간다', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlantSpeciesSearchScreen(
          name: '씩씩이',
          photoPicker: () async => File('assets/images/body_circle.png'),
        ),
      ),
    );

    await tester.tap(find.byType(FigmaCameraIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PlantPhotoIdentifyScreen), findsOneWidget);
  });

  testWidgets('카메라를 쓸 수 없으면 한국어 안내 후 갤러리로 계속한다', (WidgetTester tester) async {
    var cameraCalls = 0;
    var galleryCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PlantSpeciesSearchScreen(
          name: '씩씩이',
          cameraAvailability: () => false,
          photoPicker: () async {
            cameraCalls++;
            return null;
          },
          galleryPhotoPicker: () async {
            galleryCalls++;
            return File('assets/images/body_circle.png');
          },
        ),
      ),
    );

    await tester.tap(find.byType(FigmaCameraIcon));
    await tester.pumpAndSettle();

    expect(find.text('카메라를 사용할 수 없어요'), findsOneWidget);
    expect(find.text('갤러리에서 선택'), findsOneWidget);
    expect(cameraCalls, 0);

    await tester.tap(find.text('갤러리에서 선택'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(galleryCalls, 1);
    expect(find.byType(PlantPhotoIdentifyScreen), findsOneWidget);
  });

  testWidgets('카메라 권한 거절은 설정 안내와 갤러리 대안을 보여준다', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlantSpeciesSearchScreen(
          name: '씩씩이',
          cameraAvailability: () => true,
          photoPicker: () async =>
              throw PlatformException(code: 'camera_access_denied'),
        ),
      ),
    );

    await tester.tap(find.byType(FigmaCameraIcon));
    await tester.pumpAndSettle();

    expect(find.text('카메라 권한이 필요해요'), findsOneWidget);
    expect(find.textContaining('설정에서 카메라 권한을 허용'), findsOneWidget);
    expect(find.text('갤러리에서 선택'), findsOneWidget);
  });

  testWidgets('예상하지 못한 카메라 오류도 재시도와 갤러리 대안을 보여준다', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlantSpeciesSearchScreen(
          name: '씩씩이',
          cameraAvailability: () => true,
          photoPicker: () async =>
              throw PlatformException(code: 'unknown_camera_error'),
        ),
      ),
    );

    await tester.tap(find.byType(FigmaCameraIcon));
    await tester.pumpAndSettle();

    expect(find.text('카메라를 열지 못했어요'), findsOneWidget);
    expect(find.textContaining('잠시 후 다시 시도'), findsOneWidget);
    expect(find.text('갤러리에서 선택'), findsOneWidget);
  });

  testWidgets('성격 화면에서 스와이프로 고른 성격이 draft에 반영되어 바디 선택 화면으로 전달된다', (
    WidgetTester tester,
  ) async {
    final draft = _sampleDraft();

    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterPersonalityScreen(draft: draft)),
    );

    // 기본 첫 페이지는 '활발한 성격'(OUTGOING) — 왼쪽으로 스와이프해 다음 카드('시크한 성격')로
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    // 성격 화면의 하단 버튼 문구는 시안(4534:195)대로 '선택'이다.
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();

    expect(draft.personalityType, 'CHIC');
    // #84: 성격 다음은 바디 선택(step 5). 색선택은 그 뒤로 밀렸다.
    expect(find.byType(PlantRegisterBodyScreen), findsOneWidget);
  });

  testWidgets('바디 선택 화면에서 바디를 고르고 완료하면 draft에 반영되어 꾸미기 화면으로 전달된다', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = _sampleDraft();

    await tester.pumpWidget(
      MaterialApp(home: PlantRegisterBodyScreen(draft: draft)),
    );

    // 기본 선택은 body_circle. 통통이(body_thumb) 실루엣 인디케이터를 탭해 바꾼다.
    await tester.tap(find.bySemanticsLabel('통통이').first);
    await tester.pumpAndSettle();

    // 시안 5108:721대로 확정 버튼 문구는 '선택'이다.
    await tester.tap(find.bySemanticsLabel('선택'));
    await tester.pumpAndSettle();

    expect(draft.bodyId, 'body_thumb');
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

    // 반원 팔레트의 첫 스와치(lemon)를 선택한 뒤 중앙 흰색 완료점으로 확정한다.
    await tester.tap(find.byKey(const ValueKey('color_yellow')));
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
      ..personalityType = 'OUTGOING'
      ..bodyColorId = 'color_orange';

    await tester.pumpWidget(
      MaterialApp(
        home: PlantRegisterCompleteScreen(
          draft: draft,
          // Supabase를 초기화하지 않으므로 저장은 흉내만 낸다.
          submit: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 400));
            return 'test-plant-id';
          },
        ),
      ),
    );

    await tester.tap(find.text('다음'));
    await tester.pump(); // 로딩 상태('등록 중...') 반영
    expect(find.text('등록 중...'), findsOneWidget);

    await tester.pumpAndSettle(); // Future.delayed(400ms) 완료 대기
    expect(find.byType(HomeScreen), findsOneWidget);

    // 이름과 D+는 홈이 세션에서 직접 읽는다. 여기는 Supabase가 없어
    // 등록 전 화면이 뜨고, 실제 값 표시는 home_screen_test.dart가 본다.
    expect(find.byType(PlantRegisterCompleteScreen), findsNothing);
  });

  testWidgets('재시도 중 draft가 바뀌어도 홈은 서버에 보낸 snapshot을 표시한다', (
    WidgetTester tester,
  ) async {
    final draft = _sampleDraft()
      ..placeName = '학교'
      ..lastWateredOn = DateTime.now()
      ..personalityType = 'OUTGOING'
      ..bodyColorId = 'color_orange';
    await tester.pumpWidget(
      MaterialApp(
        home: PlantRegisterCompleteScreen(
          draft: draft,
          submit: (submittedDraft) async {
            buildPlantCreateRequest(submittedDraft);
            submittedDraft.personalityType = 'CHIC';
            return 'test-plant-id';
          },
        ),
      ),
    );

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-environment-collapse')));
    await tester.pump();

    expect(find.text('신난다'), findsNothing);
    expect(find.text('별로야'), findsNothing);
  });

  testWidgets('등록 API 오류가 나면 화면에 남아 서버 메시지를 보여준다', (WidgetTester tester) async {
    final draft = _sampleDraft()
      ..placeName = '학교'
      ..lastWateredOn = DateTime(2026, 9, 5)
      ..personalityType = 'OUTGOING'
      ..bodyColorId = 'color_orange';
    await tester.pumpWidget(
      MaterialApp(
        home: PlantRegisterCompleteScreen(
          draft: draft,
          submit: (_) async => throw const LeafieApiException(
            code: 'SPECIES_NOT_FOUND',
            message: '지원하는 식물을 찾을 수 없습니다.',
            statusCode: 404,
          ),
        ),
      ),
    );

    await tester.tap(find.text('다음'));
    await tester.pump();

    expect(find.byType(PlantRegisterCompleteScreen), findsOneWidget);
    expect(find.text('지원하는 식물을 찾을 수 없습니다.'), findsOneWidget);
  });
}
