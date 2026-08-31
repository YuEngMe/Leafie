import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

/// Figma component set `버튼` (2307:2088) variant mapping.
enum PrimaryButtonVariant {
  enabled('Frame 1707481526', '2307:2086'),
  disabled('Frame 1261154385', '2307:2087');

  const PrimaryButtonVariant(this.figmaValue, this.figmaNodeId);

  final String figmaValue;
  final String figmaNodeId;
}

// Figma 온보딩 컴포넌트 "버튼"(node 2307:2088): 높이 51, 반경 50,
// 활성은 오렌지_메인 / 비활성은 제일연한회색. 글자는 흰색 16 미디엄.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.variant,
    this.textStyle,
    this.width = double.infinity,
    this.height = AppLayout.onboardingControlHeight,
    this.showShadow = true,
    this.labelOffsetY = -1,
    this.background,
  });

  final String label;
  final TextStyle? textStyle;
  final double width;
  final double height;
  final PrimaryButtonVariant variant;
  final bool showShadow;
  final double labelOffsetY;

  /// 날짜 피커의 '다음'처럼 오렌지/흰색이 뒤집히는 자리에서만 넘긴다.
  final Color? background;

  /// null이면 Figma의 비활성(회색) 상태로 그린다.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kButtonRadius),
          boxShadow: showShadow
              ? const [BoxShadow(color: Color(0x2E000000), blurRadius: 2)]
              : null,
        ),
        child: ElevatedButton(
          onPressed: variant == PrimaryButtonVariant.enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: background ?? kOrangeMain,
            foregroundColor: Colors.white,
            disabledBackgroundColor: kGrayLightest,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kButtonRadius),
            ),
          ),
          child: Transform.translate(
            offset: Offset(0, labelOffsetY),
            child: Text(label, style: textStyle ?? kButtonStyle),
          ),
        ),
      ),
    );
  }
}
