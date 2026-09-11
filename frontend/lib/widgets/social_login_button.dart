import 'package:flutter/material.dart';

// 간편로그인 원형 버튼 (아이콘 자리 + 라벨). 실제 로고는 나중에 Image.asset으로 교체.
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 라벨까지 눌러도 반응하도록 InkWell을 전체를 감싸는 형태로 둔다.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
