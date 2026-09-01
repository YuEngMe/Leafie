import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

/// Figma node 2315:2323의 구분선과 소셜 로그인 버튼 묶음.
class SocialLoginSection extends StatelessWidget {
  const SocialLoginSection({
    super.key,
    required this.onNaver,
    required this.onKakao,
  });

  final VoidCallback onNaver;
  final VoidCallback onKakao;

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
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppLayout.loginSocialGap,
            children: [
              _SocialIconButton(
                asset: 'assets/images/social_naver.png',
                label: '네이버로 로그인',
                onTap: onNaver,
              ),
              _SocialIconButton(
                asset: 'assets/images/social_kakao.png',
                label: '카카오톡으로 로그인',
                onTap: onKakao,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Figma node 2353:41 / 2353:39를 그대로 내보낸 소셜 버튼.
///
/// 로고는 브랜드 자산이라 직접 그리지 않고 디자이너 export를 쓴다.
class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Image.asset(
          asset,
          width: AppLayout.loginSocialButtonSize,
          height: AppLayout.loginSocialButtonSize,
        ),
      ),
    );
  }
}
