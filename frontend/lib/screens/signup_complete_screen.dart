import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/brand_logo.dart';
import 'package:yeso_plant/widgets/onboarding_copy.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

// Figma "04 앱 진입_회원가입"의 완료 상태 화면 (2026-08-05 확인).
class SignupCompleteScreen extends StatelessWidget {
  const SignupCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.authHorizontalPadding,
            0,
            AppLayout.authHorizontalPadding,
            AppLayout.bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppLayout.signupCompleteTopGap),
              const Center(
                child: BrandLogo(
                  width: AppLayout.signupCompleteLogoWidth,
                  markWidthFactor: 0.66,
                ),
              ),
              const SizedBox(height: AppLayout.signupCompleteCopyGap),
              // 2315:2270은 headline이 폭 전체, body가 좌우 15px씩 들어간
              // 가운데 정렬이다.
              const Align(
                child: OnboardingCopy(
                  title: '회원가입이 완료되었습니다.',
                  subtitle: '리피와 함께 나의 반려식물을 키워요!',
                  textAlign: TextAlign.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: '시작하기',
                variant: PrimaryButtonVariant.enabled,
                height: AppLayout.onboardingControlHeight,
                textStyle: kLoginButtonStyle,
                // 로그인 화면까지 스택을 걷어내고 돌아간다 — 여기서 이메일 인증을
                // 실제로 완료했는지는 로그인 시도에서 서버가 다시 검증한다.
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
