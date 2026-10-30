import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/plant_photo_confirm_screen.dart';

final _greenPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// 확인 화면을 띄우고 닫힐 때 돌려준 값을 받는다.
Future<List<bool?>> _pumpConfirm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final results = <bool?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            results.add(
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      PlantPhotoConfirmScreen(bytes: _greenPixelPng),
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('4534:1110 찍은 사진을 깔고 다시 촬영·다음 막대를 둔다', (tester) async {
    await _pumpConfirm(tester);

    expect(find.byKey(const ValueKey('plant-confirm-photo')), findsOneWidget);
    expect(find.text('다시 촬영'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
    // 시안은 위쪽 뒤로가기·제목이 없다.
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('다음은 true, 다시 촬영은 false로 닫는다', (tester) async {
    final results = await _pumpConfirm(tester);
    await tester.tap(find.byKey(const ValueKey('plant-next-button')));
    await tester.pumpAndSettle();
    expect(results, [true]);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plant-retake-button')));
    await tester.pumpAndSettle();
    expect(results, [true, false]);
  });
}
