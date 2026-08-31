import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/login_credentials_form.dart';
import 'package:yeso_plant/widgets/onboarding_fields.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

void main() {
  test('Figma 버튼 variant가 Flutter enum과 1:1로 매핑된다', () {
    expect(PrimaryButtonVariant.enabled.figmaNodeId, '2307:2086');
    expect(PrimaryButtonVariant.disabled.figmaNodeId, '2307:2087');
    expect(SignupSendButtonVariant.enabled.figmaNodeId, '2307:2095');
    expect(SignupSendButtonVariant.disabled.figmaNodeId, '2307:2094');
  });

  test('Figma 회원가입 필드 variant가 Flutter enum과 1:1로 매핑된다', () {
    expect(
      SignupEmailFieldVariant.values.map((variant) => variant.figmaNodeId),
      ['2315:2421', '2315:2430', '2315:2439'],
    );
    expect(
      SignupPasswordFieldVariant.values.map((variant) => variant.figmaNodeId),
      ['2315:2441', '2315:2443', '2315:2456'],
    );
    expect(
      SignupNicknameFieldVariant.values.map((variant) => variant.figmaNodeId),
      ['2315:2475', '2315:2476'],
    );
  });

  test('Figma 로그인 필드 variant가 Flutter enum과 1:1로 매핑된다', () {
    expect(
      LoginEmailFieldVariant.values.map((variant) => variant.figmaNodeId),
      ['2353:1018', '2353:989'],
    );
    expect(
      LoginPasswordFieldVariant.values.map((variant) => variant.figmaNodeId),
      ['2353:1019', '2353:990'],
    );
  });

  testWidgets('Figma 로그인_공란 334x138 기하를 그대로 사용한다', (tester) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    addTearDown(emailController.dispose);
    addTearDown(passwordController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 334,
              child: LoginCredentialsForm(
                emailController: emailController,
                passwordController: passwordController,
                emailVariant: LoginEmailFieldVariant.empty,
                passwordVariant: LoginPasswordFieldVariant.standard,
                onSignup: () {},
                onForgotPassword: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final form = find.byType(LoginCredentialsForm);
    final email = find.byType(LoginEmailField);
    final password = find.byType(LoginPasswordField);
    expect(tester.getSize(form), const Size(334, 138));
    expect(
      tester.getSize(email),
      const Size(334, AppLayout.loginEmailFieldHeight),
    );
    expect(
      tester.getSize(password),
      const Size(334, AppLayout.loginPasswordComponentHeight),
    );
    expect(
      tester.getTopLeft(password).dy - tester.getBottomLeft(email).dy,
      AppLayout.loginEmailToPasswordGap,
    );
  });

  testWidgets('Figma 시작하기 버튼 기본 기하는 334x51이다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 334,
            child: PrimaryButton(
              label: '시작하기',
              variant: PrimaryButtonVariant.enabled,
              onPressed: _noop,
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(PrimaryButton)), const Size(334, 51));
  });

  testWidgets('Figma 로그인 입력 오류도 334x138 기하를 사용한다', (tester) async {
    final emailController = TextEditingController(text: 'seaminasun@naver.com');
    final passwordController = TextEditingController(text: '1234567');
    addTearDown(emailController.dispose);
    addTearDown(passwordController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 334,
              child: LoginCredentialsForm(
                emailController: emailController,
                passwordController: passwordController,
                emailVariant: LoginEmailFieldVariant.filled,
                passwordVariant: LoginPasswordFieldVariant.error,
                passwordError: '비밀번호가 옳지 않습니다.',
                onSignup: _noop,
                onForgotPassword: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    final email = find.byType(LoginEmailField);
    final password = find.byType(LoginPasswordField);
    expect(
      tester.getSize(find.byType(LoginCredentialsForm)),
      const Size(334, 138),
    );
    expect(tester.getSize(email), const Size(334, 51));
    expect(tester.getSize(password), const Size(334, 75));
    expect(tester.getTopLeft(password).dy - tester.getBottomLeft(email).dy, 12);
  });

  testWidgets('Figma 발송 버튼 variant 기하는 각각 68x51이다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SignupSendButton(
                label: '발송',
                variant: SignupSendButtonVariant.disabled,
                onPressed: null,
              ),
              SignupSendButton(
                label: '발송',
                variant: SignupSendButtonVariant.enabled,
                onPressed: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    for (final button in find.byType(SignupSendButton).evaluate()) {
      expect(tester.getSize(find.byWidget(button.widget)), const Size(68, 51));
    }
  });
}

void _noop() {}
