import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.obscureText = false,
    this.controller,
    this.hintText,
    this.errorText,
  });

  final String label;
  final bool obscureText;
  final TextEditingController? controller;
  final String? hintText;
  final String? errorText;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: kItemStyle,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _obscured,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: kBodyStyle.copyWith(color: kTextLight),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kButtonRadius),
              borderSide: BorderSide(
                color: hasError ? Colors.red : kGrayLightest,
              ),
            ),
            // 비밀번호 입력에만 표시/숨김 토글 아이콘을 보여준다.
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.errorText!,
              style: kCaptionStyle.copyWith(color: Colors.red),
            ),
          ),
      ],
    );
  }
}
