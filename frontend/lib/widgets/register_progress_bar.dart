import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';

// 캐릭터 등록 진행바(Figma node 2307:2015). 물결 다섯 개가 한 단계씩을 뜻하고
// 지나온 단계만 오렌지로 칠한다. 최신 시안(4534:22)은 이름·종·정보·성격·
// 꾸미기(바디+컬러) 5단계다 — 바디(5028:1193)와 컬러(4534:507) 모두 끝까지
// 주황이다. SVG를 그대로 넣는 대신 같은 모양을 그리는 이유는 단계 수만큼
// 파일을 따로 두지 않기 위해서다.
class RegisterProgressBar extends StatelessWidget {
  const RegisterProgressBar({
    super.key,
    required this.step,
    this.totalSteps = 5,
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
    // 시안 SVG(4534:528)는 243 폭 안에서 x 2.5~240.5에 선을 긋는다. 0~243에
    // 그리면 양 끝이 4px씩 길어진다. 끝은 둥글게 두어 물결 이음매에 틈이
    // 보이지 않게 한다.
    const inset = 2.5;
    final segment = (size.width - inset * 2) / totalSteps;
    final midY = size.height / 2;
    final amplitude = size.height / 2 - 3.2; // 선 두께 6.425의 절반만큼 뺀다

    for (var i = 0; i < totalSteps; i++) {
      final paint = Paint()
        ..color = i < step ? kOrangeMain : kProgressInactive
        ..strokeWidth = 6.425
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final startX = inset + segment * i;
      final endX = startX + segment;
      final peakY = i.isEven ? midY - amplitude : midY + amplitude;

      // 시안 물결 하나는 곡선 두 개로, 가운데에서 꼭대기(peakY)에 닿는다
      // (Vector 1203: M2.5 11.2 C2.5 11.2 8.96 3.2 27 3.2 C45 3.2 51.5 11.2
      // 51.5 11.2, 폭 49). 곡선 하나로 그리면 꼭대기가 3/4만 올라가 물결이
      // 위아래로 2px씩 얕아진다.
      final path = Path()
        ..moveTo(startX, midY)
        ..cubicTo(
          startX,
          midY,
          startX + segment * 0.132,
          peakY,
          startX + segment * 0.5,
          peakY,
        )
        ..cubicTo(endX - segment * 0.132, peakY, endX, midY, endX, midY);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.step != step || oldDelegate.totalSteps != totalSteps;
}
