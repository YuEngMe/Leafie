import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

/// Figma component set `회원가입_이메일` (2315:2440) variant mapping.
enum SignupEmailFieldVariant {
  verificationSent('Component 1', '2315:2421'),
  empty('Component 2', '2315:2430'),
  filled('Component 3', '2315:2439');

  const SignupEmailFieldVariant(this.figmaValue, this.figmaNodeId);

  final String figmaValue;
  final String figmaNodeId;
}

/// Figma component set `버튼_회원가입` (2307:2096) variant mapping.
enum SignupSendButtonVariant {
  disabled('Frame 1707481526', '2307:2094'),
  enabled('Frame 1261154386', '2307:2095');

  const SignupSendButtonVariant(this.figmaValue, this.figmaNodeId);

  final String figmaValue;
  final String figmaNodeId;
}

/// Figma component set `회원가입_비밀번호` (2315:2457) variant mapping.
enum SignupPasswordFieldVariant {
  empty('Group 1597880996', '2315:2441'),
  filled('Group 1597881002', '2315:2443'),
  error('Component 5', '2315:2456');

  const SignupPasswordFieldVariant(this.figmaValue, this.figmaNodeId);

  final String figmaValue;
  final String figmaNodeId;
}

/// Figma component set `회원가입_닉네임` (2315:2477) variant mapping.
enum SignupNicknameFieldVariant {
  empty('Group 1597880998', '2315:2475'),
  filled('Group 1597881001', '2315:2476');

  const SignupNicknameFieldVariant(this.figmaValue, this.figmaNodeId);

  final String figmaValue;
  final String figmaNodeId;
}

/// Figma node 2315:2440의 이메일 입력 상태 묶음.
class SignupEmailField extends StatelessWidget {
  const SignupEmailField({
    super.key,
    required this.controller,
    required this.variant,
    required this.onSend,
    this.errorText,
  });

  final TextEditingController controller;
  final SignupEmailFieldVariant variant;
  final VoidCallback? onSend;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final verificationSent =
        variant == SignupEmailFieldVariant.verificationSent;
    final sendButtonVariant = variant == SignupEmailFieldVariant.empty
        ? SignupSendButtonVariant.disabled
        : SignupSendButtonVariant.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RoundedInputField(
                label: '이메일',
                hintText: variant == SignupEmailFieldVariant.empty
                    ? '이메일을 입력하세요.'
                    : null,
                controller: controller,
                readOnly: verificationSent,
                errorText: errorText,
                height: AppLayout.onboardingControlHeight,
                labelGap: 1,
                centerVertically: true,
                labelColor: kOrangeMain,
                // Figma는 03:21을 절대좌표로 얹는다. suffixIcon으로 넣으면
                // 입력 폭을 뺏어 이메일 끝 글자가 잘린다.
                overlaySuffix: verificationSent,
                suffix: verificationSent
                    ? const _VerificationCountdown()
                    : null,
              ),
            ),
            const SizedBox(width: AppLayout.authEmailActionGap),
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: SignupSendButton(
                variant: sendButtonVariant,
                label: verificationSent ? '재발송' : '발송',
                onPressed: onSend,
              ),
            ),
          ],
        ),
        if (verificationSent)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 11),
            child: Text(
              '인증메일이 발송 되었습니다.',
              style: kCaptionStyle.copyWith(color: kErrorRed, height: 1),
            ),
          ),
      ],
    );
  }
}

/// Figma node 2307:2096의 회원가입용 68×51 버튼.
class SignupSendButton extends StatelessWidget {
  const SignupSendButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.variant,
  });

  final String label;
  final VoidCallback? onPressed;
  final SignupSendButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      width: AppLayout.authEmailActionWidth,
      height: AppLayout.onboardingControlHeight,
      label: label,
      onPressed: onPressed,
      variant: variant == SignupSendButtonVariant.enabled
          ? PrimaryButtonVariant.enabled
          : PrimaryButtonVariant.disabled,
      textStyle: kSendButtonStyle,
      showShadow: false,
      labelOffsetY: 0,
    );
  }
}

/// Figma node 2315:2457의 기본·입력·오류 상태를 공유한다.
class SignupPasswordField extends StatelessWidget {
  const SignupPasswordField({
    super.key,
    required this.controller,
    required this.variant,
    this.label = '비밀번호',
    this.errorText,
  });

  final TextEditingController controller;
  final SignupPasswordFieldVariant variant;
  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    assert(
      variant != SignupPasswordFieldVariant.error || errorText != null,
      'The Figma error variant requires errorText.',
    );
    return RoundedInputField(
      label: label,
      hintText: variant == SignupPasswordFieldVariant.empty
          ? '비밀번호를 입력하세요.'
          : null,
      obscureText: true,
      controller: controller,
      errorText: variant == SignupPasswordFieldVariant.error ? errorText : null,
      height: AppLayout.onboardingControlHeight,
      labelGap: 1,
      centerVertically: true,
      labelColor: kOrangeMain,
    );
  }
}

/// Figma node 2315:2477의 기본·입력 상태를 공유한다.
class SignupNicknameField extends StatelessWidget {
  const SignupNicknameField({
    super.key,
    required this.controller,
    required this.variant,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final SignupNicknameFieldVariant variant;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return RoundedInputField(
      label: '닉네임',
      hintText: variant == SignupNicknameFieldVariant.empty
          ? '닉네임을 입력하세요.'
          : null,
      controller: controller,
      enabled: enabled,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      height: AppLayout.onboardingControlHeight,
      labelGap: 1,
      centerVertically: true,
      labelColor: kOrangeMain,
    );
  }
}

class _VerificationCountdown extends StatelessWidget {
  const _VerificationCountdown();

  @override
  Widget build(BuildContext context) {
    // Figma는 03:21을 이메일과 같은 줄에 둔다(중심 48.5 vs 49.5). 필드가
    // isDense라 입력 텍스트가 세로 중앙보다 위에 붙으므로 카운트다운도
    // 같은 만큼 올린다.
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Text(
        '03:21',
        style: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 10,
          color: kErrorRed,
        ),
      ),
    );
  }
}
