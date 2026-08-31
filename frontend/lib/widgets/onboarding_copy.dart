import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

/// Figma nodes 2315:2275, 2315:2514의 두 줄 온보딩 안내 문구.
class OnboardingCopy extends StatelessWidget {
  const OnboardingCopy({
    super.key,
    required this.title,
    required this.subtitle,
    this.textAlign = TextAlign.left,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    // 두 노드 모두 타이틀 바닥 25px, 서브 상단 35px으로 10px을 띄운다.
    this.gap = 10,
    this.titleStyle,
    this.subtitleStyle,
  });

  final String title;
  final String subtitle;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;
  final double gap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: titleStyle ?? kTitleStyle.copyWith(height: 1),
        ),
        SizedBox(height: gap),
        Text(
          subtitle,
          textAlign: textAlign,
          style:
              subtitleStyle ??
              kSmallStyle.copyWith(height: 1, color: kOnboardingSubtitle),
        ),
      ],
    );
  }
}
