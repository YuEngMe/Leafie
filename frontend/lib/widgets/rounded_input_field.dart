import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

// 캐릭터 등록에서 쓰는 입력칸(Figma node 1841:475, 1841:479).
// 회원가입 쪽 AppTextField와 달리 테두리 대신 그림자를 쓰고 라벨이 오렌지다.
class RoundedInputField extends StatelessWidget {
  const RoundedInputField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.suffix,
    this.onTap,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final Widget? suffix;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: kItemStyle.copyWith(color: kOrange)),
        const SizedBox(height: 8),
        Container(
          height: 51,
          decoration: BoxDecoration(
            color: kBackgroundWhite,
            borderRadius: BorderRadius.circular(kButtonRadius),
            boxShadow: const [
              BoxShadow(color: Color(0x2E000000), blurRadius: 2),
            ],
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            style: kBodyStyle.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: kCaptionStyle,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}
