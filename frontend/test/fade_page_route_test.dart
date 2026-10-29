import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/widgets/fade_page_route.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> _pumpApp(WidgetTester tester, {bool disableAnimations = false}) =>
    tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const Text('old', key: ValueKey('old')),
        ),
      ),
    );

double _opacityAbove(WidgetTester tester, Finder finder) {
  final fades = tester.widgetList<FadeTransition>(
    find.ancestor(of: finder, matching: find.byType(FadeTransition)),
  );
  return fades.fold(1.0, (value, fade) => value * fade.opacity.value);
}

void main() {
  testWidgets('이전 화면은 그대로 두고 새 화면만 서서히 드러낸다', (tester) async {
    await _pumpApp(tester);
    final oldLeft = tester.getTopLeft(find.byKey(const ValueKey('old')));

    _navigatorKey.currentState!.pushAndRemoveUntil(
      FadePageRoute<void>(builder: (_) => const Text('new')),
      (_) => false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final midway = _opacityAbove(tester, find.text('new'));
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1));
    expect(tester.getTopLeft(find.byKey(const ValueKey('old'))), oldLeft);
    expect(tester.getTopLeft(find.text('new')), oldLeft);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('old')), findsNothing);
    expect(_opacityAbove(tester, find.text('new')), 1);
  });

  testWidgets('위로 일반 화면을 올리면 아래 화면이 iOS처럼 왼쪽으로 밀린다', (tester) async {
    await _pumpApp(tester);
    _navigatorKey.currentState!.pushAndRemoveUntil(
      FadePageRoute<void>(builder: (_) => const Text('root')),
      (_) => false,
    );
    await tester.pumpAndSettle();
    final restLeft = tester.getTopLeft(find.text('root')).dx;

    _navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('child')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.getTopLeft(find.text('root')).dx, lessThan(restLeft));
  });

  testWidgets('동작 줄이기가 켜져 있으면 fade 없이 바로 보인다', (tester) async {
    await _pumpApp(tester, disableAnimations: true);

    _navigatorKey.currentState!.pushAndRemoveUntil(
      FadePageRoute<void>(builder: (_) => const Text('new')),
      (_) => false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(_opacityAbove(tester, find.text('new')), 1);
  });
}
