import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';

/// Figma가 내보낸 벡터 아이콘을 그대로 옮긴 글리프.
///
/// 각 SVG가 단색 path 한두 개뿐이라 flutter_svg 대신 CustomPainter로 좌표를
/// 그대로 옮겼다. 상수는 Figma export의 원본 좌표계다. 그라디언트나 mask가
/// 붙은 에셋이 들어오면 그때 flutter_svg를 도입한다.
///
/// 눈 아이콘이 쓰는 회색. Figma는 여기서만 #B1B1B1을 쓴다.
const Color _kEyeGray = Color(0xFFB1B1B1);

class _PolylinePainter extends CustomPainter {
  const _PolylinePainter({
    required this.points,
    required this.viewBox,
    required this.color,
    required this.strokeWidth,
  });

  final List<Offset> points;
  final Size viewBox;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / viewBox.width;
    final scaleY = size.height / viewBox.height;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = Offset(
        points[index].dx * scaleX,
        points[index].dy * scaleY,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        // stroke는 viewBox 대비 균일하게 커지도록 평균 배율을 쓴다.
        ..strokeWidth = strokeWidth * (scaleX + scaleY) / 2,
    );
  }

  @override
  bool shouldRepaint(_PolylinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.viewBox != viewBox ||
      oldDelegate.points != points;
}

/// Figma node 2315:2486 + 2315:2487. 오렌지 원 위의 흰 체크.
class FigmaCheckedCircle extends StatelessWidget {
  const FigmaCheckedCircle({super.key, this.size = 26});

  /// Figma 원 지름(2315:2486).
  static const double figmaCircleSize = 26;

  /// 원 안 체크(2315:2487)의 좌상단 오프셋과 크기.
  static const Offset figmaCheckOffset = Offset(8, 8);
  static const Size figmaCheckSize = Size(11.6, 11.2524);

  final double size;

  @override
  Widget build(BuildContext context) {
    final scale = size / figmaCircleSize;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Figma는 kOrangeMain이 아니라 포인트 오렌지(#FFB222)를 쓴다.
          const DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: kOrange),
            child: SizedBox.expand(),
          ),
          Positioned(
            left: figmaCheckOffset.dx * scale,
            top: figmaCheckOffset.dy * scale,
            width: figmaCheckSize.width * scale,
            height: figmaCheckSize.height * scale,
            child: const FigmaCheckMark(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Figma node 2315:2487 / 2315:2494의 체크 폴리라인.
/// Figma node 2570:2036. 회원 탈퇴 동의 체크박스.
///
/// 사각 테두리와 체크 선이 같은 색이고 상태에 따라 색만 바뀐다.
class FigmaConsentCheckbox extends StatelessWidget {
  const FigmaConsentCheckbox({super.key, required this.checked});

  static const Size figmaSize = Size(23, 23);

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final color = checked ? kOrangeMain : kTextLight;
    return SizedBox.fromSize(
      size: figmaSize,
      child: CustomPaint(
        // 테두리는 1px, 체크 선은 2px이라 따로 그린다(2570:2036).
        painter: _PolylinePainter(
          points: const [Offset(5, 10.5), Offset(9.9, 17), Offset(19, 4)],
          viewBox: figmaSize,
          color: color,
          strokeWidth: 2,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: color)),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class FigmaCheckMark extends StatelessWidget {
  const FigmaCheckMark({super.key, this.color = kOrange});

  /// node 2315:2494 원본 좌표(11.8399 x 11.2357).
  static const Size figmaSize = Size(11.8399, 11.2357);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PolylinePainter(
        points: const [
          Offset(0.781795, 5.09515),
          Offset(4.37085, 9.59515),
          Offset(11.0362, 0.595154),
        ],
        viewBox: figmaSize,
        color: color,
        strokeWidth: 2,
      ),
      size: figmaSize,
    );
  }
}

/// Figma node 2315:2495의 오른쪽 꺾쇠.
class FigmaChevronRight extends StatelessWidget {
  const FigmaChevronRight({super.key, this.color = kGrayLightest});

  /// node 2315:2495 원본 좌표(8.00638 x 14.346).
  static const Size figmaSize = Size(8.00638, 14.346);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PolylinePainter(
        points: const [
          Offset(0.739621, 0.673023),
          Offset(6.65434, 7.17302),
          Offset(0.739621, 13.673),
        ],
        viewBox: figmaSize,
        color: color,
        strokeWidth: 2,
      ),
      size: figmaSize,
    );
  }
}

/// Figma node 2315:2449의 비밀번호 가리기 눈 아이콘.
///
/// Figma는 눈 윤곽(2315:2450) + 동공(2315:2451) + 흰 사선(2315:2452) +
/// 회색 사선(2315:2453) 네 레이어를 겹친다. 흰 사선은 회색 사선 아래에서
/// 눈 윤곽을 지워 슬래시가 파인 것처럼 보이게 하는 용도다.
class FigmaEyeIcon extends StatelessWidget {
  const FigmaEyeIcon({super.key, this.obscured = true, this.color = _kEyeGray});

