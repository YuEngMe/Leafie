// 회원가입 흐름: 이메일 형식 확인 → 잠금 → 비밀번호 조건 검증까지.
// Figma "04 앱 진입_회원가입"(2026-08-05 확인) 기준 — signUp은 실제 서버 호출이라
// 여기서는 그 앞 단계(형식 검증, 버튼 활성/비활성 전환)만 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/signup_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/onboarding_fields.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

// 화면 순서 고정: 0=이메일, 1=비밀번호, 2=비밀번호 확인, 3=닉네임.
// RoundedInputField가 라벨(Text)과 TextField를 형제로 그려서 텍스트로 못 찾으므로
// 인덱스로 지목한다.
Finder _passwordField() => find.byType(TextField).at(1);
Finder _passwordConfirmField() => find.byType(TextField).at(2);

ElevatedButton _submitButtonWidget(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '시작하기'));

void main() {
  testWidgets('회원가입 필드는 공통 온보딩 컴포넌트를 사용한다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    expect(find.byType(SignupEmailField), findsOneWidget);
    expect(find.byType(SignupPasswordField), findsNWidgets(2));
    expect(find.byType(SignupNicknameField), findsOneWidget);
    expect(
      tester.widget<SignupEmailField>(find.byType(SignupEmailField)).variant,
      SignupEmailFieldVariant.empty,
    );
    expect(
      tester
          .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, '시작하기'))
          .variant,
      PrimaryButtonVariant.disabled,
    );
  });

  testWidgets('이메일 형식이 틀리면 발송을 눌러도 에러만 뜨고 잠기지 않는다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.pump();
    await tester.tap(find.text('발송'));
    await tester.pump();

    expect(find.text('이메일 형식이 올바르지 않습니다.'), findsOneWidget);
    expect(find.text('발송'), findsOneWidget); // 여전히 '발송' — 잠기지 않음
  });

  testWidgets('이메일 형식이 맞으면 재발송 상태로 바뀌고 입력칸이 잠긴다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'test@example.com');
    await tester.pump();
    expect(
      tester.widget<SignupEmailField>(find.byType(SignupEmailField)).variant,
      SignupEmailFieldVariant.filled,
    );
    await tester.tap(find.text('발송'));
    await tester.pump();

    expect(find.text('재발송'), findsOneWidget);
    expect(
      tester.widget<SignupEmailField>(find.byType(SignupEmailField)).variant,
      SignupEmailFieldVariant.verificationSent,
    );
    final widget = tester.widget<TextField>(emailField);
    expect(widget.readOnly, isTrue);
    expect(find.text('03:21'), findsOneWidget);
    expect(find.text('인증메일이 발송 되었습니다.'), findsOneWidget);
  });

  testWidgets('이메일 확인 전에는 회원가입 버튼이 비활성이다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    expect(_submitButtonWidget(tester).onPressed, isNull);
  });

  testWidgets('이메일 확인 후 비밀번호가 8자 미만이면 버튼이 비활성이다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.pump();
    await tester.tap(find.text('발송'));
    await tester.pump();

    await tester.enterText(_passwordField(), '1234567');
    await tester.pump();

    expect(_submitButtonWidget(tester).onPressed, isNull);
  });

  testWidgets('비밀번호가 다르면 비활성이고 모든 값이 유효하면 활성이다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.pump();
    await tester.tap(find.text('발송'));
    await tester.pump();

    await tester.enterText(_passwordField(), 'password123');
    await tester.enterText(_passwordConfirmField(), 'password124');
    await tester.pump();

    expect(_submitButtonWidget(tester).onPressed, isNull);

    await tester.enterText(_passwordConfirmField(), 'password123');
    await tester.enterText(find.byType(TextField).at(3), '리피');
    await tester.pump();

    expect(_submitButtonWidget(tester).onPressed, isNotNull);
  });

  testWidgets('짧거나 일치하지 않는 비밀번호는 인라인 오류로 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(_passwordField(), '1234567');
    await tester.pump();
    expect(find.text('최소 8자리 이상 입력해야 합니다.'), findsOneWidget);

    await tester.enterText(_passwordField(), 'password123');
    await tester.enterText(_passwordConfirmField(), 'password124');
    await tester.pump();
    expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
  });

  testWidgets('유효한 가입 정보를 제출하면 약관 동의 시트를 연다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.pump();
    await tester.tap(find.text('발송'));
    await tester.pump();
    await tester.enterText(_passwordField(), 'password123');
    await tester.enterText(_passwordConfirmField(), 'password123');
    await tester.enterText(find.byType(TextField).at(3), '리피');
    await tester.pump();

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('약관 모두 동의'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);

    // 시안 2307:785의 딤은 검정 45%다.
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, kModalBarrier);

    var confirmButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '확인'),
    );
    expect(confirmButton.onPressed, isNull);

    await tester.tap(find.text('약관 모두 동의'));
    await tester.pump();
    confirmButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '확인'),
    );
    expect(confirmButton.onPressed, isNotNull);
  });

  testWidgets('뒤로가기를 누르면 회원가입 중단 확인 모달을 연다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('회원가입을 중단하시겠습니까?'), findsOneWidget);
    expect(find.text('네'), findsOneWidget);
    expect(find.text('아니오'), findsOneWidget);
  });
}
