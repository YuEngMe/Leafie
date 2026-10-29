import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_motion.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/calendar_pieces.dart';
import 'package:yeso_plant/widgets/date_wheel_column.dart';

/// 일정 추가 시트가 돌려주는 값. 시안(3429:1728)에 있는 REPOTTING/FERTILIZING 두 종류만 쓴다.
class NewCalendarEvent {
  const NewCalendarEvent({required this.careType, required this.date});

  final String careType;
  final DateTime date;
}

/// 일정 추가(3429:1163). 딤 위에 떠 있는 334x180 카드 + 아래 `확인` 버튼.
/// 화면 바닥에 붙는 바텀시트가 아니라서 `showDialog`로 띄운다.
Future<NewCalendarEvent?> showCalendarNewEventSheet(
  BuildContext context, {
  required DateTime initialDate,
}) {
  // showDialog는 안전영역만큼 자식을 밀어넣어 시안 절대 좌표가 어긋난다.
  // 딤과 화면 전체를 직접 쓰는 투명 라우트로 띄운다.
  return Navigator.of(context).push<NewCalendarEvent>(
    PageRouteBuilder<NewCalendarEvent>(
      opaque: false,
      barrierColor: kModalBarrier,
      barrierDismissible: true,
      barrierLabel: '일정 추가 닫기',
      transitionDuration: AppMotion.overlayEnter,
      reverseTransitionDuration: AppMotion.overlayExit,
      pageBuilder: (_, _, _) =>
          CalendarNewEventSheet(initialDate: initialDate),
      transitionsBuilder: _sheetTransition,
    ),
  );
}

/// M3 enter and exit(화면 안, iOS): 들어올 때는 살짝 작은 크기에서 커지며
/// 나타나고, 나갈 때는 크기 그대로 흐려지기만 한다.
Widget _sheetTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> _,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return DualTransitionBuilder(
    animation: animation,
    forwardBuilder: (_, enter, child) {
      final curved = enter.drive(CurveTween(curve: AppMotion.pageFadeCurve));
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: curved.drive(
            Tween(begin: AppMotion.overlayEnterScale, end: 1.0),
          ),
          alignment: _CalendarNewEventSheetState._scaleOrigin,
          child: child,
        ),
      );
    },
    reverseBuilder: (_, exit, child) => FadeTransition(
      opacity: exit
          .drive(CurveTween(curve: AppMotion.overlayExitCurve))
          .drive(Tween(begin: 1.0, end: 0.0)),
      child: child,
    ),
    child: child,
  );
}

