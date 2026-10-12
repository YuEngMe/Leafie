import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// 시안의 안쪽 그림자(CSS `box-shadow: inset ...`)를 그리는 상자.
///
/// Flutter의 BoxShadow에는 inset이 없다. `BlurStyle.inner`도 그림자 도형의
/// 안쪽 가장자리만 흐릴 뿐 상자 바깥에 그려져, 시안과 반대로 테두리 밖이
/// 어두워진다. 그래서 상자 모양으로 자른 캔버스 위에 "상자를 [BoxShadow.offset]
/// 만큼 옮기고 spread만큼 줄인 구멍"을 뺀 넓은 판을 흐려 칠한다. 구멍 밖으로
/// 남은 부분이 안쪽 가장자리에 번져 CSS inset 그림자와 같은 모양이 된다.
///
/// 흐림 값은 앱의 다른 BoxShadow와 같은 환산([BoxShadow.toPaint])을 쓴다.
/// 그래서 테스트의 `debugDisableShadows`가 켜지면 다른 그림자처럼 흐림 없이
/// 찍힌다.
class InsetShadowBox extends StatelessWidget {
  const InsetShadowBox({
    super.key,
    required this.color,
    required this.shadows,
    this.borderRadius = BorderRadius.zero,
    this.child,
  });

  /// 상자 바탕색. 그림자는 이 위, [child] 아래에 그린다.
  final Color color;

  /// 안쪽 그림자들. offset·blurRadius·spreadRadius는 CSS inset과 같은 뜻이다.
  final List<BoxShadow> shadows;

  final BorderRadius borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: InsetShadowPainter(
        color: color,
        shadows: shadows,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

/// [InsetShadowBox]의 바탕과 안쪽 그림자를 칠한다. 테스트가 값을 읽을 수
/// 있게 공개한다.
class InsetShadowPainter extends CustomPainter {
  const InsetShadowPainter({
    required this.color,
    required this.shadows,
    required this.borderRadius,
  });

  final Color color;
  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final box = borderRadius.toRRect(Offset.zero & size);
    canvas.drawRRect(box, Paint()..color = color);
    for (final shadow in shadows) {
      // 구멍 바깥 판은 흐림이 상자 안까지 번질 만큼만 넓으면 된다.
      final margin =
          shadow.blurRadius * 2 +
          shadow.spreadRadius.abs() +
          shadow.offset.distance;
      final hole = box.shift(shadow.offset).deflate(shadow.spreadRadius);
      final plate = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(box.outerRect.inflate(margin))
        ..addRRect(hole);
      canvas
        ..save()
        ..clipRRect(box)
        ..drawPath(plate, shadow.toPaint())
        ..restore();
    }
  }

  @override
  bool shouldRepaint(InsetShadowPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius ||
      !listEquals(shadows, oldDelegate.shadows);
}
