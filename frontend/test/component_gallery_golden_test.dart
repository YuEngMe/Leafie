import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/brand_logo.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_progress_bar.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

void main() {
  testWidgets('와프4차 공통 컴포넌트 402x874 스냅샷', (tester) async {
    tester.view.physicalSize = AppLayout.referenceViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          scaffoldBackgroundColor: kBackgroundWhite,
          fontFamily: kFontFamily,
        ),
        home: const _ComponentGallery(),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(_ComponentGallery));
      await Future.wait([
        precacheImage(
          const AssetImage('assets/images/leafie_logo_symbol.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/leafie_logo_word.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/character/body_circle_yellow.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/character/face_circle_default.png'),
          context,
        ),
      ]);
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(_ComponentGallery),
      matchesGoldenFile('goldens/component_gallery.png'),
    );
  });

  testWidgets('온보딩 약관 시트 402x874 스냅샷', (tester) async {
    tester.view.physicalSize = AppLayout.referenceViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TermsAgreementSheet(initiallyChecked: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(TermsAgreementSheet),
      matchesGoldenFile('goldens/onboarding_terms_sheet_402.png'),
    );
  });

  testWidgets('회원가입 중단 모달 402x874 스냅샷', (tester) async {
    tester.view.physicalSize = AppLayout.referenceViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: const Scaffold(body: Center(child: SignupAbortDialog())),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SignupAbortDialog),
      matchesGoldenFile('goldens/signup_abort_dialog_402.png'),
    );
  });

  testWidgets('로그인 오류 컴포넌트 402x874 스냅샷', (tester) async {
    tester.view.physicalSize = AppLayout.referenceViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final emailController = TextEditingController(text: 'seaminasun@naver.com');
    final passwordController = TextEditingController(text: '1234567');
    addTearDown(emailController.dispose);
    addTearDown(passwordController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 334,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundedInputField(
                    controller: emailController,
                    centerText: true,
                    height: AppLayout.onboardingControlHeight,
                    centerVertically: true,
                  ),
                  const SizedBox(height: 12),
                  RoundedInputField(
                    controller: passwordController,
                    obscureText: true,
                    centerText: true,
                    errorText: '비밀번호가 옳지 않습니다.',
                    errorTrailing: const Text(
                      '비밀번호 찾기',
                      style: kLoginLinkStyle,
                    ),
                    height: AppLayout.onboardingControlHeight,
                    centerVertically: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/login_error_component_402.png'),
    );
  });
}

class _ComponentGallery extends StatelessWidget {
  const _ComponentGallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const BrandLogo(width: 110),
              const SizedBox(height: 18),
              const RegisterProgressBar(step: 3),
              const SizedBox(height: 18),
              const PlantCharacterArt(width: 120),
              const SizedBox(height: 18),
              const RoundedInputField(
                label: '닉네임',
                hintText: '닉네임을 입력하세요.',
                height: AppLayout.onboardingControlHeight,
                labelGap: 5,
                centerVertically: true,
                labelColor: kOrangeMain,
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: '다음',
                variant: PrimaryButtonVariant.enabled,
                onPressed: () {},
                height: AppLayout.onboardingControlHeight,
                textStyle: kLoginButtonStyle,
              ),
              const SizedBox(height: 12),
              const PrimaryButton(
                label: '비활성',
                variant: PrimaryButtonVariant.disabled,
                onPressed: null,
                height: AppLayout.onboardingControlHeight,
                textStyle: kLoginButtonStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
