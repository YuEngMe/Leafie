import 'package:flutter/material.dart';

// 간편로그인 원형 버튼(Figma node 1656:621~625). 시안은 라벨 없이
// 브랜드 색 원만 늘어놓는다. 실제 로고 SVG는 아직 없어 색으로만 구분하고,
// 스크린 리더를 위해 이름은 semanticLabel로 남긴다.
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label 로그인',
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 49.4,
          height: 49.4,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
