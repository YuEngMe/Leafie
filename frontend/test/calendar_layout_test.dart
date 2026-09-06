import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/calendar_screen.dart';
import 'package:yeso_plant/services/calendar_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/calendar_pieces.dart';

/// 캘린더 3프레임 회귀 측정.
/// 시안: 월간 `3341:2`, 주간 `2687:15303`, 일정 추가 `3429:1163` (402x874).
void main() {
  group('캘린더 1 · 월간 3341:2', () {
    testWidgets('종이·압정·기간 라벨·꺾쇠 자리', (tester) async {
      await _pumpMonth(tester);

      // 3341:394 종이 380x423 @ (11, 122.96).
      _expectRect(
        tester,
        find.byType(CalendarPaper),
        const Rect.fromLTWH(11, 122.961, 380, 423),
      );

      // 3341:395 압정 그룹 332.876x52 @ (35.06, 110).
      _expectRect(
        tester,
        _svg('calendar_paper_pins.svg'),
        const Rect.fromLTWH(35.063, 110, 332.876, 52),
      );

      // 3341:402 꺾쇠 114.333x10.01 @ (143.348, 149).
      _expectRect(
        tester,
        _svg('calendar_period_chevrons.svg'),
        const Rect.fromLTWH(143.348, 149, 114.333, 10.01),
      );

      // 3341:401 라벨 '2026. 7' 16 SemiBold #444, 중심 (201.45, 154.18).
      final label = _style(tester, '2026. 7');
      expect(label.fontSize, 16);
      expect(label.fontWeight, FontWeight.w600);
      expect(label.color, kTextDark);
      expect(tester.getCenter(find.text('2026. 7')).dx, closeTo(201.45, 1));
    });

    testWidgets('요일 머리글 16 SemiBold, 중심 y=206.79', (tester) async {
      await _pumpMonth(tester);

      // 3341:407 요일 16 SemiBold #FF8834.
      final sunday = tester.widget<Text>(_headerText('일')).style!;
      expect(sunday.fontSize, 16);
      expect(sunday.fontWeight, FontWeight.w600);
      expect(sunday.color, kBrightOrange);

      // 3341:408~414 중심 x = 50.10 / 100.23 / ... / 351.40, 중심 y = 206.79.
      // '월'·'주'는 토글에도 있으니 색으로 요일 머리글만 고른다.
      const centers = [50.10, 100.23, 150.37, 200.50, 250.63, 300.77, 350.90];
      const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
      for (var i = 0; i < 7; i++) {
        final center = tester.getCenter(_headerText(weekdays[i]));
        expect(center.dx, closeTo(centers[i], 1), reason: weekdays[i]);
        expect(center.dy, closeTo(206.79, 1), reason: weekdays[i]);
      }
    });

    testWidgets('격자 셀 50.132x56.525, 선 1px, 날짜 16 SemiBold', (tester) async {
      await _pumpMonth(tester);

      // 3341:415 첫 셀 (26.04, 232.571) 50.132x56.525. 격자선은 kBrightOrange 1px.
      final cells = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border?.top.color ==
                kBrightOrange,
      );
      final first = tester.getRect(cells.first);
      expect(first.left, closeTo(26.04, 1));
      expect(first.top, closeTo(232.571, 1));
      expect(first.width, closeTo(50.132, 1));
      expect(first.height, closeTo(56.525, 1));

      // 격자선 1px (3341:415 border 기본).
      final border =
          (tester.widget<DecoratedBox>(cells.first).decoration as BoxDecoration)
              .border!;
      expect(border.top.width, 1);
      expect(border.top.color, kBrightOrange);

      // 3341:419 날짜 숫자 16 SemiBold, 미선택도 w600.
      final day1 = _style(tester, '1');
      expect(day1.fontSize, 16);
      expect(day1.fontWeight, FontWeight.w600);
      expect(day1.color, kTextDark);

      // 셀 왼쪽 8 / 위 7.762에 22x19 글자칸이 앉는다 → 중심은 셀에서 (19, 17.26).
      // 2026.7.1은 수요일이라 4번째 칸(left 176.436).
      final one = tester.getCenter(find.text('1'));
      expect(one.dx, closeTo(176.436 + 19, 1));
      expect(one.dy, closeTo(232.571 + 17.26, 1));
    });

    testWidgets('일정 있는 날 표식은 종류와 무관하게 물방울 하나', (tester) async {
      await _pumpMonth(tester, items: _twoCards);

      // 3341:426 물방울 17.045x23.729, 15일 셀(176.436, 345.996) 기준 (29.07, 27.59).
      // 2026.7.15는 수요일이라 4번째 열(index 3) = 26.04 + 3*50.132.
      // 분갈이·비료 두 건이 같은 날에 있어도 표식은 하나다.
      final drops = _svg('calendar_day_drop.svg');
      expect(drops, findsOneWidget);
      final drop = tester.getRect(drops);
      expect(drop.left, closeTo(176.436 + 29.07, 1));
      expect(drop.top, closeTo(345.996 + 27.59, 1));
      expect(drop.width, closeTo(17.045, 1));
      expect(drop.height, closeTo(23.729, 1));

      // 날짜 칸에는 일정 종류 아이콘(화분·비료)이 없다 — 카드 쪽에만 있다.
      expect(
        find.descendant(
          of: find.byType(CalendarPaper),
          matching: find.byType(CalendarEventIcon),
        ),
        findsNothing,
      );
    });

    testWidgets('종이에 구겨진 질감을 깐다', (tester) async {
      await _pumpMonth(tester);

      // 3345:633 Mask group `image 309` — 90도 회전 + 20% 불투명도.
      final texture = find.descendant(
        of: find.byType(CalendarPaper),
        matching: find.byType(Image),
      );
      expect(texture, findsOneWidget);
      final image = tester.widget<Image>(texture).image as AssetImage;
      expect(image.assetName, 'assets/images/calendar_paper_texture.png');
      expect(
        tester.widget<Opacity>(
          find.ancestor(of: texture, matching: find.byType(Opacity)).first,
        ).opacity,
        0.2,
      );
    });

    testWidgets('오늘 할 일 제목과 카드 두 장', (tester) async {
      await _pumpMonth(tester, items: _twoCards);

      // 3341:362 제목 (35, 564.195) 16 SemiBold.
      final title = tester.getRect(find.text('오늘 할 일'));
      expect(title.left, closeTo(35, 1));
      expect(title.top, closeTo(564.195, 2));
      expect(_style(tester, '오늘 할 일').fontWeight, FontWeight.w600);

      // 3429:677 카드1 374x51 @ (13, 588.195), 3429:689 카드2 y=653.195 → 간격 14.
      final cards = find.byType(CalendarEventCard);
      expect(cards, findsNWidgets(2));
      final card1 = tester.getRect(cards.at(0));
      final card2 = tester.getRect(cards.at(1));
      expect(card1.left, closeTo(13, 1));
      expect(card1.top, closeTo(588.195, 1));
      expect(card1.width, closeTo(374, 1));
      expect(card1.height, 51);
      expect(card2.top - card1.bottom, closeTo(14, 0.5));
    });

    testWidgets('카드 속 글자·아이콘·완료 표식 자리', (tester) async {
      await _pumpMonth(tester, items: _twoCards);

      // 3429:678 제목 #1F2E21 16 Medium, x=108.29 (카드 left 13 + 95.29).
      final cardTitle = _style(tester, '분갈이');
      expect(cardTitle.color, kCalendarCardTitle);
      expect(cardTitle.fontSize, 16);
      expect(cardTitle.fontWeight, FontWeight.w500);
      expect(tester.getRect(find.text('분갈이')).left, closeTo(108.29, 1));

      // 3429:679 날짜 12 Regular #A1A1A1, x=227.15.
      final dateStyle = _style(tester, '2026. 7.15 수');
      expect(dateStyle.fontSize, 12);
      expect(dateStyle.color, kTextLight);
      expect(
        tester.getRect(find.text('2026. 7.15 수').first).left,
        closeTo(227.15, 1),
      );

      // 3429:680 분갈이 아이콘 26x24.10 @ x=33 / 3429:695 비료 19x30.59 @ x=37.
      final icons = find.descendant(
        of: find.byType(CalendarEventCard),
        matching: find.byType(CalendarEventIcon),
      );
      final repotIcon = tester.getRect(icons.at(0));
      expect(repotIcon.left, closeTo(33, 1));
      expect(repotIcon.width, closeTo(26, 1));
      final fertilizeIcon = tester.getRect(icons.at(1));
      expect(fertilizeIcon.left, closeTo(37, 1));
      expect(fertilizeIcon.width, closeTo(19, 1));

      // 3429:713 완료 원 26x26 @ x=349 (카드 left + 336).
      final mark = tester.getRect(find.byType(CalendarCompleteMark).first);
      expect(mark.left, closeTo(349, 1));
      expect(mark.width, 26);
      expect(mark.height, 26);
    });

    testWidgets('월/주 토글은 정원이 아니라 알약, 우하단 + 는 45x45 @ (342,730)', (
      tester,
    ) async {
      await _pumpMonth(tester);

      // 3341:483 토글 48x24.923 @ (335, 58).
      _expectRect(
        tester,
        find.byType(CalendarModeSwitch),
        const Rect.fromLTWH(335, 58, 48, 24.923),
      );
      // 3341:487 '월' 11x14 @ (342, 63) / 3341:488 '주' @ (365, 63).
      // 토글 안쪽 글자만 고른다(요일 머리글에도 같은 글자가 있다).
      Finder inSwitch(String label) => find.descendant(
        of: find.byType(CalendarModeSwitch),
        matching: find.text(label),
      );
      expect(tester.getRect(inSwitch('월')).left, closeTo(342, 1));
      expect(tester.getRect(inSwitch('주')).left, closeTo(365, 1));

      // 3341:493 FAB. SVG 캔버스 52.833에 그림자 여백 3.917이 있어
      // 실제 원은 (342, 730) 45x45에 앉는다.
      final fab = tester.getRect(find.byKey(const ValueKey('calendar-add')));
      expect(fab.left + 3.917, closeTo(342, 1));
      expect(fab.top + 3.917, closeTo(730, 1));
      expect(fab.width - 7.834, closeTo(45, 1));

      // 3345:667 화면 제목 '캘린더'는 16 Medium (21이면 시안 폭 43을 넘는다).
      final screenTitle = _style(tester, '캘린더');
      expect(screenTitle.fontSize, 16);
      expect(tester.getRect(find.text('캘린더')).width, lessThan(50));
    });
  });

  group('캘린더 2 · 주간 2687:15303', () {
    testWidgets('종이 379x165 @ (11,132), 압정 342x39 @ (30,120)', (tester) async {
      await _pumpWeek(tester);

      _expectRect(
        tester,
        find.byType(CalendarPaper),
        const Rect.fromLTWH(11, 132, 379, 165),
      );
      _expectRect(
        tester,
        _svg('calendar_paper_pins_week.svg'),
        const Rect.fromLTWH(30, 120, 342, 39),
      );
      // 2687:15580 꺾쇠 @ (144, 155), 2687:15579 라벨 중심 x=201.45.
      _expectRect(
        tester,
        _svg('calendar_period_chevrons.svg'),
        const Rect.fromLTWH(144, 155, 114.333, 10.01),
      );
      expect(tester.getCenter(find.text('2026. 7')).dx, closeTo(201.45, 1));
    });

    testWidgets('요일 y=186, 날짜 셀 (26, 222.571) 50x56.525', (tester) async {
      await _pumpWeek(tester);

      // 3345:528 요일 (43, 186) 14x21.571 → 중심 (50, 196.79).
      final sunday = tester.getCenter(_headerText('일'));
      expect(sunday.dx, closeTo(50, 1));
      expect(sunday.dy, closeTo(196.79, 1));
      expect(tester.widget<Text>(_headerText('일')).style!.fontSize, 16);

      // 3345:511 날짜 숫자 16 SemiBold, 셀 왼쪽 8 / 위 7.762.
      final twelve = _style(tester, '12');
      expect(twelve.fontSize, 16);
      expect(twelve.fontWeight, FontWeight.w600);
      // 3345:510 첫 셀 (26, 222.571) → 글자칸 중심 (26+19, 222.571+17.26).
      final center = tester.getCenter(find.text('12'));
      expect(center.dx, closeTo(45, 1));
      expect(center.dy, closeTo(239.83, 1));
    });

    testWidgets('아젠다 헤딩 y=327, 첫 카드 y=351, 같은 날 카드 간격 14', (tester) async {
      await _pumpWeek(tester, items: _weekCards);

      // 2687:17819 헤딩 (35, 327) / 2687:17820 카드 (14, 351).
      final heading = tester.getRect(find.text('2026. 7.14 화').first);
      expect(heading.left, closeTo(35, 1));
      expect(heading.top, closeTo(327, 2));

      final cards = find.byType(CalendarEventCard);
      final first = tester.getRect(cards.at(0));
      expect(first.left, closeTo(14, 1));
      expect(first.top, closeTo(351, 2));
      expect(first.width, closeTo(374, 1));

      // 2687:15624 y=466 → 2687:15645 y=531, 카드 51 → 간격 14.
      final second = tester.getRect(cards.at(1));
      final third = tester.getRect(cards.at(2));
      expect(third.top - second.bottom, closeTo(14, 0.5));

      // 카드 바닥 402 → 다음 헤딩 442 = 40.
      final nextHeading = tester.getRect(find.text('2026. 7.15 수').first);
      expect(nextHeading.top - first.bottom, closeTo(40, 2));
    });

    testWidgets('완료 표식은 체크(V)가 아니라 꺾쇠, 미완료는 빈 흰 원', (tester) async {
      await _pumpWeek(tester, items: _weekCards);

      // 3429:619 완료는 오렌지 원 + 흰 꺾쇠, 3429:632 미완료는 흰 원.
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      final marks = find.byType(CalendarCompleteMark);
      final incomplete = tester.widget<CalendarCompleteMark>(marks.at(0));
      expect(incomplete.completed, isFalse);
      final done = tester.widget<CalendarCompleteMark>(marks.at(1));
      expect(done.completed, isTrue);

      // 두 상태 모두 흰 카드 위에서 보여야 한다: 미완료는 테두리로, 완료는 채움으로.
      BoxDecoration decorationOf(int index) =>
          tester.widget<DecoratedBox>(find.descendant(
            of: marks.at(index),
            matching: find.byType(DecoratedBox),
          )).decoration as BoxDecoration;
      expect(decorationOf(0).color, Colors.white);
      expect(decorationOf(0).border, isNotNull);
      expect(decorationOf(1).color, kOrangeMain);
    });
  });

  group('캘린더 3 · 일정 추가 3429:1163', () {
    testWidgets('떠 있는 334x180 카드 + 확인 버튼 334x51 @ (34,790)', (tester) async {
      await _openSheet(tester);

      // 3429:1596 카드 334x180 @ (34, 590) — 바닥에 붙는 시트가 아니다.
      final card = tester.getRect(find.byType(ClipRRect).first);
      expect(card.left, closeTo(34, 1));
      expect(card.top, closeTo(590, 1));
      expect(card.width, closeTo(334, 1));
      expect(card.height, closeTo(180, 1));

      // 3429:1594 확인 버튼 334x51 @ (34, 790), 문구 `확인`.
      final confirm = tester.getRect(
        find.byKey(const ValueKey('calendar-new-event-confirm')),
      );
      expect(confirm.left, closeTo(34, 1));
      expect(confirm.top, closeTo(790, 1));
      expect(confirm.width, closeTo(334, 1));
      expect(confirm.height, closeTo(51, 1));
      expect(find.text('확인'), findsOneWidget);
      expect(find.text('등록하기'), findsNothing);
    });

    testWidgets('3열 휠 + 노란 강조 알약 230x40 @ (53,660)', (tester) async {
      await _openSheet(tester);

      // 3429:1609/1618/1613 세 줄이 년·월·일 세 열에 보인다.
      expect(find.text('2026년'), findsOneWidget);
      expect(find.text('7월'), findsOneWidget);
      expect(find.text('15일'), findsOneWidget);
      // Material 날짜 다이얼로그를 쓰지 않는다.
      expect(find.byType(DatePickerDialog), findsNothing);

      // 3429:1617 강조 알약 230x40 @ (53, 660).
      final highlight = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                kCalendarWheelHighlight,
      );
      final rect = tester.getRect(highlight);
      expect(rect.left, closeTo(53, 1));
      expect(rect.top, closeTo(660, 1));
      expect(rect.width, closeTo(230, 1));
      expect(rect.height, closeTo(40, 1));

      // 3429:1618 선택 줄 18 SemiBold #444, 3429:1610 나머지 16 Medium #A1A1A1.
      final selected = _style(tester, '2026년');
      expect(selected.fontSize, 18);
      expect(selected.fontWeight, FontWeight.w600);
      expect(selected.color, kTextDark);
      final dimmed = _style(tester, '2025년');
      expect(dimmed.fontSize, 16);
      expect(dimmed.color, kTextLight);
    });

    testWidgets('일정 종류는 우측 세로 아이콘 2개 (분갈이·비료)', (tester) async {
      await _openSheet(tester);

      // 3429:1707 / 3429:1715 — 49x49 @ x=301, y=619 / 685.09.
      final repot = tester.getRect(
        find.byKey(const ValueKey('calendar-type-REPOTTING')),
      );
      expect(repot.left, closeTo(301, 1));
      expect(repot.top, closeTo(619, 1));
      expect(repot.width, closeTo(49, 1));
      final fertilize = tester.getRect(
        find.byKey(const ValueKey('calendar-type-FERTILIZING')),
      );
      expect(fertilize.left, closeTo(301, 1));
      expect(fertilize.top, closeTo(685.09, 1));

      // 시안에 없는 것들은 사라졌다.
      expect(find.text('일정 추가'), findsNothing);
      expect(find.text('가지치기'), findsNothing);
      expect(find.text('비료 주기'), findsNothing);
    });
  });
}

