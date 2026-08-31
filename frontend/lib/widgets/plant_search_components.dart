import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

/// Figma node 2318:3777. 사진 인식 결과를 보여주는 폴라로이드 카드.
///
/// 뒤에 연노랑 종이가 -6.31도 기울어 깔리고 그 위에 흰 카드가 올라간다.
class PlantResultCard extends StatelessWidget {
  const PlantResultCard({
    super.key,
    required this.imageProvider,
    required this.speciesName,
    required this.familyName,
    required this.bloomSeason,
  });

  /// 흰 카드(2318:3764) 크기.
  static const Size cardSize = Size(303, 420);

  /// 뒤 종이까지 포함한 전체 크기(2318:3777).
  static const Size totalSize = Size(347.32, 450.75);

  final ImageProvider imageProvider;
  final String speciesName;
  final String familyName;
  final String bloomSeason;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: totalSize,
      child: Stack(
        children: [
          // 뒤 종이(2318:3752). 내용 없이 색과 기울기만 남긴다.
          Positioned(
            left: 0,
            top: 33.3,
            child: Transform.rotate(
              angle: -6.31 * 3.1415926535 / 180,
              child: Container(
                width: cardSize.width,
                height: cardSize.height,
                decoration: BoxDecoration(
                  color: kProfileCardYellow,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Color(0x26000000), blurRadius: 10),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 22.16,
            top: 15.38,
            child: _PolaroidFront(
              imageProvider: imageProvider,
              rows: [
                ('식물명', speciesName),
                ('식물과', familyName),
                ('개화기', bloomSeason),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolaroidFront extends StatelessWidget {
  const _PolaroidFront({required this.imageProvider, required this.rows});

  final ImageProvider imageProvider;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PlantResultCard.cardSize.width,
      height: PlantResultCard.cardSize.height,
      decoration: BoxDecoration(
        color: kBackgroundWhite,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 10)],
      ),
      child: Stack(
        children: [
          // 사진(2318:3773): 카드 좌측 12, 상단 10, 279 x 265.
          Positioned(
            left: 12,
            top: 10,
            width: 279,
            height: 265,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
          for (var index = 0; index < rows.length; index++)
            // 첫 행 y=295(카드 기준), 이후 39.5씩 내려간다.
            Positioned(
              left: 17,
              top: 295 + index * 39.5,
              width: 263,
              child: _ResultRow(
                label: rows[index].$1,
                value: rows[index].$2,
                // 마지막 행 아래에는 구분선을 두지 않는다.
                showDivider: index < rows.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.showDivider,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 19,
          child: Row(
            children: [
              SizedBox(
                // Figma 라벨 폭은 35지만 Flutter Paperlogy가 더 넓게 잡혀
                // 3글자가 잘린다. 잘림 없이 들어가는 최소치로 넓힌다.
                width: 44,
                child: Text(
                  label,
                  style: kCaptionStyle.copyWith(
                    fontSize: 13,
                    color: kResultLabel,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: kBodyStyle.copyWith(color: Colors.black),
                ),
              ),
              // 값이 라벨을 뺀 폭의 가운데에 오도록 좌측 라벨 폭만큼 비운다.
              const SizedBox(width: 44),
            ],
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(top: 5.5),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
          ),
      ],
    );
  }
}

/// Figma component set 2318:3799. 인식 결과를 확인하는 버튼 쌍.
class PlantResultConfirmButtons extends StatelessWidget {
  const PlantResultConfirmButtons({
    super.key,
    required this.onConfirm,
    required this.onReject,
  });

  /// 버튼 하나 크기와 사이 간격(2318:3788 / 2318:3789).
  static const double buttonWidth = 149.2795;
  static const double buttonHeight = 44;
  static const double gap = 27.44;

  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          label: '맞아요',
          variant: PrimaryButtonVariant.enabled,
          width: buttonWidth,
          height: buttonHeight,
          showShadow: false,
          onPressed: onConfirm,
        ),
        const SizedBox(width: gap),
        PrimaryButton(
          label: '아니에요',
          // Figma는 회색이지만 실제로 누를 수 있는 버튼이라 콜백을 붙인다.
          variant: PrimaryButtonVariant.disabled,
          width: buttonWidth,
          height: buttonHeight,
          showShadow: false,
          onPressed: onReject,
        ),
      ],
    );
  }
}

/// Figma node 2318:3948. 카메라 프리뷰 위에 얹는 뷰파인더 가이드.
class CameraViewfinderOverlay extends StatelessWidget {
  const CameraViewfinderOverlay({super.key, this.color = kBackgroundWhite});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ViewfinderPainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({required this.color});

  /// 2318:3939 코너 마커와 2318:3944 플러스의 원본 수치.
  static const double _strokeWidth = 8;
  static const double _cornerRadius = 26.1048;
  static const double _armLength = 28.0149;
  static const double _plusLength = 38.5;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final inset = _strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - _strokeWidth,
      size.height - _strokeWidth,
    );
    final r = _cornerRadius;
    final arm = _armLength - r;

    // 네 모서리에 곡선 + 짧은 직선 두 개씩.
    for (final corner in [
      (rect.left, rect.top, 1.0, 1.0),
      (rect.right, rect.top, -1.0, 1.0),
      (rect.left, rect.bottom, 1.0, -1.0),
      (rect.right, rect.bottom, -1.0, -1.0),
    ]) {
      final (x, y, sx, sy) = corner;
      canvas.drawPath(
        Path()
          ..moveTo(x + sx * (r + arm), y)
          ..lineTo(x + sx * r, y)
          ..arcToPoint(
            Offset(x, y + sy * r),
            radius: Radius.circular(r),
            clockwise: sx * sy < 0,
          )
          ..lineTo(x, y + sy * (r + arm)),
        paint,
      );
    }

    // 중앙 플러스.
    final center = Offset(size.width / 2, size.height / 2);
    final half = _plusLength / 2;
    canvas
      ..drawLine(center.translate(0, -half), center.translate(0, half), paint)
      ..drawLine(center.translate(-half, 0), center.translate(half, 0), paint);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Figma node 2318:3831. 연·월·일 휠 세 개를 담은 날짜 선택 바텀시트.
class PlantDatePickerSheet extends StatefulWidget {
  const PlantDatePickerSheet({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<PlantDatePickerSheet> createState() => _PlantDatePickerSheetState();
}

class _PlantDatePickerSheetState extends State<PlantDatePickerSheet> {
  /// 시트 크기와 내부 좌표(2318:3803).
  static const double _sheetHeight = 325;
  static const double _rowExtent = 38.61;
  static const double _bandHeight = 39.69;

  late int _year = widget.initialDate.year;
  late int _month = widget.initialDate.month;
  late int _day = widget.initialDate.day;

  late final _yearController = FixedExtentScrollController(
    initialItem: _year - _firstYear,
  );
  late final _monthController = FixedExtentScrollController(
    initialItem: _month - 1,
  );
  late final _dayController = FixedExtentScrollController(
    initialItem: _day - 1,
  );

  static const int _firstYear = 2015;
  static const int _lastYear = 2035;

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _clampDay() {
    final maxDay = _daysInMonth;
    if (_day > maxDay) {
      _day = maxDay;
      _dayController.jumpToItem(maxDay - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _sheetHeight,
      decoration: const BoxDecoration(
        color: kOrangeMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 5)],
      ),
      child: Stack(
        children: [
          // 선택 밴드(2318:3823)는 휠 뒤에 깔린다.
          Positioned(
            left: 1,
            right: 1,
            top: 98.66,
            height: _bandHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFC588).withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x2E000000), blurRadius: 4),
                ],
              ),
            ),
          ),
          // Figma는 선택 행 위아래로 두 줄씩, 모두 다섯 줄만 보여준다.
          Positioned(
            left: 0,
            right: 0,
            top: 98.66 + _bandHeight / 2 - _rowExtent * 2.5,
            height: _rowExtent * 5,
            child: Row(
              children: [
                Expanded(
                  child: _DateWheel(
                    controller: _yearController,
                    itemCount: _lastYear - _firstYear + 1,
                    labelBuilder: (index) => '${_firstYear + index}년',
                    onSelected: (index) => setState(() {
                      _year = _firstYear + index;
                      _clampDay();
                    }),
                  ),
                ),
                Expanded(
                  child: _DateWheel(
                    controller: _monthController,
                    itemCount: 12,
                    labelBuilder: (index) => '${index + 1}월',
                    onSelected: (index) => setState(() {
                      _month = index + 1;
                      _clampDay();
                    }),
                  ),
                ),
                Expanded(
                  child: _DateWheel(
                    controller: _dayController,
                    itemCount: _daysInMonth,
                    labelBuilder: (index) => '${index + 1}일',
                    onSelected: (index) => setState(() => _day = index + 1),
                  ),
                ),
              ],
            ),
          ),
          // 확정 버튼(2318:3828)은 흰 바탕에 오렌지 글씨로 색이 반전된다.
          Positioned(
            left: 34,
            top: 241,
            width: 334,
            height: AppLayout.onboardingControlHeight,
            child: PrimaryButton(
              label: '다음',
              variant: PrimaryButtonVariant.enabled,
              height: AppLayout.onboardingControlHeight,
              background: kBackgroundWhite,
              textStyle: kLoginButtonStyle.copyWith(color: kOrangeMain),
              onPressed: () =>
                  Navigator.of(context).pop(DateTime(_year, _month, _day)),
            ),
          ),
          // 드래그 핸들(2318:3802).
          Positioned(
            left: 120.7,
            top: 297.11,
            width: 160.6,
            height: 6.44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF8E8E8E),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double rowExtent = _rowExtent;
}

class _DateWheel extends StatelessWidget {
  const _DateWheel({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _PlantDatePickerSheetState.rowExtent,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onSelected,
      // 시안은 원근 왜곡 없이 평평하게 쌓인다.
      perspective: 0.001,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) => Center(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final selected =
                  controller.hasClients && controller.selectedItem == index;
              return Text(
                labelBuilder(index),
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: selected ? 18 : 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? kBackgroundWhite
                      : kBackgroundWhite.withValues(alpha: 0.8),
                  height: 1,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
