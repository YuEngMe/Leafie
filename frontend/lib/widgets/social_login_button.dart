import 'package:flutter/material.dart';

// 간편로그인 원형 버튼 (아이콘 자리 + 라벨). 실제 로고는 나중에 Image.asset으로 교체.
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }
}
