import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

// Figma 컴포넌트 "버튼"(node 2097:9460): 높이 52, 반경 50,
// 활성은 오렌지_메인 / 비활성은 제일연한회색. 글자는 항상 흰색 16 세미볼드.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed});

  final String label;

  /// null이면 Figma의 비활성(회색) 상태로 그린다.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kOrangeMain,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kGrayLightest,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kButtonRadius),
          ),
        ),
        child: Text(
          label,
          style: kItemStyle.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
