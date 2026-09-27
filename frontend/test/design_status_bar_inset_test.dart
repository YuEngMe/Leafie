import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/widgets/design_status_bar_inset.dart';

/// iPhone 16 Pro 실제 안전 영역(상단 62)에서 시안 상태바(46)로 줄어드는지.
void main() {
  Future<EdgeInsets> paddingSeenUnder(WidgetTester tester, double top) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: top, bottom: 34);
    addTearDown(tester.view.reset);
    late EdgeInsets seen;
    await tester.pumpWidget(
      DesignStatusBarInset(
        child: Builder(
          builder: (context) {
            seen = MediaQuery.paddingOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return seen;
  }

  testWidgets('상단 62는 시안 높이 46으로 줄이고 하단은 그대로 둔다', (tester) async {
    final padding = await paddingSeenUnder(tester, 62);
    expect(padding.top, 46);
    expect(padding.bottom, 34);
  });

  testWidgets('46보다 얇은 안전 영역은 건드리지 않는다', (tester) async {
    final padding = await paddingSeenUnder(tester, 20);
    expect(padding.top, 20);
  });

  testWidgets('앱바가 시안 위치(46)에서 시작한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DesignStatusBarInset(child: child!),
        home: Scaffold(
          appBar: AppBar(title: const Text('제목'), toolbarHeight: 46),
        ),
      ),
    );
    expect(tester.getRect(find.byType(NavigationToolbar)).top, 46);
  });
}
