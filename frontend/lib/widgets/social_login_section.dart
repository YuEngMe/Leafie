import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/social_login_button.dart';

/// Figma node 2315:2323의 구분선과 소셜 로그인 버튼 묶음.
class SocialLoginSection extends StatelessWidget {
  const SocialLoginSection({
    super.key,
    required this.onNaver,
    required this.onKakao,
    required this.onApple,
  });

  final VoidCallback onNaver;
  final VoidCallback onKakao;
  final VoidCallback onApple;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppLayout.loginDividerLeftInset,
            right: AppLayout.loginDividerRightInset,
          ),
          child: Row(
            children: [
              const Expanded(child: Divider(color: kTextLight)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.loginDividerLabelInset,
                ),
                child: Text('간편로그인', style: kLoginDividerStyle),
              ),
              const Expanded(child: Divider(color: kTextLight)),
            ],
          ),
        ),
        const SizedBox(height: AppLayout.loginDividerToSocialGap),
        Padding(
          padding: const EdgeInsets.only(
            left: AppLayout.loginSocialLeftInset,
            right: AppLayout.loginSocialRightInset,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SocialLoginButton(
                label: '네이버',
                color: const Color(0xFF4CAF50),
                onTap: onNaver,
              ),
              SocialLoginButton(
                label: '카카오',
                color: const Color(0xFFF5E14C),
                onTap: onKakao,
              ),
              SocialLoginButton(
                label: '애플',
                color: Colors.black,
                onTap: onApple,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
