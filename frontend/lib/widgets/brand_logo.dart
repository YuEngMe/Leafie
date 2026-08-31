import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 142, this.markWidthFactor = 0.82});

  final double width;
  final double markWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Leafie',
      image: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/leafie_mark.png',
            width: width * markWidthFactor,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 5),
          Image.asset(
            'assets/images/leafie_wordmark.png',
            width: width,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
