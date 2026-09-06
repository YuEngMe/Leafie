import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/calendar_pieces.dart';

/// 일정 추가 시트가 돌려주는 값.
class NewCalendarEvent {
  const NewCalendarEvent({required this.type, required this.date});

  final String type;
  final DateTime date;

  /// 시안(3429:1728)에 있는 두 종류만 쓴다.
  String get title => type == 'REPOTTING' ? '분갈이' : '비료 주기';
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
      pageBuilder: (_, _, _) =>
          CalendarNewEventSheet(initialDate: initialDate),
    ),
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
  // 3429:1618 가운데 줄 중심 y=678.91 → 카드 안 88.91. 행 간격은 위·아래 줄
  // 중심(625.26 / 729.65) 차이의 절반 = 52.2.
  static const double _rowExtent = 52.2;
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
          // 3열 휠. 년 왼쪽정렬 x=73→카드 39, 월 중심 183.34→149.34, 일 중심 245.48→211.48.
          _wheel(
            left: 34,
            width: 80,
            controller: _yearController,
            count: _lastYear - _firstYear + 1,
            label: (index) => '${_firstYear + index}년',
            onSelected: (index) => setState(() {
              _year = _firstYear + index;
              _clampDay();
            }),
          ),
          _wheel(
            left: 124,
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
    required double left,
    required double width,
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) label,
    required ValueChanged<int> onSelected,
  }) {
    return Positioned(
      left: left,
      top: 0,
      width: width,
      height: _cardHeight,
      // 휠 가운데를 시안의 강조 줄 중심(카드 안 88.91)에 맞춘다.
      child: Transform.translate(
        offset: const Offset(0, _wheelCenter - _cardHeight / 2),
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: _rowExtent,
          physics: const FixedExtentScrollPhysics(),
          diameterRatio: 100, // 시안은 원근 왜곡 없이 평평하다.
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, index) => _WheelRow(
              text: label(index),
              controller: controller,
              index: index,
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            // 3429:1707 흰 원(미선택) / 3429:1715 연노랑 원(선택).
            color: selected ? kPaleYellow : Colors.white,
            shape: BoxShape.circle,
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
        NewCalendarEvent(type: _type, date: DateTime(_year, _month, _day)),
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

/// 선택된 줄만 18 SemiBold #444, 나머지는 16 Medium #A1A1A1 (3429:1618 / 3429:1625).
class _WheelRow extends StatelessWidget {
  const _WheelRow({
    required this.text,
    required this.controller,
    required this.index,
  });

  final String text;
  final FixedExtentScrollController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected =
            (controller.hasClients ? controller.selectedItem : controller.initialItem) ==
            index;
        return Center(
          child: Text(
            text,
            style: selected
                ? kItemStyle.copyWith(fontSize: 18, height: 1)
                : kBodyStyle.copyWith(color: kTextLight, height: 1),
          ),
        );
      },
    );
  }
}

/// 3429:1596의 `inset 0 0 5px rgba(0,0,0,0.2)`. Flutter에 안쪽 그림자가 없어 직접 그린다.
class _InnerShadowPainter extends CustomPainter {
  const _InnerShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(30));
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    canvas.saveLayer(rect, Paint());
    canvas.drawRRect(rrect, Paint()..color = const Color(0x33000000));
    canvas.drawRRect(
      rrect,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..color = Colors.black
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerShadowPainter oldDelegate) => false;
}
