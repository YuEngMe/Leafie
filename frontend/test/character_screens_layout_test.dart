import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/models/plant_species_candidate.dart';
import 'package:yeso_plant/screens/plant_register_body_screen.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/screens/plant_register_personality_screen.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';

/// 캐릭터 등록 화면 3개의 캐릭터 배치를 시안(402×874) 좌표로 고정한다.
/// 헤어는 박스 위로 솟으므로 몸통 박스 바닥으로 위치를 잰다.
/// 몸통 박스 바닥 = 시안 몸통 바닥 + circle PNG 아래 여백(박스 높이의 37/649).

PlantRegistrationDraft _draft() =>
    PlantRegistrationDraft(
        name: '씩씩이',
        species: const PlantSpeciesCandidate(
          referenceId: 'catalog:dracaena-trifasciata',
          displayName: '산세베리아',
          scientificName: 'Dracaena trifasciata',
          categorySuggestion: 'FOLIAGE',
        ),
      )
      ..placeName = '학교'
      ..personalityType = 'OUTGOING'
      ..bodyColorId = 'color_yellow'
      ..headItem = 'hair_pointed_succulent';

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

double _bodyBottom(Rect art) => art.bottom - art.width * 649 / 698 * 37 / 649;

Matcher _near(double v) => closeTo(v, 2);

void main() {
  testWidgets('성격: 몸통 폭 139·바닥 489, 헤어가 태그를 덮지 않는다', (tester) async {
    await _pump(tester, PlantRegisterPersonalityScreen(draft: _draft()));
    final art = tester.getRect(find.byType(PlantCharacterArt).first);
    expect(art.center.dx, _near(201));
    expect(art.width * 0.897, _near(139));
    expect(_bodyBottom(art), _near(488.85));
    final hair = tester.getRect(find.bySemanticsLabel('식물 머리').first);
    final tags = tester.getRect(find.text('#긍정적'));
    // 헤어 PNG는 레이어 렌더 영역을 사방 3 unit 넓혀 뽑아 위쪽이 투명하다.
    // 보이는 그림의 꼭대기는 이미지 사각형보다 3 unit(= 3 × width×0.897/155.23)
    // 아래다.
    final unit = art.width * 0.897 / 155.23;
    expect(hair.top + 3 * unit, greaterThan(tags.bottom));
  });

  testWidgets('외형: 가운데 정렬, 몸통 바닥 489, 인디케이터 y=558', (tester) async {
    await _pump(tester, PlantRegisterBodyScreen(draft: _draft()));
    final art = tester.getRect(find.byType(PlantCharacterArt));
    expect(art.center.dx, _near(201));
    expect(art.width * 0.897, _near(170.44));
    expect(_bodyBottom(art), _near(489));
    final circle = tester.getRect(find.byKey(const ValueKey('body_body_circle')));
    final square = tester.getRect(find.byKey(const ValueKey('body_body_square')));
    expect(circle.top, _near(558));
    expect((circle.center.dx + square.center.dx) / 2, _near(201));
  });

  testWidgets('완료: 제목 y=188, 몸통 바닥 597', (tester) async {
    await _pump(tester, PlantRegisterCompleteScreen(draft: _draft()));
    expect(tester.getRect(find.text('당신의 리피가 완성되었어요!')).top, _near(188));
    final art = tester.getRect(find.byType(PlantCharacterArt));
    expect(art.center.dx, _near(201));
    expect(_bodyBottom(art), _near(596.9));
  });
}
