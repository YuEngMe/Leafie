// 회원가입 흐름: 이메일 형식 확인 → 잠금 → 비밀번호 조건 검증까지.
// Figma "04 앱 진입_회원가입"(2026-08-05 확인) 기준 — signUp은 실제 서버 호출이라
// 여기서는 그 앞 단계(형식 검증, 버튼 활성/비활성 전환)만 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/signup_screen.dart';

// 화면 순서 고정: 0=이메일, 1=비밀번호, 2=비밀번호 확인, 3=닉네임.
// AppTextField가 라벨(Text)과 TextField를 형제로 그려서 텍스트로 못 찾으므로 인덱스로 지목한다.
Finder _passwordField() => find.byType(TextField).at(1);
Finder _passwordConfirmField() => find.byType(TextField).at(2);

// AppBar 제목과 버튼에 같은 문구('회원가입')가 있어 버튼 쪽만 지정.
Finder _submitButton() => find.descendant(
  of: find.byType(ElevatedButton),
  matching: find.text('회원가입'),
);

void main() {
  testWidgets('이메일 형식이 틀리면 발송을 눌러도 에러만 뜨고 잠기지 않는다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.tap(find.text('발송'));
    await tester.pump();

    expect(find.text('이메일 형식이 올바르지 않습니다.'), findsOneWidget);
    expect(find.text('발송'), findsOneWidget); // 여전히 '발송' — 잠기지 않음
  });

  testWidgets('이메일 형식이 맞으면 확인 완료로 바뀌고 입력칸이 잠긴다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'test@example.com');
    await tester.tap(find.text('발송'));
    await tester.pump();

    expect(find.text('확인 완료'), findsOneWidget);
    final widget = tester.widget<TextField>(emailField);
    expect(widget.enabled, isFalse);
  });

  testWidgets('이메일 확인 전에 회원가입을 누르면 안내만 뜨고 진행되지 않는다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.tap(_submitButton());
    await tester.pump();

    expect(find.text('이메일을 먼저 확인해주세요.'), findsOneWidget);
  });

  testWidgets('이메일 확인 후 비밀번호가 8자 미만이면 막힌다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.tap(find.text('발송'));
    await tester.pump();

    await tester.enterText(_passwordField(), '1234567');
    await tester.tap(_submitButton());
    await tester.pump();

    expect(find.text('비밀번호는 최소 8자리 이상이어야 합니다.'), findsOneWidget);
  });

  testWidgets('비밀번호와 확인이 다르면 막힌다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.tap(find.text('발송'));
    await tester.pump();

    await tester.enterText(_passwordField(), 'password123');
    await tester.enterText(_passwordConfirmField(), 'password124');
    await tester.tap(_submitButton());
    await tester.pump();

    expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
  });
}
