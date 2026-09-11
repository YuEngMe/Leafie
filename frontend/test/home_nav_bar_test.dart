// 하단 네비게이션(3628:2411). 아이콘 넷의 좌표가 시안과 어긋나면 홈 화면
// 전체가 틀어지므로 여기서 값을 잠근다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/calendar_screen.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/my_page_screen.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/widgets/main_tab_shell.dart';

class _StatefulTab extends StatefulWidget {
  const _StatefulTab();

  @override
  State<_StatefulTab> createState() => _StatefulTabState();
}

class _StatefulTabState extends State<_StatefulTab> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => count++),
      child: Text('calendar:$count'),
    ),
  );
}

Finder _navIcon(FigmaNavIcon icon) =>
    find.byWidgetPredicate((w) => w is FigmaBottomNavIcon && w.icon == icon);

void main() {
  testWidgets('탭은 바와 상태를 유지하고 마이페이지 뒤로가기는 홈으로 간다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabShell(
          home: const Center(child: Text('home-tab')),
          diaryBuilder: (_) => const Center(child: Text('diary-tab')),
          calendarBuilder: (_) => const _StatefulTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.element(find.byType(AppBottomNav));
    await tester.tap(_navIcon(FigmaNavIcon.calendar));
    await tester.pumpAndSettle();
    await tester.tap(find.text('calendar:0'));
    await tester.pump();
    await tester.tap(_navIcon(FigmaNavIcon.diary));
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.element(find.byType(AppBottomNav)), same(bar));
    await tester.pumpAndSettle();
    expect(find.text('diary-tab'), findsOneWidget);
    await tester.tap(_navIcon(FigmaNavIcon.calendar));
    await tester.pumpAndSettle();
    expect(find.text('calendar:1'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(MainTabShell))).canPop(),
      isFalse,
    );
    await tester.tap(_navIcon(FigmaNavIcon.my));
    await tester.pumpAndSettle();
    expect(find.byType(MyPageScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
    await tester.tap(find.byType(FigmaBackChevron));
    await tester.pumpAndSettle();
    expect(find.text('home-tab'), findsOneWidget);
    await tester.tap(_navIcon(FigmaNavIcon.calendar));
    await tester.pumpAndSettle();
    expect(find.text('calendar:1'), findsOneWidget);
  });

  testWidgets('3628:2412 기본 바는 그림자 없이 위쪽만 30px 둥글다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SizedBox(width: 402, child: AppBottomNav())),
      ),
    );
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(AppBottomNav),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(tester.getSize(find.byType(AppBottomNav)), const Size(402, 79));
    expect(decoration.color, Colors.white);
    expect(decoration.boxShadow, isNull);
    expect(
      decoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(30)),
    );
  });

  testWidgets('아이콘 넷이 시안 좌표에 앉는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    final screen = tester.getRect(find.byType(HomeScreen));
    final barTop = screen.bottom - AppLayout.homeBottomNavHeight;

    // 시안 3628:2411의 x / 바 안쪽 y (2026-09-07 갱신본).
    const expected = <FigmaNavIcon, Offset>{
      FigmaNavIcon.home: Offset(35, 17),
      FigmaNavIcon.diary: Offset(139, 19),
      FigmaNavIcon.calendar: Offset(240, 17),
      FigmaNavIcon.my: Offset(338, 20),
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

    // 3628:2411은 아이콘만 놓는다. 예전 알약의 글자가 남아 있으면 안 된다.
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
