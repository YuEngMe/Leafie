import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({super.key, required this.label, this.obscureText = false});

  final String label;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: kLabelGreen,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorderGreen),
        ),
      ),
    );
  }
}