// ---- 도우미 ----------------------------------------------------------------

const _twoCards = [
  ('repot-1', 'REPOTTING', '분갈이', 15, 'SCHEDULED'),
  ('fertilize-1', 'FERTILIZING', '비료 주기', 15, 'SCHEDULED'),
];

const _weekCards = [
  ('repot-14', 'REPOTTING', '분갈이', 14, 'SCHEDULED'),
  ('repot-15', 'REPOTTING', '분갈이', 15, 'COMPLETED'),
  ('fertilize-15', 'FERTILIZING', '비료 주기', 15, 'COMPLETED'),
];

Future<void> _pumpMonth(
  WidgetTester tester, {
  List<(String, String, String, int, String)> items = const [],
}) async {
  await _pump(tester, items);
}

Future<void> _pumpWeek(
  WidgetTester tester, {
  List<(String, String, String, int, String)> items = const [],
}) async {
  await _pump(tester, items);
  await tester.tap(find.byKey(const ValueKey('calendar-mode-week')));
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await _pump(tester, const []);
  await tester.tap(find.byKey(const ValueKey('calendar-add')));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  List<(String, String, String, int, String)> items,
) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: CalendarScreen(
        plantId: 'plant-1',
        plantName: '새싹이',
        repository: _StubRepository(items),
        today: DateTime(2026, 7, 15),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _svg(String assetName) => find.byWidgetPredicate(
  (widget) =>
      widget.runtimeType.toString() == 'SvgPicture' &&
      widget.toString().contains(assetName),
);

/// 요일 머리글만 고른다. '월'·'주'는 토글에도 있어 글자만으로는 안 갈린다.
Finder _headerText(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data == label &&
      widget.style?.color == kBrightOrange,
);

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style!;

void _expectRect(WidgetTester tester, Finder finder, Rect expected) {
  final actual = tester.getRect(finder.first);
  expect(actual.left, closeTo(expected.left, 1), reason: 'left');
  expect(actual.top, closeTo(expected.top, 1), reason: 'top');
  expect(actual.width, closeTo(expected.width, 1), reason: 'width');
  expect(actual.height, closeTo(expected.height, 1), reason: 'height');
}

class _StubRepository implements CalendarRepository {
  _StubRepository(this.rows);

  final List<(String, String, String, int, String)> rows;

  @override
  Future<List<CalendarItemData>> listCalendar(
    String plantId,
    DateTime from,
    DateTime to, {
    Iterable<String>? types,
  }) async => [
    for (final (id, type, title, day, status) in rows)
      CalendarItemData(
        id: id,
        date: DateTime(2026, 7, day),
        type: type,
        status: status,
        viewStatus: 'UPCOMING',
        title: title,
        source: 'USER',
        conditionScore: null,
        conditionLevel: null,
        completable: status != 'COMPLETED',
      ),
  ];

  @override
  Future<void> completeEvent(String eventId, {DateTime? performedOn}) async {}

  @override
  Future<void> createEvent(
    String plantId, {
    required String type,
    required String title,
    required DateTime dueDate,
  }) async {}
}
