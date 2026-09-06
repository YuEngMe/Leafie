// 회원가입 인증 발송 뒤의 상태(2395:42 만료)와 발송 전후 레이아웃 고정
// (2395:40 ↔ 2395:42). 2026-09-07 감사에서 둘 다 빠져 있었다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/signup_screen.dart';

void main() {
  testWidgets('발송해도 아래 칸이 밀리지 않고, 3:21이 지나면 만료 문구로 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    final before = tester.getRect(find.text('비밀번호')).top;
    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.pump();
    await tester.tap(find.text('발송'));
    await tester.pump();

    expect(find.text('인증메일이 발송 되었습니다.'), findsOneWidget);
    expect(find.text('03:21'), findsOneWidget);
    expect(tester.getRect(find.text('비밀번호')).top, before);

    await tester.pump(const Duration(minutes: 3, seconds: 21));
    expect(find.text('시간이 만료 되었습니다.'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('재발송'), findsOneWidget);
  });
}
