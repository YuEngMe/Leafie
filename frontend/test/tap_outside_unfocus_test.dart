import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/widgets/tap_outside_unfocus.dart';

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  Future<(FocusNode, FocusNode)> pumpFields(
    WidgetTester tester, {
    VoidCallback? onButton,
  }) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TapOutsideUnfocus(child: child!),
        home: Scaffold(
          body: ListView(
            children: [
              TextField(key: const ValueKey('first'), focusNode: first),
              TextField(key: const ValueKey('second'), focusNode: second),
              TextButton(onPressed: onButton, child: const Text('버튼')),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    return (first, second);
  }

  testWidgets('입력창 밖 빈 곳을 탭하면 키보드가 내려간다', (tester) async {
    final (first, _) = await pumpFields(tester);
    await tester.tap(find.byKey(const ValueKey('first')));
    await tester.pump();
    expect(first.hasFocus, isTrue);

    await tester.tapAt(const Offset(200, 500));
    await tester.pump();

    expect(first.hasFocus, isFalse);
  }, variant: ios);

  testWidgets('입력창 밖을 끌어 스크롤하면 키보드는 그대로다', (tester) async {
    final (first, _) = await pumpFields(tester);
    await tester.tap(find.byKey(const ValueKey('first')));
    await tester.pump();

    await tester.dragFrom(const Offset(200, 500), const Offset(0, -200));
    await tester.pump();

    expect(first.hasFocus, isTrue);
  }, variant: ios);

  testWidgets('다른 입력창을 탭하면 포커스가 그쪽으로 옮겨 간다', (tester) async {
    final (first, second) = await pumpFields(tester);
    await tester.tap(find.byKey(const ValueKey('first')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('second')));
    await tester.pump();

    expect(first.hasFocus, isFalse);
    expect(second.hasFocus, isTrue);
  }, variant: ios);

  testWidgets('입력창 밖 버튼을 탭하면 버튼도 눌리고 키보드도 내려간다', (tester) async {
    var pressed = 0;
    final (first, _) = await pumpFields(tester, onButton: () => pressed++);
    await tester.tap(find.byKey(const ValueKey('first')));
    await tester.pump();

    await tester.tap(find.text('버튼'));
    await tester.pump();

    expect(pressed, 1);
    expect(first.hasFocus, isFalse);
  }, variant: ios);
}
