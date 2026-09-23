import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';

// 캐릭터 등록 진행바(Figma node 2307:2015). 물결 다섯 개가 한 단계씩을 뜻하고
// 지나온 단계만 오렌지로 칠한다. SVG를 그대로 넣는 대신 같은 모양을 그리는
// 이유는 단계 수만큼 파일을 따로 두지 않기 위해서다.
class RegisterProgressBar extends StatelessWidget {
  const RegisterProgressBar({
    super.key,
    required this.step,
    this.totalSteps = 6,
  });

  /// 1부터 시작하는 현재 단계.
  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppLayout.progressHeight,
      width: AppLayout.progressWidth,
      child: CustomPaint(
        painter: _WavePainter(step: step, totalSteps: totalSteps),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  void paint(Canvas canvas, Size size) {
    // 물결 하나는 위로 볼록한 반원, 다음 하나는 아래로 볼록하게 번갈아 그린다.
    final segment = size.width / totalSteps;
    final midY = size.height / 2;
    final amplitude = size.height / 2 - 3.2; // 선 두께 6.425의 절반만큼 뺀다

    for (var i = 0; i < totalSteps; i++) {
      final paint = Paint()
        ..color = i < step ? kOrangeMain : kProgressInactive
        ..strokeWidth = 6.425
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final startX = segment * i;
      final endX = startX + segment;
      final peakY = i.isEven ? midY - amplitude : midY + amplitude;

      final path = Path()
        ..moveTo(startX, midY)
        ..cubicTo(
          startX + segment * 0.3,
          peakY,
          endX - segment * 0.3,
          peakY,
          endX,
          midY,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.step != step || oldDelegate.totalSteps != totalSteps;
}
