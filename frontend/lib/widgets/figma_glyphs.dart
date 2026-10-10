import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_colors.dart';

// Figma가 내보낸 벡터 아이콘을 그대로 옮긴 글리프.
//
// 각 SVG가 단색 path 한두 개뿐이라 flutter_svg 대신 CustomPainter로 좌표를
// 그대로 옮겼다. 상수는 Figma export의 원본 좌표계다. 눈 아이콘처럼 시안
// 에셋을 받아 둔 것은 flutter_svg로 그린다.

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

/// 비밀번호 칸의 눈 아이콘이 화면 계열마다 쓰는 시안 에셋.
///
/// 인증 화면(로그인 4534:1343·회원가입 4534:2076·비밀번호 변경 4534:2784)은
/// 사선을 잘라낸 Subtract 그룹(427320837)을, 기기연결(PIN 5728:5761·Wi-Fi
/// 5728:5842)은 흰 사선을 겹친 옛 그룹(427320836)을 쓴다. 생김새는 같지만
/// 상자 크기와 칸 안 위치가 달라 에셋을 따로 둔다.
enum FigmaEyeVariant {
  auth(
    closedAsset: 'assets/images/icon_eye_closed.svg',
    closedSize: Size(22.6274, 27.393),
    // 칸 오른쪽 끝에서 아이콘 상자 오른쪽 끝까지(334 − 292 − 22.63).
    rightInset: 19.37,
    // 뜬 눈(4534:1427, top 18)은 감은 눈 상자(top 12)보다 6 아래, x는 같다.
    openOffset: Offset(0, 6),
  ),
  sensor(
    closedAsset: 'assets/images/icon_eye_closed_sensor.svg',
    closedSize: Size(23.5124, 26.0163),
    // 334 − 282 − 23.51.
    rightInset: 28.49,
    // 기기연결엔 뜬 눈 시안이 없다. 인증 화면 뜬 눈의 동공(11.45, 7.31)을
    // 이 상자의 동공(12, 13)에 맞춘다.
    openOffset: Offset(0.55, 5.69),
  );

  const FigmaEyeVariant({
    required this.closedAsset,
    required this.closedSize,
    required this.rightInset,
    required this.openOffset,
  });

  final String closedAsset;
  final Size closedSize;
  final double rightInset;
  final Offset openOffset;
}

/// 비밀번호 가리기 눈 아이콘. 시안 SVG를 그대로 그린다.
///
/// 감은 눈 상자 안에 뜬 눈(4534:1427, 22.63×14.58)을 겹쳐 두어, 토글해도
/// 아이콘이 차지하는 자리와 동공 위치가 변하지 않는다.
class FigmaEyeIcon extends StatelessWidget {
  const FigmaEyeIcon({
    super.key,
    this.obscured = true,
    this.variant = FigmaEyeVariant.auth,
  });

  static const String openAsset = 'assets/images/icon_eye_open.svg';
  static const Size openSize = Size(22.6276, 14.5834);

  /// 사선이 그어진 가려짐 상태인지.
  final bool obscured;
  final FigmaEyeVariant variant;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: variant.closedSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (obscured)
            Positioned.fill(child: SvgPicture.asset(variant.closedAsset))
          else
            Positioned(
              left: variant.openOffset.dx,
              top: variant.openOffset.dy,
              width: openSize.width,
              height: openSize.height,
              child: SvgPicture.asset(openAsset),
            ),
        ],
      ),
    );
  }
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
