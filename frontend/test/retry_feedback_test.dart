import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/theme/app_motion.dart';
import 'package:yeso_plant/widgets/retry_feedback.dart';

Future<void> _pump(
  WidgetTester tester,
  Future<bool> Function() onRetry, {
  VoidCallback? onSucceeded,
}) => tester.pumpWidget(
  MaterialApp(
    home: Center(
      child: RetryFeedback(
        onRetry: onRetry,
        onSucceeded: onSucceeded,
        builder: (context, phase, retry) => TextButton(
          onPressed: retry,
          child: Text(switch (phase) {
            RetryPhase.idle => '다시 시도',
            RetryPhase.busy => kRetryBusyLabel,
            RetryPhase.failed => kRetryFailedMessage,
          }),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('곧바로 실패해도 연결 중을 잠깐 보여 준 뒤 실패 문구로 바꾼다', (tester) async {
    await _pump(tester, () async => false);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(find.text(kRetryBusyLabel), findsOneWidget);

    await tester.pump(AppMotion.retryMinBusy - const Duration(milliseconds: 1));
    expect(find.text(kRetryBusyLabel), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text(kRetryFailedMessage), findsOneWidget);

    await tester.pump(AppMotion.retryFailedHold);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('요청이 길면 끝날 때까지 연결 중이고, 겹친 탭은 무시한다', (tester) async {
    final result = Completer<bool>();
    var calls = 0;
    await _pump(tester, () {
      calls++;
      return result.future;
    });

    await tester.tap(find.text('다시 시도'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(kRetryBusyLabel), findsOneWidget);

    await tester.tap(find.text(kRetryBusyLabel));
    await tester.pump();
    expect(calls, 1);

    result.complete(false);
    await tester.pump();
    expect(find.text(kRetryFailedMessage), findsOneWidget);
    await tester.pump(AppMotion.retryFailedHold);
  });

  testWidgets('성공하면 연결 중을 다 보여 준 뒤 onSucceeded를 부른다', (tester) async {
    var succeeded = false;
    await _pump(tester, () async => true, onSucceeded: () => succeeded = true);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(succeeded, isFalse);

    await tester.pump(AppMotion.retryMinBusy);
    expect(succeeded, isTrue);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('요청이 예외를 던지면 실패로 본다', (tester) async {
    await _pump(tester, () async => throw StateError('offline'));

    await tester.tap(find.text('다시 시도'));
    await tester.pump(AppMotion.retryMinBusy);
    expect(find.text(kRetryFailedMessage), findsOneWidget);
    await tester.pump(AppMotion.retryFailedHold);
  });

  testWidgets('누르면 가벼운 진동을 준다', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester, () async => true);

    await tester.tap(find.text('다시 시도'));
    await tester.pump(AppMotion.retryMinBusy);

    expect(
      calls,
      contains(
        isA<MethodCall>()
            .having((call) => call.method, 'method', 'HapticFeedback.vibrate')
            .having(
              (call) => call.arguments,
              'arguments',
              'HapticFeedbackType.lightImpact',
            ),
      ),
    );
  });
}
