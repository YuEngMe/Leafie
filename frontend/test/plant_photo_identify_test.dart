// 사진 인식 흐름(4889:421 분석 중, 2318:2890 결과). 좌표와 함께,
// '맞아요'가 인식한 종을 draft로 넘기는지 확인한다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/plant_photo_identify_screen.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/plant_search_components.dart';

/// 시안이 보여주는 인식 결과.
const _mockResult = PlantIdentification(
  candidate: PlantSpeciesCandidate(
    referenceId: 'catalog:sedum-polytrichoides',
    displayName: '바위채송화',
    scientificName: 'Sedum polytrichoides',
    categorySuggestion: 'SUCCULENT',
  ),
  familyName: '돌나무과',
  bloomSeason: '8월 ~ 9월',
  identificationId: 'identification-id',
  mediaFileId: 'media-id',
);

/// 사진 자체는 화면에 안 그려져도 되지만 File은 실재해야 한다.
final _photo = File('assets/images/character/body_circle_yellow.png');

Widget _screen({PlantIdentifier? identifier}) => MaterialApp(
  home: PlantPhotoIdentifyScreen(
    photo: _photo,
    name: '씩씩이',
    identifier: identifier ?? (_) async => _mockResult,
  ),
);

void _setUpView(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('분석 중 화면이 시안 좌표에 앉는다', (tester) async {
    _setUpView(tester);
    // 완료되지 않는 Future로 분석 중 상태를 붙잡는다.
    final pending = Completer<PlantIdentification>();
    await tester.pumpWidget(_screen(identifier: (_) => pending.future));
    await tester.pump();

    // 시안 4889:421. 옛 시안(2318:2815)의 문구 y=205·진행 막대·앱바 제목은
    // 최신 시안에서 빠지고, 캐릭터 셋 아래 화면 가운데쯤으로 문구가 내려왔다.
    final headline = tester.getRect(find.text('AI가 식물을 분석하고 있어요'));
    // 4889:442 x=80. 글자 상자 top 456이면 보이는 글자가 시안 렌더(461)에 앉는다.
    expect(headline.left, closeTo(80, 1));
    expect(headline.top, closeTo(456, 1));
    // 4889:443 중심 x=202.5.
    final subtitle = tester.getRect(find.text('잠시만 기다려주세요..'));
    expect(subtitle.center.dx, closeTo(202.5, 1));
    expect(subtitle.top, closeTo(492, 1));
    // 4889:445 캐릭터 묶음 x=129 y=363, 144x42.4.
    final characters = tester.getRect(
      find.byKey(const ValueKey('analyzing-characters')),
    );
    expect(characters.left, closeTo(129, 0.5));
    expect(characters.top, closeTo(363, 0.5));
    expect(characters.width, closeTo(144, 0.5));
    expect(characters.height, closeTo(42.4, 0.5));
    // 앱바는 꺾쇠만 있고 제목이 없다.
    expect(find.text('내 식물 등록하기'), findsNothing);
    expect(find.byType(FigmaBackChevron), findsOneWidget);

    // 결과가 오면 제목이 있는 결과 화면으로 바뀐다.
    pending.complete(_mockResult);
    await tester.pumpAndSettle();
    expect(find.text('내 식물 등록하기'), findsOneWidget);
  });

  testWidgets('결과 화면이 시안 좌표에 앉는다', (tester) async {
    _setUpView(tester);
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('이 식물은 바위채송화이군요?')).top, closeTo(169, 1));
    expect(
      tester.getRect(find.byType(PlantResultCard)).top,
      closeTo(238.62, 1),
    );
    expect(
      tester.getRect(find.byType(PlantResultConfirmButtons)).top,
      closeTo(759, 1),
    );
  });

  testWidgets('인식 결과의 이름과 분류가 카드에 뜬다', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    expect(find.text('바위채송화'), findsWidgets);
    expect(find.text('돌나무과'), findsOneWidget);
    expect(find.text('8월 ~ 9월'), findsOneWidget);
  });

  testWidgets('맞아요를 누르면 인식한 종으로 환경 화면에 간다', (tester) async {
    // 버튼이 y=759라 기본 테스트 화면(600x800) 밖이다.
    _setUpView(tester);
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('맞아요'));
    await tester.pumpAndSettle();

    final env = tester.widget<PlantRegisterEnvironmentScreen>(
      find.byType(PlantRegisterEnvironmentScreen),
    );
    expect(env.draft.name, '씩씩이');
    expect(env.draft.species.displayName, '바위채송화');
    expect(env.draft.species.referenceId, 'catalog:sedum-polytrichoides');
    expect(env.draft.speciesIdentificationId, 'identification-id');
    expect(env.draft.primaryMediaFileId, 'media-id');
  });

  testWidgets('인식에 실패하면 안내를 띄운다', (tester) async {
    await tester.pumpWidget(
      _screen(identifier: (_) async => throw Exception('boom')),
    );
    await tester.pumpAndSettle();

    expect(find.text('사진으로 찾지 못했어요'), findsOneWidget);
    expect(find.byType(PlantResultCard), findsNothing);
  });

  testWidgets('결과 카드는 아래에서 떠오르며 나타난다', (tester) async {
    _setUpView(tester);
    final pending = Completer<PlantIdentification>();
    await tester.pumpWidget(_screen(identifier: (_) => pending.future));
    await tester.pump();

    pending.complete(_mockResult);
    await tester.pump(); // 결과로 바뀐 첫 프레임
    await tester.pump(const Duration(milliseconds: 50));
    final card = find.byKey(const ValueKey('identify-result-card'));
    Opacity opacityOf() => tester.widget<Opacity>(
      find.descendant(of: card, matching: find.byType(Opacity)).first,
    );
    double dyOf() => tester
        .widget<Transform>(
          find.descendant(of: card, matching: find.byType(Transform)).first,
        )
        .transform
        .getTranslation()
        .y;
    expect(opacityOf().opacity, lessThan(1));
    expect(dyOf(), greaterThan(0), reason: '아직 아래에 있다');

    await tester.pumpAndSettle();
    expect(opacityOf().opacity, 1);
    expect(dyOf(), 0);
  });

  testWidgets('모션을 끄면 결과 카드는 움직이지 않고 페이드만 한다', (tester) async {
    _setUpView(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final pending = Completer<PlantIdentification>();
    await tester.pumpWidget(_screen(identifier: (_) => pending.future));
    await tester.pump();
    pending.complete(_mockResult);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final card = find.byKey(const ValueKey('identify-result-card'));
    final translation = tester
        .widget<Transform>(
          find.descendant(of: card, matching: find.byType(Transform)).first,
        )
        .transform
        .getTranslation();
    expect(translation.y, 0);
  });
}
