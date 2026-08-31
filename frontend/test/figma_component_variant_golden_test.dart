import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/login_credentials_form.dart';
import 'package:yeso_plant/widgets/onboarding_fields.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

void main() {
  testWidgets('Figma 로그인 입력 오류 2353:991 동일 크기 스냅샷', (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(374, 178);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final email = TextEditingController(text: 'seaminasun@naver.com');
    final password = TextEditingController(text: '1234567');
    addTearDown(email.dispose);
    addTearDown(password.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: Scaffold(
          backgroundColor: const Color(0xFFEBEBEB),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: LoginCredentialsForm(
              emailController: email,
              passwordController: password,
              emailVariant: LoginEmailFieldVariant.filled,
              passwordVariant: LoginPasswordFieldVariant.error,
              passwordError: '비밀번호가 옳지 않습니다.',
              onSignup: _noop,
              onForgotPassword: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/figma_login_filled_error_374x178.png'),
    );
    debugDisableShadows = true;
  });

  testWidgets('Figma 발송 버튼 2307:2096 동일 크기 스냅샷', (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(188, 91);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: Scaffold(
          backgroundColor: const Color(0xFFEBEBEB),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SignupSendButton(
                  label: '발송',
                  variant: SignupSendButtonVariant.disabled,
                  onPressed: null,
                ),
                const SizedBox(width: 12),
                SignupSendButton(
                  label: '발송',
                  variant: SignupSendButtonVariant.enabled,
                  onPressed: _noop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/figma_send_button_188x91.png'),
    );
    debugDisableShadows = true;
  });

  testWidgets('Figma 시작하기 버튼 2307:2088 동일 크기 스냅샷', (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(374, 163);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: const Scaffold(
          backgroundColor: Color(0xFFEBEBEB),
          body: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                PrimaryButton(
                  label: '시작하기',
                  variant: PrimaryButtonVariant.enabled,
                  onPressed: _noop,
                ),
                SizedBox(height: 21),
                PrimaryButton(
                  label: '시작하기',
                  variant: PrimaryButtonVariant.disabled,
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/figma_primary_button_374x163.png'),
    );
    debugDisableShadows = true;
  });

  testWidgets('Figma 로그인 공란 2353:1020 동일 크기 스냅샷', (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(374, 178);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final email = TextEditingController();
    final password = TextEditingController();
    addTearDown(email.dispose);
    addTearDown(password.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: Scaffold(
          backgroundColor: const Color(0xFFEBEBEB),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: LoginCredentialsForm(
              emailController: email,
              passwordController: password,
              emailVariant: LoginEmailFieldVariant.empty,
              passwordVariant: LoginPasswordFieldVariant.standard,
              onSignup: () {},
              onForgotPassword: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/figma_login_empty_374x178.png'),
    );
    debugDisableShadows = true;
  });

  testWidgets('Figma 회원가입 입력 variant 402x874 스냅샷', (tester) async {
    tester.view.physicalSize = AppLayout.referenceViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final empty = TextEditingController();
    final email = TextEditingController(text: 'seamiansun@naver.com');
    final password = TextEditingController(text: 'password123');
    addTearDown(empty.dispose);
    addTearDown(email.dispose);
    addTearDown(password.dispose);

    await tester.pumpWidget(
      _VariantApp(
        child: Column(
          children: [
            SignupEmailField(
              controller: empty,
              variant: SignupEmailFieldVariant.empty,
              onSend: () {},
            ),
            const SizedBox(height: 12),
            SignupEmailField(
              controller: email,
              variant: SignupEmailFieldVariant.filled,
              onSend: () {},
            ),
            const SizedBox(height: 12),
            SignupEmailField(
              controller: email,
              variant: SignupEmailFieldVariant.verificationSent,
              onSend: () {},
            ),
            const SizedBox(height: 20),
            SignupPasswordField(
              controller: empty,
              variant: SignupPasswordFieldVariant.empty,
            ),
            const SizedBox(height: 12),
            SignupPasswordField(
              controller: password,
              variant: SignupPasswordFieldVariant.filled,
            ),
            const SizedBox(height: 12),
            SignupPasswordField(
              controller: password,
              variant: SignupPasswordFieldVariant.error,
              errorText: '최소 8자리 이상 입력해야 합니다.',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/figma_signup_input_variants_402.png'),
    );
  });

  testWidgets('Figma 로그인·닉네임·버튼 variant 402x874 스냅샷', (tester) async {
    tester.view.physicalSize = AppLayout.referenceViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final emptyEmail = TextEditingController();
    final emptyPassword = TextEditingController();
    final email = TextEditingController(text: 'seaminasun@naver.com');
    final password = TextEditingController(text: 'password123');
    final nickname = TextEditingController(text: '식집사 콩쥐');
    addTearDown(emptyEmail.dispose);
    addTearDown(emptyPassword.dispose);
    addTearDown(email.dispose);
    addTearDown(password.dispose);
    addTearDown(nickname.dispose);

    await tester.pumpWidget(
      _VariantApp(
        child: Column(
          children: [
            LoginCredentialsForm(
              emailController: emptyEmail,
              passwordController: emptyPassword,
              emailVariant: LoginEmailFieldVariant.empty,
              passwordVariant: LoginPasswordFieldVariant.standard,
              onSignup: () {},
              onForgotPassword: () {},
            ),
            const SizedBox(height: 18),
            LoginCredentialsForm(
              emailController: email,
              passwordController: password,
              emailVariant: LoginEmailFieldVariant.filled,
              passwordVariant: LoginPasswordFieldVariant.error,
              passwordError: '비밀번호가 옭지 않습니다.',
              onSignup: () {},
              onForgotPassword: () {},
            ),
            const SizedBox(height: 24),
            SignupNicknameField(
              controller: emptyEmail,
              variant: SignupNicknameFieldVariant.empty,
            ),
            const SizedBox(height: 12),
            SignupNicknameField(
              controller: nickname,
              variant: SignupNicknameFieldVariant.filled,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: '활성',
                    variant: PrimaryButtonVariant.enabled,
                    onPressed: () {},
                    height: AppLayout.onboardingControlHeight,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: PrimaryButton(
                    label: '비활성',
                    variant: PrimaryButtonVariant.disabled,
                    onPressed: null,
                    height: AppLayout.onboardingControlHeight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/figma_login_control_variants_402.png'),
    );
  });
}

void _noop() {}

class _VariantApp extends StatelessWidget {
  const _VariantApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: kBackgroundWhite,
        fontFamily: kFontFamily,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(34, 12, 34, 12),
            child: child,
          ),
        ),
      ),
    );
  }
}
