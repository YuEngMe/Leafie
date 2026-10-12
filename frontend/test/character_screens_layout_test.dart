import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/models/plant_species_candidate.dart';
import 'package:yeso_plant/screens/plant_register_body_screen.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/screens/plant_register_personality_screen.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

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

  testWidgets('성격: 태그 알약 20.67, 꼬리 달린 말풍선, 대사 가운데 532', (tester) async {
    await _pump(tester, PlantRegisterPersonalityScreen(draft: _draft()));
    // 4534:169/171: 58.69x20.67 알약 둘이 y=190, 사이 6.62. 여백으로 크기를
    // 잡을 때는 높이가 24였다.
    final chips = find.ancestor(
      of: find.text('#긍정적'),
      matching: find.byType(Container),
    );
    final chip = tester.getRect(chips.first);
    expect(chip.height, closeTo(20.667, 0.1));
    expect(chip.width, closeTo(58.693, 0.1));
    expect(chip.top, closeTo(190, 1));
    final second = tester.getRect(
      find
          .ancestor(of: find.text('#에너지'), matching: find.byType(Container))
          .first,
    );
    expect(second.left - chip.right, closeTo(6.62, 0.1));
    // 4534:175 말풍선은 위로 꼬리가 난 시안 SVG다. 그림자 여백 포함 위 500.55.
    final bubble = tester.getRect(find.byType(SvgPicture).first);
    expect(bubble.top, closeTo(500.55, 1));
    expect(bubble.center.dx, closeTo(201, 1));
    // 4534:178 대사 글자 가운데 532.23 → Flutter 상자 top 520.73. 옛 구현은
    // 상자 가운데 정렬이라 보이는 글자가 4px 위였다.
    expect(
      tester.getRect(find.text('오늘도 같이 놀자!')).top,
      closeTo(520.73, 0.5),
    );
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

  testWidgets('완료: 앱바 없음, 제목 y=188, 몸통 바닥 597', (tester) async {
    await _pump(tester, PlantRegisterCompleteScreen(draft: _draft()));
    // 시안 4534:812에는 앱바(뒤로가기·'캐릭터 만들기')가 없다(AUTH-ISS-011).
    expect(find.byType(YesoAppBar), findsNothing);
    expect(find.text('캐릭터 만들기'), findsNothing);
    // 시안 글자 상자 188, 보이는 글자 꼭대기 192. Flutter 상자는 글자 위
    // 여백이 6이라 상자를 186에 둔다.
    expect(tester.getRect(find.text('당신의 리피가 완성되었어요!')).top, closeTo(186, 0.5));
    // 광원 4534:832: 408 원, top 251.
    final glow = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).gradient is RadialGradient,
      ),
    );
    expect(glow.top, closeTo(251, 0.5));
    expect(glow.width, closeTo(408, 0.5));
    final art = tester.getRect(find.byType(PlantCharacterArt));
    expect(art.center.dx, _near(201));
    expect(_bodyBottom(art), _near(596.9));
  });
}
