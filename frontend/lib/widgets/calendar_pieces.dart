import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

/// 캘린더 월간(3341:2)·주간(2687:15303)·일정 추가(3429:1163)가 함께 쓰는 조각들.
/// 화면 파일이 커져서 골격만 남기려고 뽑아냈다. 좌표는 전부 402x874 시안 기준.

// 카드 제목(3429:678). 팔레트 토큰이 아니라 노드에 직접 박힌 값이다.
const Color kCalendarCardTitle = Color(0xFF1F2E21);
// 휠 강조 알약(3429:1617). kPaleYellow(#FFECA6)보다 옅다.
const Color kCalendarWheelHighlight = Color(0xFFFFF3CA);

/// 일정 카드(3429:677 / 2687:15626). 374x51, radius 50.
/// 안쪽 좌표는 전부 카드 왼쪽 기준 offset이라 월간(left 13)·주간(left 14)이 같다.
class CalendarEventCard extends StatelessWidget {
  const CalendarEventCard({
    super.key,
    required this.type,
    required this.title,
    required this.dateLabel,
    required this.completed,
    required this.completing,
    required this.completable,
    required this.onComplete,
    this.completeKey,
  });

  static const double height = 51;

  final String type;
  final String title;
  final String dateLabel;
  final bool completed;
  final bool completing;
  final bool completable;
  final VoidCallback onComplete;
  final Key? completeKey;

  @override
  Widget build(BuildContext context) {
    // 아이콘 x는 종류마다 다르다: 분갈이 33-13=20, 비료 37-13=24 (3429:680 / 3429:695).
    final repot = type == 'REPOTTING';
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                boxShadow: const [
                  BoxShadow(color: Color(0x2E000000), blurRadius: 4),
                ],
              ),
            ),
          ),
          // 분갈이 26x24.10 top 14 / 비료 19x30.59 top 11 / 나머지는 분갈이 자리.
          Positioned(
            left: repot ? 20 : 24,
            top: repot ? 14 : 11,
            width: repot ? 26 : 19,
            height: repot ? 24.101 : 30.593,
            child: CalendarEventIcon(type: type),
          ),
          Positioned(
            left: 95.29,
            top: 0,
            width: 108.61,
            height: height,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kBodyStyle.copyWith(color: kCalendarCardTitle),
              ),
            ),
          ),
          // 시안 노드는 78 폭이지만 `whitespace-nowrap`이라 글자가 넘쳐 흐른다.
          // Flutter는 78에서 요일을 잘라먹으므로 완료 원 앞까지 자리를 준다.
          Positioned(
            left: 214.15,
            top: 0,
            width: 108,
            height: height,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                dateLabel,
                maxLines: 1,
                style: kCaptionStyle.copyWith(color: kTextLight),
              ),
            ),
          ),
          // 완료 원 26x26, 카드 왼쪽에서 336 (3429:713 349-13 / 3429:639 350-14).
          Positioned(
            left: 323,
            top: 0,
            width: 52,
            height: height,
            child: GestureDetector(
              key: completeKey,
              behavior: HitTestBehavior.opaque,
              onTap: completable && !completing ? onComplete : null,
              child: Center(
                child: completing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kOrangeMain,
                        ),
                      )
                    : CalendarCompleteMark(completed: completed),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 완료 표식(3429:1450 미완료 / 3429:1463+3429:1465 완료).
/// 완료는 오렌지 원 + 흰 꺾쇠(V), 체크(✓)가 아니다.
class CalendarCompleteMark extends StatelessWidget {
  const CalendarCompleteMark({super.key, required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: completed ? kOrangeMain : Colors.white,
          shape: BoxShape.circle,
          // 시안(3429:715)의 미완료 원은 테두리 없는 순백이라 흰 카드 위에서
          // 사라진다. 시안 자체도 종이색 배경 위에서만 보이는 것이라
          // 카드 위에서 구분되도록 옅은 테두리를 준다.
          border: completed
              ? null
              : Border.all(color: kGaugeTrack, width: 1),
        ),
        child: completed
            ? const Center(
                child: SizedBox(
                  width: 12,
                  height: 8,
                  child: CustomPaint(painter: _DownChevronPainter()),
                ),
              )
            : null,
      ),
    );
  }
}

// 3429:1487 Vector 1215: stroke 2 흰 선, round cap, 12x8 안의 V.
class _DownChevronPainter extends CustomPainter {
  const _DownChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(1, 1)
      ..lineTo(size.width / 2, size.height - 1)
      ..lineTo(size.width - 1, 1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DownChevronPainter oldDelegate) => false;
}

