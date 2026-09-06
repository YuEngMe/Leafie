import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

/// 다이어리 화면의 종이 크기와 자리(2739:34905 외). 세 화면이 공유한다.
class DiaryLayout {
  const DiaryLayout._();

  /// 노란 책 표지(2739:38324). 왼쪽으로 넘쳐 나간다.
  static const Rect book = Rect.fromLTWH(-38, 119, 440, 578);

  /// 흰 종이(2739:34974).
  static const Rect paper = Rect.fromLTWH(34, 132, 334, 548);

  /// 종이 왼쪽에 겹쳐 보이는 책등(2739:35054).
  static const Rect spine = Rect.fromLTWH(-2, 132, 32, 547);

  /// 오른쪽 파란 책갈피(2766:203).
  static const Rect tab = Rect.fromLTWH(350, 232, 45, 42);

  /// 이전/다음 달 버튼(3496:11993, 3496:11996).
  static const Rect prevButton = Rect.fromLTWH(350, 493, 45, 42);
  static const Rect nextButton = Rect.fromLTWH(351, 561, 44, 42);

  /// 글쓰기로 가는 연필 버튼(3496:12213).
  static const Rect fab = Rect.fromLTWH(302, 661, 45, 45);

  /// 앱바 오른쪽 편집 아이콘(2739:34955).
  static const Size editIcon = Size(28.656, 29);
}

/// 배경 일러스트와 책·종이를 깔아 주는 뼈대.
///
/// 시안은 언덕과 구름을 벡터 90여 개로 그렸지만 그대로 옮길 것이 아니라
/// 통째로 내보낸 PNG를 쓴다(2739:34593).
class DiaryScaffoldBody extends StatelessWidget {
  const DiaryScaffoldBody({
    super.key,
    required this.child,
    this.onFabPressed,
    this.onNavTap,
  });

  /// 종이 위에 놓일 내용. 좌표는 화면 절대값을 그대로 쓴다.
  final Widget child;
  final VoidCallback? onFabPressed;

  /// 하단 네비를 띄울지. null이면 그리지 않는다(글쓰기 화면).
  final ValueChanged<FigmaNavIcon>? onNavTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/diary_background.png',
            fit: BoxFit.cover,
          ),
        ),
        // 노란 표지. 종이보다 조금 크고 왼쪽으로 빠져나간다.
        Positioned.fromRect(
          rect: DiaryLayout.book,
          child: Image.asset('assets/images/diary_book.png', fit: BoxFit.fill),
        ),
        Positioned.fromRect(
          rect: DiaryLayout.paper,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: kDiaryPaper,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 3.452,
                  offset: Offset(0, 3.452),
                ),
              ],
            ),
            // 종이 질감(2739:34975). 내보낸 PNG가 순백이라 쓸 수 없어
            // 시안에서 잰 노이즈(밝기 243~253)를 직접 뿌린다.
            child: const CustomPaint(painter: _PaperGrainPainter()),
          ),
        ),
        child,
        // 시안(2739:34928)은 다이어리에도 하단 네비를 둔다.
        if (onNavTap case final onTap?)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(onTap: onTap),
          ),
        if (onFabPressed != null)
          Positioned.fromRect(
            rect: DiaryLayout.fab,
            child: GestureDetector(
              onTap: onFabPressed,
              child: Semantics(
                label: '다이어리 쓰기',
                button: true,
                child: SvgPicture.asset('assets/images/icon_diary_fab.svg'),
              ),
            ),
          ),
      ],
    );
  }
}

/// 종이의 오돌토돌한 결. 시안은 밝기 243~253 사이의 잔 알갱이다.
class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 매 프레임 달라지면 지저분하니 자리를 고정한다.
    final random = Random(7);
    final paint = Paint();
    final count = (size.width * size.height / 26).round();
    for (var i = 0; i < count; i++) {
      final shade = 243 + random.nextInt(11);
      paint.color = Color.fromARGB(255, shade, shade, shade);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        random.nextDouble() * 1.1 + 0.4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PaperGrainPainter oldDelegate) => false;
}