  /// 2315:2449 기준 좌표계. left 290~313.5, top 11~37 범위를 감싼다.
  static const Size figmaSize = Size(24, 26);

  /// 슬래시가 그어진 가려짐 상태인지. Figma에는 이 상태만 있다.
  final bool obscured;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EyePainter(obscured: obscured, color: color),
      size: figmaSize,
    );
  }
}

class _EyePainter extends CustomPainter {
  const _EyePainter({required this.obscured, required this.color});

  final bool obscured;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 좌표는 Figma의 절대 위치(left 290, top 11)를 원점으로 옮긴 값이다.
    final scaleX = size.width / FigmaEyeIcon.figmaSize.width;
    final scaleY = size.height / FigmaEyeIcon.figmaSize.height;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.74682
      ..strokeJoin = StrokeJoin.round;

    // 눈 윤곽(2315:2450): Figma 좌표에서 left 290 - 290 = 0, top 18.56 - 11.
    canvas.save();
    canvas.translate(0, 7.56);
    canvas
      ..drawPath(
        Path()
          ..moveTo(20.6446, 5.04353)
          ..cubicTo(12.3243, -1.84011, 6.24105, 1.05132, 1.93412, 4.7848)
          ..cubicTo(0.491988, 6.03492, 0.525823, 8.27719, 2.00244, 9.48637)
          ..cubicTo(10.5932, 16.5213, 16.7928, 13.5148, 20.8707, 9.49837)
          ..cubicTo(22.1422, 8.24603, 22.0197, 6.18119, 20.6446, 5.04353),
        outline,
      )
      ..restore();

    // 동공(2315:2451): left 297 - 290 = 7, top 20 - 11 = 9, 지름 10.
    canvas.drawCircle(const Offset(7 + 5, 9 + 5), 5, Paint()..color = color);

    if (obscured) {
      // 사선 두 개(2315:2452, 2315:2453). 좌상에서 우하로 긋고, 흰 선이
      // 회색 선보다 우측 0.9 / 위 1.15만큼 비껴 있어 슬래시 옆에 파임이
      // 생긴다. Figma 좌표(left 292.9 / 292, top 12 / 13.15) 그대로다.
      final slash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas
        ..drawLine(
          const Offset(5.4, 1.6),
          const Offset(18.1, 23.6),
          slash..color = Colors.white,
        )
        ..drawLine(
          const Offset(4.5, 2.75),
          const Offset(17.2, 24.75),
          slash..color = color,
        );
    }

    // canvas.scale이 stroke 두께까지 함께 키우므로 별도 보정은 없다.
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EyePainter oldDelegate) =>
      oldDelegate.obscured != obscured || oldDelegate.color != color;
}

/// Figma node 2353:1042의 회원가입 중단 모달 구분선.
///
/// 가로선 하나와 그 중앙에서 아래로 내려가는 세로선이 한 path로 묶여 있다.
/// 좌우 24.7px, 아래 7.5px를 비워 모서리 곡선을 침범하지 않는다.
class FigmaDialogDivider extends StatelessWidget {
  const FigmaDialogDivider({super.key, this.color = kOrange});

  /// node 2353:1042 원본 좌표(258.634 x 45.6098).
  static const Size figmaSize = Size(258.634, 45.6098);
  static const double figmaStrokeWidth = 1.07317;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DialogDividerPainter(color: color),
      size: figmaSize,
    );
  }
}

class _DialogDividerPainter extends CustomPainter {
  const _DialogDividerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / FigmaDialogDivider.figmaSize.width;
    final scaleY = size.height / FigmaDialogDivider.figmaSize.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          FigmaDialogDivider.figmaStrokeWidth * (scaleX + scaleY) / 2;
    // 원본의 y=0.536585는 stroke 두께의 절반이라 화면에서는 맨 윗줄이다.
    final top = 0.536585 * scaleY;
    final centerX = 129.317 * scaleX;
    canvas
      ..drawLine(Offset(0, top), Offset(size.width, top), paint)
      ..drawLine(Offset(centerX, top), Offset(centerX, size.height), paint);
  }

  @override
  bool shouldRepaint(_DialogDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}
