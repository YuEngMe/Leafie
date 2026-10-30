import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 시안 SVG의 드롭 섀도를 그 그림의 실루엣으로 다시 그린다.
///
/// Figma는 그림자를 SVG `<filter>`로 내보내는데 flutter_svg는 이 요소를
/// 그리지 않는다(`unhandled element <filter/>`). 흰 원 아이콘이 흰 배경에
/// 묻혀 사라지므로, 같은 그림을 [opacity]의 검정으로 칠해 [stdDeviation]만큼
/// 흐린 뒤 원본 밑에 깐다. Figma 필터(SourceAlpha → feGaussianBlur →
/// 알파 [opacity])와 같은 계산이고, stdDeviation은 Flutter의 sigma와 같다.
class SvgDropShadow extends StatelessWidget {
  const SvgDropShadow({
    super.key,
    required this.stdDeviation,
    required this.opacity,
    this.color = Colors.black,
    required this.child,
  });

  /// `<feGaussianBlur stdDeviation>`.
  final double stdDeviation;

  /// 그림자 색 행렬의 알파 값.
  final double opacity;

  /// 그림자 색(알파 제외). 시안 대부분은 검정이다.
  final Color color;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: stdDeviation,
            sigmaY: stdDeviation,
          ),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              color.withValues(alpha: opacity),
              BlendMode.srcIn,
            ),
            child: child,
          ),
        ),
        child,
      ],
    );
  }
}
