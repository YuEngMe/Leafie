import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width = 142,
    this.markWidthFactor = 0.82,
    this.gap = 5,
  });

  final double width;
  final double markWidthFactor;

  /// 심볼 바닥에서 워드마크 top까지. 시안 4792:106은 7이다.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Leafie',
      image: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/leafie_logo_symbol.png',
            width: width * markWidthFactor,
            fit: BoxFit.contain,
          ),
          SizedBox(height: gap),
          Image.asset(
            'assets/images/leafie_logo_word.png',
            width: width,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
