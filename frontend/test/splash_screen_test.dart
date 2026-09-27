import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/splash_screen.dart';

void main() {
  Future<List<int>> pumpSplash(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <int>[];
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onDone: () => calls.add(1))),
    );
    return calls;
  }

  testWidgets('시작 화면을 탭하면 연출을 기다리지 않고 바로 넘어간다', (tester) async {
    final calls = await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const ValueKey('splash-skip')));
    await tester.pump();
    expect(calls, hasLength(1));

    // 연출은 멈추지 않고 끝까지 돈다(로고가 중간에 얼어붙은 채 밀려나지
    // 않게). 끝난 뒤 걸리는 타이머가 와도 한 번 더 넘어가지 않는다.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, hasLength(1));
  });

  testWidgets('탭하지 않으면 연출이 끝난 뒤 한 번 넘어간다', (tester) async {
    final calls = await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(calls, isEmpty);

    // 연출(1.1초)이 끝나고 0.26초 뒤에 넘어간다.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, hasLength(1));
  });
}
