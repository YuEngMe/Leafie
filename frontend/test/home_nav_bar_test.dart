// 하단 네비게이션(3173:113). 아이콘 넷의 좌표가 시안과 어긋나면 홈 화면
// 전체가 틀어지므로 여기서 값을 잠근다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/calendar_screen.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/my_page_screen.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

Finder _navIcon(FigmaNavIcon icon) =>
    find.byWidgetPredicate((w) => w is FigmaBottomNavIcon && w.icon == icon);

void main() {
  testWidgets('아이콘 넷이 시안 좌표에 앉는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    final screen = tester.getRect(find.byType(HomeScreen));
    final barTop = screen.bottom - AppLayout.homeBottomNavHeight;

    // 시안 3173:113의 x / 바 안쪽 y.
    const expected = <FigmaNavIcon, Offset>{
      FigmaNavIcon.home: Offset(35, 22),
      FigmaNavIcon.diary: Offset(139, 24),
      FigmaNavIcon.calendar: Offset(240, 22),
      FigmaNavIcon.my: Offset(338, 25),
    };

    for (final entry in expected.entries) {
      final rect = tester.getRect(_navIcon(entry.key));
      expect(rect.left, closeTo(entry.value.dx, 0.5), reason: entry.key.label);
      expect(
        rect.top - barTop,
        closeTo(entry.value.dy, 0.5),
        reason: entry.key.label,
      );
      expect(rect.size, entry.key.figmaSize, reason: entry.key.label);
    }
  });

  testWidgets('알약 배경과 글자 라벨은 시안에서 빠졌다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // 3173:113은 아이콘만 놓는다. 예전 알약의 글자가 남아 있으면 안 된다.
    expect(find.text('기록'), findsNothing);
    expect(find.text('달력'), findsNothing);
    expect(find.text('마이'), findsNothing);
  });

  testWidgets('마이 아이콘을 누르면 마이페이지로 간다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(_navIcon(FigmaNavIcon.my));
    await tester.pumpAndSettle();

    expect(find.byType(MyPageScreen), findsOneWidget);
  });

  testWidgets('캘린더 아이콘을 누르면 관리 캘린더로 간다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          plant: HomePlant(
            id: 'plant-1',
            name: '새싹이',
            startedOn: null,
            personalityType: null,
          ),
          period: HomeTimePeriod.day,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(_navIcon(FigmaNavIcon.calendar));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarScreen), findsOneWidget);
  });
}
