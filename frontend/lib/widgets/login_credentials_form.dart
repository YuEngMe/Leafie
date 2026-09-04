import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

/// Figma login email components (2353:1018, 2353:989).
enum LoginEmailFieldVariant {
  empty('Frame 1261154387', '2353:1018'),
  filled('Default', '2353:989');

  const LoginEmailFieldVariant(this.figmaValue, this.figmaNodeId);

  final String figmaValue;
  final String figmaNodeId;
}

/// Figma login password components (2353:1019, 2353:990).
enum LoginPasswordFieldVariant {
  standard('Component 7', '2353:1019'),
  error('Default', '2353:990');

  const LoginPasswordFieldVariant(this.figmaValue, this.figmaNodeId);

  final String figmaValue;
  final String figmaNodeId;
}

/// Figma nodes 2353:991, 2353:1020의 로그인 입력 묶음.
class LoginCredentialsForm extends StatelessWidget {
  const LoginCredentialsForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onSignup,
    required this.onForgotPassword,
    required this.emailVariant,
    required this.passwordVariant,
    this.passwordError,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onSignup;
  final VoidCallback onForgotPassword;
  final LoginEmailFieldVariant emailVariant;
  final LoginPasswordFieldVariant passwordVariant;
  final String? passwordError;

  @override
  Widget build(BuildContext context) {
    assert(
      passwordVariant != LoginPasswordFieldVariant.error ||
          passwordError != null,
      'The Figma error variant requires passwordError.',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LoginEmailField(controller: emailController, variant: emailVariant),
        SizedBox(
          height: emailVariant == LoginEmailFieldVariant.filled
              ? AppLayout.loginFilledEmailToPasswordGap
              : AppLayout.loginEmailToPasswordGap,
        ),
        LoginPasswordField(
          controller: passwordController,
          variant: passwordVariant,
          passwordError: passwordError,
          onSignup: onSignup,
          onForgotPassword: onForgotPassword,
        ),
      ],
    );
  }
}

class LoginEmailField extends StatelessWidget {
  const LoginEmailField({
    super.key,
    required this.controller,
    required this.variant,
  });

  final TextEditingController controller;
  final LoginEmailFieldVariant variant;

  @override
  Widget build(BuildContext context) {
    final isFilled = variant == LoginEmailFieldVariant.filled;
    return RoundedInputField(
      controller: controller,
      hintText: isFilled ? null : '이메일을 입력하세요.',
      centerText: true,
      height: isFilled
          ? AppLayout.loginFilledEmailFieldHeight
          : AppLayout.loginEmailFieldHeight,
      centerVertically: true,
      contentPadding: isFilled
          ? const EdgeInsets.fromLTRB(16, 14, 16, 21)
          : const EdgeInsets.fromLTRB(16, 16, 16, 19),
      hintStyle: kLoginHintStyle,
      textStyle: isFilled ? kLoginEmailValueStyle : null,
    );
  }
}

class LoginPasswordField extends StatelessWidget {
  const LoginPasswordField({
    super.key,
    required this.controller,
    required this.variant,
    required this.onSignup,
    required this.onForgotPassword,
    this.passwordError,
  });

  final TextEditingController controller;
  final LoginPasswordFieldVariant variant;
  final VoidCallback onSignup;
  final VoidCallback onForgotPassword;
  final String? passwordError;

  @override
  Widget build(BuildContext context) {
    final isError = variant == LoginPasswordFieldVariant.error;
    assert(
      !isError || passwordError != null,
      'The Figma error variant requires passwordError.',
    );
    return SizedBox(
      height: AppLayout.loginPasswordComponentHeight,
      child: Stack(
        children: [
          RoundedInputField(
            controller: controller,
            hintText: '비밀번호를 입력하세요.',
            obscureText: true,
            centerText: true,
            hasError: isError,
            height: AppLayout.onboardingControlHeight,
            centerVertically: true,
            contentPadding: isError
                ? const EdgeInsets.fromLTRB(16, 18, 32, 19)
                : const EdgeInsets.fromLTRB(16, 17, 16, 20),
            overlaySuffix: true,
            // 시안 2395:31은 빈 칸에도 눈 아이콘을 띄운다.
            alwaysShowEye: true,
            hintStyle: kLoginHintStyle,
            textStyle: isError ? kLoginPasswordValueStyle : null,
            obscuringCharacter: isError ? '●' : '•',
            showShadow: !isError,
          ),
          Positioned(
            top: AppLayout.loginPasswordLinksTop,
            left: AppLayout.loginLinkHorizontalInset,
            right: AppLayout.loginLinkHorizontalInset,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isError)
                  Text(passwordError!, style: kLoginErrorStyle)
                else
                  _LoginTextLink(label: '회원가입', onTap: onSignup),
                _LoginTextLink(label: '비밀번호 찾기', onTap: onForgotPassword),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginTextLink extends StatelessWidget {
  const _LoginTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(label, style: kLoginLinkStyle),
    );
  }
}
