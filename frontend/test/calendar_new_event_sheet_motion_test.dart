import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/widgets/calendar_new_event_sheet.dart';

Future<void> _pumpOpener(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(402, 874),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCalendarNewEventSheet(
              context,
              initialDate: DateTime(2026, 7, 15),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
}

double _opacity(WidgetTester tester) => tester
    .widgetList<FadeTransition>(
      find.ancestor(of: find.text('확인'), matching: find.byType(FadeTransition)),
    )
    .fold(1.0, (value, fade) => value * fade.opacity.value);

double _scale(WidgetTester tester) => tester
    .widgetList<ScaleTransition>(
      find.ancestor(
        of: find.text('확인'),
        matching: find.byType(ScaleTransition),
      ),
    )
    .fold(1.0, (value, scale) => value * scale.scale.value);

void main() {
  testWidgets('일정 추가 카드는 살짝 작은 크기에서 커지며 나타난다', (tester) async {
    await _pumpOpener(tester);

    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(_opacity(tester), inExclusiveRange(0, 1));
    expect(_scale(tester), inExclusiveRange(0.95, 1));

    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    expect(_scale(tester), 1);
  });

  testWidgets('닫을 때는 크기를 그대로 두고 흐려지기만 한다', (tester) async {
    await _pumpOpener(tester);
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(_opacity(tester), inExclusiveRange(0, 1));
    expect(_scale(tester), 1);

    await tester.pumpAndSettle();
    expect(find.text('확인'), findsNothing);
  });

  testWidgets('동작 줄이기가 켜져 있으면 바로 나타난다', (tester) async {
    await _pumpOpener(tester, disableAnimations: true);

    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(_opacity(tester), 1);
    expect(_scale(tester), 1);
  });
}