class CalendarNewEventSheet extends StatefulWidget {
  const CalendarNewEventSheet({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<CalendarNewEventSheet> createState() => _CalendarNewEventSheetState();
}

class _CalendarNewEventSheetState extends State<CalendarNewEventSheet> {
  // 3429:1596 카드, 3429:1594 버튼 — 전부 402x874 시안 절대 좌표.
  static const double _cardLeft = 34;
  static const double _cardTop = 590;
  static const double _cardWidth = 334;
  static const double _cardHeight = 180;
  static const double _confirmTop = 790;
  static const double _confirmHeight = 51;

  /// 카드와 확인 버튼 묶음의 가운데. 나타날 때 이 점을 기준으로 키운다.
  /// 묶음이 가로 가운데라 x는 0이다.
  static final Alignment _scaleOrigin = Alignment(
    0,
    (_cardTop + _confirmTop + _confirmHeight) /
            AppLayout.referenceViewport.height -
        1,
  );
  // 4534:6100 가운데 줄 중심 y=678.91 → 카드 안 88.91. 위·아래 줄 중심은
  // 625.26 / 729.65라 위 간격 53.65, 아래 간격 50.74로 다르다. 기본 간격을
  // 둘의 평균 52.2로 두고 위는 1.45 더 벌리고 아래는 1.46 좁힌다.
  static const double _rowExtent = 52.2;
  static const double _gapAbove = 53.65 - _rowExtent;
  static const double _gapBelow = 50.74 - _rowExtent;
  static const double _wheelCenter = 88.91;

  static const int _firstYear = 2020;
  static const int _lastYear = 2100;

  late int _year = widget.initialDate.year;
  late int _month = widget.initialDate.month;
  late int _day = widget.initialDate.day;
  String _type = 'REPOTTING';

  late final FixedExtentScrollController _yearController =
      FixedExtentScrollController(initialItem: _year - _firstYear);
  late final FixedExtentScrollController _monthController =
      FixedExtentScrollController(initialItem: _month - 1);
  late final FixedExtentScrollController _dayController =
      FixedExtentScrollController(initialItem: _day - 1);

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  void _clampDay() {
    final maxDay = _daysInMonth;
    if (_day <= maxDay) return;
    _day = maxDay;
    _dayController.jumpToItem(maxDay - 1);
  }

  @override
  Widget build(BuildContext context) {
    // 시안 전체 좌표를 그대로 쓰려고 화면을 402x874로 두고 배율만 맞춘다.
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: AppLayout.referenceViewport.width,
            height: AppLayout.referenceViewport.height,
            child: Stack(
              children: [
                Positioned(
                  left: _cardLeft,
                  top: _cardTop,
                  width: _cardWidth,
                  height: _cardHeight,
                  child: _card(),
                ),
                Positioned(
                  left: _cardLeft,
                  top: _confirmTop,
                  width: _cardWidth,
                  height: _confirmHeight,
                  child: _confirmButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: const _InnerShadowPainter()),
          ),
          // 강조 알약 3429:1617: 230x40 @ (53,660) → 카드 기준 (19,70), radius 20.
          Positioned(
            left: 19,
            top: 70,
            width: 230,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kCalendarWheelHighlight,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x2E000000), blurRadius: 4),
                ],
              ),
            ),
          ),
          // 3열 휠(4534:6088~6101). 년은 왼쪽 정렬로 고른 줄 x=68.33, 나머지
          // x=73 → 카드 34.33 / 39. 월 중심 183.34→149.34, 일 중심 245.48→211.48.
          _wheel(
            key: const ValueKey('calendar-year-wheel'),
            left: 34,
            width: 80,
            alignment: Alignment.centerLeft,
            padding: (selected) => EdgeInsets.only(left: selected ? 0.33 : 5),
            controller: _yearController,
            count: _lastYear - _firstYear + 1,
            label: (index) => '${_firstYear + index}년',
            onSelected: (index) => setState(() {
              _year = _firstYear + index;
              _clampDay();
            }),
          ),
          _wheel(
            key: const ValueKey('calendar-month-wheel'),
            left: 123.84,
            width: 51,
            controller: _monthController,
            count: 12,
            label: (index) => '${index + 1}월',
            onSelected: (index) => setState(() {
              _month = index + 1;
              _clampDay();
            }),
          ),
          _wheel(
            key: const ValueKey('calendar-day-wheel'),
            left: 190,
            width: 43,
            controller: _dayController,
            count: _daysInMonth,
            label: (index) => '${index + 1}일',
            onSelected: (index) => setState(() => _day = index + 1),
          ),
          // 일정 종류 아이콘 2개 (3429:1707 분갈이 / 3429:1715 비료), 49x49 @ x=301.
          _typeButton(
            top: 29,
            value: 'REPOTTING',
            asset: 'assets/images/calendar_event_repot.svg',
            iconWidth: 29.628,
            iconHeight: 27.464,
          ),
          _typeButton(
            top: 95.09,
            value: 'FERTILIZING',
            asset: 'assets/images/calendar_event_fertilize.svg',
            iconWidth: 21.651,
            iconHeight: 34.862,
          ),
        ],
      ),
    );
  }

  Widget _wheel({
    required Key key,
    required double left,
    required double width,
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) label,
    required ValueChanged<int> onSelected,
    Alignment alignment = Alignment.center,
    EdgeInsets Function(bool selected)? padding,
  }) {
    return Positioned(
      left: left,
      top: 0,
      width: width,
      height: _cardHeight,
      // 휠 가운데를 시안의 강조 줄 중심(카드 안 88.91)에 맞춘다.
      child: Transform.translate(
        offset: const Offset(0, _wheelCenter - _cardHeight / 2),
        child: DateWheelColumn(
          key: key,
          controller: controller,
          itemCount: count,
          itemExtent: _rowExtent,
          gapAbove: _gapAbove,
          gapBelow: _gapBelow,
          onSelectedItemChanged: onSelected,
          // 선택된 줄만 18 SemiBold #444, 나머지는 16 Medium #A1A1A1
          // (4534:6099 / 4534:6090).
          itemBuilder: (context, index, selected) => Padding(
            padding: padding?.call(selected) ?? EdgeInsets.zero,
            child: Align(
              alignment: alignment,
              child: Text(
                label(index),
                style: selected
                    ? kItemStyle.copyWith(fontSize: 18, height: 1)
                    : kBodyStyle.copyWith(color: kTextLight, height: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeButton({
    required double top,
    required String value,
    required String asset,
    required double iconWidth,
    required double iconHeight,
  }) {
    final selected = _type == value;
    return Positioned(
      left: 267,
      top: top,
      width: 49,
      height: 49,
      child: GestureDetector(
        key: ValueKey('calendar-type-$value'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _type = value),
        // 4534:6068 흰 원(미선택) / 4534:6076 연노랑 원(선택). 시안 렌더는 두
        // 원 모두 가장자리 안쪽이 옅게 어둡다(바깥 1px 239·다음 1px 250).
        // 내보낸 SVG엔 그 효과가 빠져 있어, 렌더 픽셀에 맞춘 안쪽 그림자
        // (흐림 σ 1.25, 검정 20%)로 그린다. 흰 카드 위에서 원 경계가 보인다.
        child: CustomPaint(
          painter: _InnerShadowPainter(
            radius: 24.5,
            sigma: 1.25,
            fill: selected ? kPaleYellow : Colors.white,
          ),
          child: Center(
            child: SizedBox(
              width: iconWidth,
              height: iconHeight,
              child: SvgPicture.asset(asset, fit: BoxFit.fill),
            ),
          ),
        ),
      ),
    );
  }

  Widget _confirmButton() {
    return GestureDetector(
      key: const ValueKey('calendar-new-event-confirm'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(
        context,
        NewCalendarEvent(careType: _type, date: DateTime(_year, _month, _day)),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kOrangeMain,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [
            BoxShadow(color: Color(0x2E000000), blurRadius: 2),
          ],
        ),
        // 3429:1595 `확인` 16 Medium #444.
        child: const Center(child: Text('확인', style: kBodyStyle)),
      ),
    );
  }
}

/// `inset 0 0 <2σ>px rgba(0,0,0,0.2)`. Flutter에 안쪽 그림자가 없어 직접 그린다.
/// 기본값은 카드 3429:1596(`inset 0 0 5px`), 종류 원도 같은 방식으로 쓴다.
class _InnerShadowPainter extends CustomPainter {
  const _InnerShadowPainter({
    this.radius = 30,
    this.sigma = 2.5,
    this.fill = Colors.white,
  });

  final double radius;
  final double sigma;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.saveLayer(rect, Paint());
    canvas.drawRRect(rrect, Paint()..color = const Color(0x33000000));
    canvas.drawRRect(
      rrect,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..color = Colors.black
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerShadowPainter oldDelegate) =>
      radius != oldDelegate.radius ||
      sigma != oldDelegate.sigma ||
      fill != oldDelegate.fill;
}
