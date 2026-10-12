import 'package:flutter/material.dart';

/// 날짜 휠의 한 열(연·월·일 중 하나).
///
/// 시안의 날짜 휠은 고른 줄 위아래만 간격이 넓고 나머지 줄은 [itemExtent]
/// 간격으로 쌓인다(주황 시트 4534:921~944 / 일정 추가 4534:6088~6101).
/// ListWheelScrollView는 줄 간격이 하나뿐이라, 줄마다 고른 줄에서 떨어진
/// 거리만큼 위로 [gapAbove]·아래로 [gapBelow]를 더 밀어 시안 간격을 만든다.
/// 이웃 줄까지는 거리에 비례해 밀어 스크롤하는 동안에도 줄이 튀지 않는다.
///
/// 휠은 평평하게 쌓인다(시안에 원근 왜곡이 없다). 휠 가운데가 고른 줄의
/// 글자 중심이 되도록 부모가 자리를 잡는다. 밀린 줄이 영역 밖에 비치지 않게
/// 휠 영역 밖은 잘린다.
class DateWheelColumn extends StatelessWidget {
  const DateWheelColumn({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemExtent,
    required this.itemBuilder,
    required this.onSelectedItemChanged,
    this.gapAbove = 0,
    this.gapBelow = 0,
  });

  final FixedExtentScrollController controller;
  final int itemCount;

  /// 고른 줄을 뺀 나머지 줄끼리의 간격.
  final double itemExtent;

  /// 고른 줄과 바로 위 줄 사이를 [itemExtent]보다 더 벌릴 양. 음수면 좁힌다.
  final double gapAbove;

  /// 고른 줄과 바로 아래 줄 사이를 [itemExtent]보다 더 벌릴 양.
  final double gapBelow;

  /// 줄 하나를 그린다. [selected]는 지금 가운데에 온 줄인지다.
  final Widget Function(BuildContext context, int index, bool selected)
  itemBuilder;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemExtent,
      diameterRatio: 100,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final position = controller.hasClients
                ? controller.offset / itemExtent
                : controller.initialItem.toDouble();
            final distance = index - position;
            final shift = distance < 0
                ? distance.clamp(-1.0, 0.0) * gapAbove
                : distance.clamp(0.0, 1.0) * gapBelow;
            final selected = controller.hasClients
                ? controller.selectedItem == index
                : controller.initialItem == index;
            return Transform.translate(
              offset: Offset(0, shift),
              child: itemBuilder(context, index, selected),
            );
          },
        ),
      ),
    );
  }
}

/// 날짜 휠의 고른 줄 띠. 바탕이 반투명이어도 그림자는 띠 **바깥**에만 그린다.
///
/// BoxShadow는 상자 밑에 그림자 도형을 통째로 깔아서, 반투명 바탕 밑으로
/// 그림자가 비쳐 띠가 시안(#FFBC51)보다 어둡게(#E4A94D) 보였다. 시안의 그림자
/// (CSS box-shadow)는 상자 안쪽을 비우므로, 띠 모양을 뺀 영역에만 그림자를
/// 칠하고 그 위에 바탕을 칠한다. 흐림 환산은 앱의 다른 BoxShadow와 같은
/// [BoxShadow.toPaint]를 쓴다.
class DateWheelHighlight extends StatelessWidget {
  const DateWheelHighlight({
    super.key,
    required this.color,
    required this.shadow,
    required this.borderRadius,
  });

  final Color color;
  final BoxShadow shadow;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DateWheelHighlightPainter(
        color: color,
        shadow: shadow,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// [DateWheelHighlight]를 칠한다. 테스트가 값을 읽을 수 있게 공개한다.
class DateWheelHighlightPainter extends CustomPainter {
  const DateWheelHighlightPainter({
    required this.color,
    required this.shadow,
    required this.borderRadius,
  });

  final Color color;
  final BoxShadow shadow;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final box = borderRadius.toRRect(Offset.zero & size);
    final margin =
        shadow.blurRadius * 2 +
        shadow.spreadRadius.abs() +
        shadow.offset.distance;
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(box.outerRect.inflate(margin))
      ..addRRect(box);
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        box.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      )
      ..restore()
      ..drawRRect(box, Paint()..color = color);
  }

  @override
  bool shouldRepaint(DateWheelHighlightPainter oldDelegate) =>
      color != oldDelegate.color ||
      shadow != oldDelegate.shadow ||
      borderRadius != oldDelegate.borderRadius;
}
