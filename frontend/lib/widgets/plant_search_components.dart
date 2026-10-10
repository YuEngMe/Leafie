import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/date_wheel_column.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

/// Figma node 2318:3777. 사진 인식 결과를 보여주는 폴라로이드 카드.
///
/// 뒤에 연노랑 종이가 -6.31도 기울어 깔리고 그 위에 흰 카드가 올라간다.
/// 시안 4534:1187·4534:1198은 두 장의 가운데가 같은 점(카드 묶음 가운데)이다.
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
          // 뒤 종이(4534:1187). 내용 없이 색과 기울기만 남긴다. 흰 카드와
          // 같은 자리에서 가운데를 축으로 돌린다. 예전에는 기울어진 그림의
          // 바깥 상자 값(왼쪽 0·위 33.3)을 돌리기 전 자리로 써서 종이가
          // 왼쪽 아래로 22·18px 밀렸다. 그래서 시안처럼 오른쪽 위 모서리가
          // 흰 카드 위로 나오지 않고 왼쪽만 비어져 나와, 반대로 기운 것처럼
          // 보였다.
          Positioned(
            left: 22.16,
            top: 15.38,
            child: Transform.rotate(
              angle: -6.31 * 3.1415926535 / 180,
              child: Container(
                width: cardSize.width,
                height: cardSize.height,
                decoration: BoxDecoration(
                  color: kProfileCardYellow,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [_cardShadow],
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

/// 4534:1187·4534:1198 그림자: 흐림 10, 검정 15%. Figma/CSS 흐림은 2σ라
/// σ=5이고, Flutter blurRadius는 σ = r·0.57735 + 0.5라 r ≈ 7.79다. 흐림 10을
/// 그대로 넣으면 σ 6.27로 더 넓게 퍼져 시안보다 옅게 보였다.
const BoxShadow _cardShadow = BoxShadow(
  color: Color(0x26000000),
  blurRadius: 7.79,
);

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
        boxShadow: const [_cardShadow],
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
        // 구분선 4534:1205/1206: #D4D4D4 1px, 카드 기준 y 322·361(행 글자
        // 상자 바닥에서 8 아래).
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFD4D4D4)),
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

/// 연·월·일 휠 세 개를 담은 주황 날짜 선택 바텀시트.
///
/// 식물 등록(4534:877 "캐릭터 등록9")과 캐릭터 정보 수정(4534:20112
/// "정보수정 4")이 같은 시트를 쓴다. 두 시안은 버튼 문구('다음'/'수정하기')만
/// 다르고 시트·휠·띠 값이 모두 같다. 아래 좌표는 시트 top(y=549) 기준이다.
///
/// 시트 뒤 회색 핸들바(4534:919/4534:20157)는 시안에서 시트 아래 레이어라
/// 보이지 않으므로 그리지 않는다. 시트가 화면 바닥에 붙으므로 하단
/// SafeArea는 시트 안에서 더하지 않는다 — 더하면 시트가 34px 커지고 버튼이
/// 휠 위로 밀려 올라간다.
class PlantDatePickerSheet extends StatefulWidget {
  const PlantDatePickerSheet({
    super.key,
    required this.initialDate,
    this.maximumDate,
    this.buttonLabel = '다음',
    this.firstYear = 2015,
    this.lastYear = 2035,
  });

  final DateTime initialDate;

  /// 이 날짜 뒤를 고르고 버튼을 누르면 닫지 않고 안내만 띄운다.
  final DateTime? maximumDate;

  final String buttonLabel;
  final int firstYear;
  final int lastYear;

  /// 4534:920 시트 402x325.
  static const double sheetHeight = 325;

  /// 고르지 않은 줄끼리의 간격. 4534:20161→20165 글자 중심 582.79→621.40.
  static const double rowExtent = 38.61;

  /// 고른 줄 글자 중심(666.43)과 위·아래 줄(621.40 / 713.61)의 간격이
  /// [rowExtent]보다 넓은 만큼. 45.03-38.61, 47.18-38.61.
  static const double gapAbove = 6.42;
  static const double gapBelow = 8.57;

  /// 고른 줄 글자 중심. 4534:20181 666.43-549.
  static const double selectedCenter = 117.43;

  /// 4534:940 띠. y=647.664, 39.686 높이, x=1 w=399.954.
  static const double highlightTop = 647.664 - 549;
  static const double highlightHeight = 39.686;

  /// 4534:945 버튼. y=790.
  static const double buttonTop = 790 - 549;

  /// 연도는 왼쪽 정렬 x=60(고른 줄 60.33), 월·일은 가운데 정렬
  /// x=201.16 / 320.84(4534:20161~20182).
  static const double yearLeft = 60;
  static const double monthCenter = 201.16;
  static const double dayCenter = 320.84;

  @override
  State<PlantDatePickerSheet> createState() => _PlantDatePickerSheetState();
}

class _PlantDatePickerSheetState extends State<PlantDatePickerSheet> {
  /// 4534:940 rgba(255,197,136,0.42). 주황 위에 겹쳐 #FFBC51로 보인다.
  static const Color _highlight = Color(0x6BFFC588);

  /// 휠 영역 반높이. 위아래 둘째 줄(가운데에서 83.64 / 85.75)까지 보이고
  /// 셋째 줄은 시트 위 가장자리·버튼에 비치지 않게 자른다.
  static const double _wheelHalfHeight = 105;

  late final int _firstYear = widget.firstYear;
  late final int _lastYear = widget.lastYear;

  late int _year = widget.initialDate.year.clamp(_firstYear, _lastYear);
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

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  DateTime get _selectedDate => DateTime(_year, _month, _day);

  bool get _isAfterMaximum {
    final maximumDate = widget.maximumDate;
    if (maximumDate == null) return false;
    final maximum = DateTime(
      maximumDate.year,
      maximumDate.month,
      maximumDate.day,
    );
    return _selectedDate.isAfter(maximum);
  }

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
      height: PlantDatePickerSheet.sheetHeight,
      decoration: const BoxDecoration(
        color: kOrangeMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 5)],
      ),
      child: Stack(
        children: [
          // 선택 띠(4534:940)는 휠 뒤에 깔린다.
          const Positioned(
            left: 1,
            width: 399.954,
            top: PlantDatePickerSheet.highlightTop,
            height: PlantDatePickerSheet.highlightHeight,
            child: DateWheelHighlight(
              color: _highlight,
              shadow: BoxShadow(color: Color(0x2E000000), blurRadius: 4),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
          _column(
            key: const ValueKey('date_year_wheel'),
            left: 0,
            width: 146,
            controller: _yearController,
            itemCount: _lastYear - _firstYear + 1,
            label: (index) => '${_firstYear + index}년',
            alignment: Alignment.centerLeft,
            // 연도만 왼쪽 정렬이다. 고른 줄은 0.33 더 들어간다.
            padding: (selected) => EdgeInsets.only(
              left: PlantDatePickerSheet.yearLeft + (selected ? 0.33 : 0),
            ),
            onSelected: (index) => setState(() {
              _year = _firstYear + index;
              _clampDay();
            }),
          ),
          _column(
            key: const ValueKey('date_month_wheel'),
            left: PlantDatePickerSheet.monthCenter - 55.16,
            width: 110.32,
            controller: _monthController,
            itemCount: 12,
            label: (index) => '${index + 1}월',
            onSelected: (index) => setState(() {
              _month = index + 1;
              _clampDay();
            }),
          ),
          _column(
            key: const ValueKey('date_day_wheel'),
            left: PlantDatePickerSheet.dayCenter - 64.52,
            width: 129.04,
            controller: _dayController,
            itemCount: _daysInMonth,
            label: (index) => '${index + 1}일',
            onSelected: (index) => setState(() => _day = index + 1),
          ),
          // 확정 버튼(4534:945)은 흰 바탕에 오렌지 글씨로 색이 반전된다.
          Positioned(
            left: 34,
            top: PlantDatePickerSheet.buttonTop,
            right: 34,
            height: AppLayout.onboardingControlHeight,
            child: PrimaryButton(
              label: widget.buttonLabel,
              variant: PrimaryButtonVariant.enabled,
              height: AppLayout.onboardingControlHeight,
              background: kBackgroundWhite,
              textStyle: kLoginButtonStyle.copyWith(color: kOrangeMain),
              onPressed: () {
                if (_isAfterMaximum) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('오늘 이후 날짜는 선택할 수 없습니다.')),
                  );
                  return;
                }
                Navigator.of(context).pop(_selectedDate);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 휠 한 열. 휠 가운데가 고른 줄 글자 중심에 오도록 놓는다.
  Widget _column({
    required Key key,
    required double left,
    required double width,
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) label,
    required ValueChanged<int> onSelected,
    Alignment alignment = Alignment.center,
    EdgeInsets Function(bool selected)? padding,
  }) {
    return Positioned(
      left: left,
      width: width,
      top: PlantDatePickerSheet.selectedCenter - _wheelHalfHeight,
      height: _wheelHalfHeight * 2,
      child: DateWheelColumn(
        key: key,
        controller: controller,
        itemCount: itemCount,
        itemExtent: PlantDatePickerSheet.rowExtent,
        gapAbove: PlantDatePickerSheet.gapAbove,
        gapBelow: PlantDatePickerSheet.gapBelow,
        onSelectedItemChanged: onSelected,
        itemBuilder: (context, index, selected) => Padding(
          padding: padding?.call(selected) ?? EdgeInsets.zero,
          child: Align(
            alignment: alignment,
            child: Text(
              label(index),
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: selected ? 18 : 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? kBackgroundWhite
                    : kBackgroundWhite.withValues(alpha: 0.8),
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
