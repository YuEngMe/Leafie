import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/widgets/instant_page_route.dart';

void main() {
  testWidgets('즉시 전환 화면도 왼쪽 끝을 밀면 닫힌다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              InstantPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('전체보기')),
              ),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('전체보기'), findsOneWidget);

    // 가운데에서 민 건 닫지 않고, 왼쪽 끝(20px 안)에서 민 것만 닫는다.
    await tester.dragFrom(const Offset(200, 300), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(find.text('전체보기'), findsOneWidget);

    await tester.dragFrom(const Offset(5, 300), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(find.text('전체보기'), findsNothing);
  });
}