/// 종이 오른쪽에 붙은 파란 책갈피(2766:203). 단색 사각형이라 직접 그린다.
class DiaryTab extends StatelessWidget {
  const DiaryTab({super.key, this.onTap, this.color = kDiaryTabBlue});

  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 달력 한 장(2739:34974). 연·월과 요일 머리글, 6주 격자.
class DiaryCalendar extends StatelessWidget {
  const DiaryCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.onSelect,
    this.markedDays = const {},
  });

  /// 보여 줄 달. 일(day)은 무시한다.
  final DateTime month;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  /// 글이 있는 날. 시안에 표시가 없어 지금은 쓰지 않지만 넘겨는 둔다.
  final Set<int> markedDays;

  /// 시안 2739:34979의 요일 머리글 x좌표.
  static const List<double> _weekdayX = [
    62,
    107.3,
    151.3,
    193.7,
    237.1,
    275.8,
    321,
  ];
  static const List<String> _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  /// 격자 첫 칸(2739:35026)과 칸 크기.
  static const double _gridLeft = 45;
  static const double _gridTop = 292.9;
  static const double _cellWidth = 44;

  /// 시안 격자는 332.65 높이에 다섯 줄이다(2739:34987).
  static const double _cellHeight = 332.65 / 5;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday는 월요일이 1이다. 시안은 일요일이 첫 칸이다.
    final leading = first.weekday % 7;
    final weeks = ((leading + daysInMonth) / 7).ceil();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 2739:34977 연도, 2739:34978 월.
        Positioned(
          left: 0,
          right: 0,
          top: 162.7,
          child: Center(
            child: Text(
              '${month.year}',
              style: kSmallStyle.copyWith(
                fontSize: 16,
                height: 1,
                color: kTextDark,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 179.3,
          child: Center(
            child: Text(
              '${month.month}',
              style: const TextStyle(
                fontFamily: kFontFamily,
                fontSize: 55,
                fontWeight: FontWeight.w600,
                height: 65 / 55,
                color: kTextDark,
              ),
            ),
          ),
        ),
        for (var i = 0; i < 7; i++)
          Positioned(
            left: _weekdayX[i],
            top: 262.5,
            child: Text(
              _weekdays[i],
              style: kSmallStyle.copyWith(
                height: 1,
                color: kOrangeMain,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        // 시안(2739:34987)은 6주 42칸을 모두 그린다. 날짜가 없는 칸도
        // 테두리는 있다.
        for (var i = 0; i < weeks * 7; i++)
          _cell(
            i,
            i >= leading && i - leading < daysInMonth ? i - leading + 1 : null,
          ),
      ],
    );
  }

  Widget _cell(int index, int? day) {
    final row = index ~/ 7;
    final col = index % 7;
    final cell = Positioned(
      left: _gridLeft + col * _cellWidth,
      top: _gridTop + row * _cellHeight,
      width: _cellWidth,
      height: _cellHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: kDiaryGridLine, width: 0.5),
        ),
        child: day == null
            ? const SizedBox.expand()
            : _dayLabel(DateTime(month.year, month.month, day), day),
      ),
    );
    return cell;
  }

  Widget _dayLabel(DateTime date, int day) {
    final isSelected = DiaryEntry.sameDay(date, selected);
    return GestureDetector(
      onTap: () => onSelect(date),
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$day',
            style: kSmallStyle.copyWith(
              height: 1,
              fontSize: 15,
              color: isSelected ? kOrangeMain : kTextDark,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// 날짜 줄 오른쪽의 날씨 여섯 칸(2739:39806 외).
class DiaryWeatherPicker extends StatelessWidget {
  const DiaryWeatherPicker({super.key, required this.selected, this.onSelect});

  final DiaryWeather? selected;
  final ValueChanged<DiaryWeather>? onSelect;

  /// 시안이 잡아 둔 아이콘별 좌표. 크기가 제각각이라 표로 둔다.
  static const Map<DiaryWeather, Offset> _positions = {
    DiaryWeather.sunny: Offset(217, 152),
    DiaryWeather.partlyCloudy: Offset(243.09, 152.95),
    DiaryWeather.cloudy: Offset(271.99, 155.9),
    DiaryWeather.rainy: Offset(302.23, 152.95),
    DiaryWeather.shower: Offset(326.81, 152),
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final entry in _positions.entries)
          Positioned(
            left: entry.value.dx,
            top: entry.value.dy,
            child: GestureDetector(
              onTap: onSelect == null ? null : () => onSelect!(entry.key),
              child: Opacity(
                // 고른 날씨만 진하게 둔다. 시안에는 선택 상태가 없다.
                opacity: selected == null || selected == entry.key ? 1 : 0.35,
                child: Semantics(
                  label: entry.key.label,
                  button: onSelect != null,
                  child: SvgPicture.asset(
                    entry.key.asset,
                    width: entry.key.width,
                    height: entry.key.height,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 사진칸(2739:39790). 비어 있으면 '사진 추가하기'를 띄운다.
class DiaryPhotoBox extends StatelessWidget {
  const DiaryPhotoBox({
    super.key,
    required this.photoPath,
    this.photoUrl,
    this.onTap,
  });

  final String? photoPath;
  final String? photoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final url = photoUrl;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: kOrangeMain)),
        child: path == null && url == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/images/icon_diary_photo_add.svg',
                      width: 96,
                      height: 79,
                    ),
                    const SizedBox(height: 13),
                    Text('사진 추가하기', style: kCaptionStyle.copyWith(height: 1)),
                  ],
                ),
              )
            // 사진은 칸 아래쪽(y=176~)만 채운다. 위는 날짜 줄이 쓴다.
            : Padding(
                padding: const EdgeInsets.only(top: 36),
                child: path != null
                    ? Image.file(File(path), fit: BoxFit.cover)
                    : Image.network(
                        url!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: kDiaryPaper,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
              ),
      ),
    );
  }
}