/// 일정 종류 아이콘. 시안 노드 크기를 그대로 채우도록 늘린다.
class CalendarEventIcon extends StatelessWidget {
  const CalendarEventIcon({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final asset = switch (type) {
      'WATERING' => 'assets/images/calendar_event_water.svg',
      'FERTILIZING' => 'assets/images/calendar_event_fertilize.svg',
      // 시안에 그림이 없는 종류(가지치기·상태기록)는 분갈이 화분을 쓴다.
      _ => 'assets/images/calendar_event_repot.svg',
    };
    return SvgPicture.asset(asset, fit: BoxFit.fill);
  }
}

/// 월/주 토글(3341:483). 48x24.923 오렌지 알약 + 지름 21.23 흰 알약 손잡이.
class CalendarModeSwitch extends StatelessWidget {
  const CalendarModeSwitch({
    super.key,
    required this.weekSelected,
    required this.onChanged,
  });

  static const double width = 48;
  static const double height = 24.923;
  // 3341:484의 흰 원 r=10.615, 중심 x는 알약 왼쪽에서 12.615.
  static const double _knobDiameter = 21.231;
  static const double _knobInset = 2;

  final bool weekSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kOrangeMain,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
          Positioned(
            left: weekSelected ? width - _knobInset - _knobDiameter : _knobInset,
            top: (height - _knobDiameter) / 2,
            width: _knobDiameter,
            height: _knobDiameter,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x33000000), blurRadius: 5),
                ],
              ),
            ),
          ),
          // 글자 '월' x=342 y=63 11x14, '주' x=365 — 알약(x=335) 기준 7 / 30.
          for (final (label, left, week) in const [
            ('월', 7.0, false),
            ('주', 30.0, true),
          ])
            Positioned(
              key: ValueKey('calendar-mode-${week ? 'week' : 'month'}'),
              left: left,
              top: 5,
              width: 11,
              height: 14,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(week),
                child: Center(
                  child: Text(
                    label,
                    style: kCaptionStyle.copyWith(
                      color: weekSelected == week
                          ? kTextDark
                          : kBackgroundWhite,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 기간 라벨(3341:401)과 좌우 꺾쇠(3341:402).
/// 라벨은 16 SemiBold, 꺾쇠는 SVG 그룹 114.33x10.01.
class CalendarPeriodBar extends StatelessWidget {
  const CalendarPeriodBar({
    super.key,
    required this.label,
    required this.onShift,
  });

  static const double chevronsWidth = 114.333;
  static const double chevronsHeight = 10.01;

  final String label;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 꺾쇠는 라벨 줄(y=146, h=16.366) 안에서 3px 아래(y=149)에 앉는다.
        Positioned(
          left: 0,
          top: 3,
          width: chevronsWidth,
          height: chevronsHeight,
          child: SvgPicture.asset(
            'assets/images/calendar_period_chevrons.svg',
            fit: BoxFit.fill,
          ),
        ),
        // 3341:401 `2026. 7` 16 SemiBold #444, 꺾쇠 그룹 안 가운데.
        Positioned.fill(
          child: Center(
            child: Text(
              label,
              style: kItemStyle,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          ),
        ),
        // 터치 영역만 넓힌다. 그림은 위 SVG가 그린다.
        for (final (key, delta, left) in const [
          ('calendar-period-prev', -1, -8.0),
          ('calendar-period-next', 1, chevronsWidth - 24),
        ])
          Positioned(
            key: ValueKey(key),
            left: left,
            top: -12,
            width: 32,
            height: 34,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onShift(delta),
            ),
          ),
      ],
    );
  }
}

/// 종이 패널(3341:394 / 2687:15578)과 압정(3341:395 / 2687:17780).
class CalendarPaper extends StatelessWidget {
  const CalendarPaper({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFFDFDFD),
          boxShadow: [
            BoxShadow(
              color: Color(0x4D444444),
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        // 3345:633 Mask group: `image 309` 구겨진 종이를 90도 돌려
        // mix-blend-multiply 20%로 덮는다.
        child: ClipRect(
          child: Opacity(
            opacity: 0.2,
            child: RotatedBox(
              quarterTurns: 1,
              child: Image.asset(
                'assets/images/calendar_paper_texture.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 압정 두 개. 월간은 332.876x52@(35.06,110), 주간은 342x39@(30,120)로 크기가 다르다.
/// `Stack` 안에 그대로 넣으면 되도록 Positioned를 스스로 만든다.
Widget calendarPins({required bool week}) => Positioned(
  left: week ? 30 : 35.063,
  top: week ? 120 : 110,
  width: week ? 342 : 332.876,
  height: week ? 39 : 52,
  child: SvgPicture.asset(
    week
        ? 'assets/images/calendar_paper_pins_week.svg'
        : 'assets/images/calendar_paper_pins.svg',
    fit: BoxFit.fill,
  ),
);
