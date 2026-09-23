// 사진 인식 흐름(2318:2815 분석 중, 2318:2890 결과). 좌표와 함께,
// '맞아요'가 인식한 종을 draft로 넘기는지 확인한다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/plant_photo_identify_screen.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
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

    final headline = tester.getRect(find.text('AI가 식물을 분석하고 있어요'));
    expect(headline.top, closeTo(205, 1));
    final subtitle = tester.getRect(find.text('잠시만 기다려주세요..'));
    expect(subtitle.top, closeTo(241, 1));

    // 애니메이션이 도는 채로 테스트를 끝내지 않는다.
    pending.complete(_mockResult);
    await tester.pumpAndSettle();
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
}
