import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/widgets/calendar_pieces.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

/// 다이어리 화면의 종이 크기와 자리(2739:34905 외). 세 화면이 공유한다.
class DiaryLayout {
  const DiaryLayout._();

  /// 노란 책 표지(3496:11987). 왼쪽으로 넘쳐 나간다.
  static const Rect book = Rect.fromLTWH(-57, 119, 440, 620);

  /// 흰 종이(3496:11999).
  static const Rect paper = Rect.fromLTWH(30, 132.94, 334, 587.82);

  /// 종이 뒤에 겹쳐 보이는 두 장(3496:11988, 3496:11989).
  static const Rect paperBack2 = Rect.fromLTWH(32, 132.94, 342, 587.82);
  static const Rect paperBack1 = Rect.fromLTWH(24, 132.94, 345, 587.82);

  /// 종이 왼쪽에 겹쳐 보이는 책등(3496:12001).
  static const Rect spine = Rect.fromLTWH(-2, 132.94, 32, 586.75);

  /// 오른쪽 파란 책갈피(3496:11990). 시안은 180도 돌려 놓아 left가
  /// 395로 적히지만 실제로 그려지는 자리는 395 - 45 = 350이다.
  static const Rect tab = Rect.fromLTWH(350, 232, 45, 42);

  /// 이전/다음 달 버튼(3496:11992).
  static const Rect prevButton = Rect.fromLTWH(350, 493, 45, 42);
  static const Rect nextButton = Rect.fromLTWH(351, 561, 44, 42);

  /// 글쓰기 화면(2739:39308, 3496:10291)의 앞뒤 날 버튼. 3173:185 그룹
  /// 45×110이 y 493~603을 차지한다 — 위 42, 사이 26, 아래 42.
  static const Rect entryPrevButton = Rect.fromLTWH(350, 493, 45, 42);
  static const Rect entryNextButton = Rect.fromLTWH(350, 561, 45, 42);

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
    this.paperTabs = const [],
  });

  /// 종이 위에 놓일 내용. 좌표는 화면 절대값을 그대로 쓴다.
  final Widget child;

  /// Figma tabs are behind the front sheet, which hides their left 14px.
  final List<Widget> paperTabs;
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
        // 노란 표지(3496:11987). 단색 사각형이라 직접 그린다.
        // 시안 커버(3496:11987)는 안쪽 그림자 -3,-3 blur 3.712 rgba(86,0,0,.25)
        // 로 오른쪽·아래 가장자리가 살짝 어둡다. Flutter엔 inset shadow가
        // 없어 두 방향 그라디언트로 그린다(폭 ≈ 3 + 3.712/2).
        Positioned.fromRect(
          rect: DiaryLayout.book,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11.786),
            child: const ColoredBox(
              color: kDiaryCover,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0x00560000),
                          Color(0x00560000),
                          Color(0x40560000),
                        ],
                        stops: [0, 1 - 4.856 / 440, 1],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00560000),
                          Color(0x00560000),
                          Color(0x40560000),
                        ],
                        stops: [0, 1 - 4.856 / 620, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 뒤에 겹친 종이 두 장이 두께를 만든다(3496:11988, 3496:11989).
        Positioned.fromRect(
          rect: DiaryLayout.paperBack2,
          child: _PaperSheet(color: kDiaryPaperBack2, blur: 3.703),
        ),
        Positioned.fromRect(
          rect: DiaryLayout.paperBack1,
          child: _PaperSheet(color: kDiaryPaperBack1, blur: 3.675),
        ),
        ...paperTabs,
        Positioned.fromRect(
          rect: DiaryLayout.paper,
          child: _PaperSheet(
            color: kDiaryPaper,
            blur: 3.452,
            // 종이 질감(3496:12000 `image 308`): 구겨진 종이 래스터를
            // multiply 30%로 덮는다. 흰 종이 위라 Opacity로 같은 결과.
            child: ClipRect(
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  'assets/images/diary_paper_texture.png',
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        // 책등(3496:12001). 시안은 그라디언트가 아니라 래스터 이미지라
        // 그대로 깐다(2026-09-14 디자이너 지적). 그림자는 노드값 3.452.
        Positioned.fromRect(
          rect: DiaryLayout.spine,
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: [_figmaShadow(3.452)]),
            child: Image.asset(
              'assets/images/diary_spine.png',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 3496:12213 원 45 + 그림자 여백 3.917. PNG 내보내기는
                    // 흰 배경이 구워져 있어 SVG와 공용 섀도 페인터를 쓴다.
                    Positioned(
                      left: -3.917,
                      top: -3.917,
                      width: 52.833,
                      height: 52.833,
                      child: CustomPaint(
                        painter: const FabShadowPainter(),
                        child: SvgPicture.asset(
                          'assets/images/icon_diary_fab.svg',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 겹쳐 놓는 종이 한 장. 세 장이 두께를 만든다(3496:11988~11999).
/// Figma drop shadow(blur b, y b, 검정 25%)를 Flutter BoxShadow로 옮긴다.
/// Figma/CSS의 blur는 2σ, Flutter의 blurRadius는 σ = r·0.577 + 0.5라
/// 같은 값을 그대로 넣으면 시안보다 두 배 가까이 번진다.
BoxShadow _figmaShadow(double blur, {Color color = const Color(0x40000000)}) {
  final sigma = blur / 2;
  final radius = ((sigma - 0.5) / 0.57735).clamp(0.0, double.infinity);
  return BoxShadow(color: color, blurRadius: radius, offset: Offset(0, blur));
}

/// 종이 한 장. 시안(3496:11999/11988/11989)은 장마다 아래로 3.5~3.7px
/// 그림자가 있다(2026-09-13 시안 재확인).
class _PaperSheet extends StatelessWidget {
  const _PaperSheet({required this.color, required this.blur, this.child});

  final Color color;
  final double blur;
  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, boxShadow: [_figmaShadow(blur)]),
    child: child ?? const SizedBox.expand(),
  );
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
  /// 시안 3496:12137의 요일 머리글 x좌표.
  static const List<double> _weekdayCenterX = [
    64.33,
    109.58,
    153.64,
    196.06,
    239.40,
    282.72,
    327.90,
  ];
  static const List<String> _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  /// 격자 칸의 x좌표와 폭(3496:12145). 시안은 균등 분할이 아니다.
  static const List<double> _colX = [
    44,
    88.30,
    132.60,
    176.90,
    219.10,
    264.45,
    307.70,
  ];
  static const List<double> _colWidth = [
    44.30,
    44.30,
    44.30,
    42.19,
    45.36,
    43.25,
    44.30,
  ];

  /// 줄의 y좌표. 66.95와 65.90이 섞여 있다.
  static const List<double> _rowY = [292.89, 359.83, 426.78, 492.69, 559.63];
  static const List<double> _rowHeight = [66.95, 66.95, 65.90, 66.95, 65.90];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday는 월요일이 1이다. 시안은 일요일이 첫 칸이다.
    final leading = first.weekday % 7;
    // 시안 격자(3496:12145)는 다섯 줄뿐이라 여섯 주가 필요한 달은
    // 마지막 줄을 그리지 못한다.
    final weeks = ((leading + daysInMonth) / 7).ceil().clamp(1, _rowY.length);

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
              // 3496:12135 16 Medium.
              style: kSmallStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
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
        // 3496:12138~12144는 글자를 각 중심 x에 가운데 정렬한다.
        for (var i = 0; i < 7; i++)
          Positioned(
            left: _weekdayCenterX[i] - 20,
            width: 40,
            top: 262.5,
            child: Text(
              _weekdays[i],
              textAlign: TextAlign.center,
              // 3496:12137 16 SemiBold #FF8834.
              style: kItemStyle.copyWith(height: 1, color: kDiaryGridLine),
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
      left: _colX[col],
      top: _rowY[row],
      width: _colWidth[col],
      height: _rowHeight[row],
      child: DecoratedBox(
        decoration: BoxDecoration(
          // 3496:12146 border 0.769.
          border: Border.all(color: kDiaryGridLine, width: 0.769),
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
            // 3496:12147 외 전부 16 SemiBold. 고른 날만 색이 다르다.
            style: kItemStyle.copyWith(
              height: 1,
              color: isSelected ? kOrangeMain : kTextDark,
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
    // 3496:10680 / 10703 / 10704 / 10715 / 10729.
    DiaryWeather.sunny: Offset(216.09, 151.09),
    DiaryWeather.partlyCloudy: Offset(242, 152),
    DiaryWeather.cloudy: Offset(271.99, 155.9),
    DiaryWeather.rainy: Offset(302.23, 152.95),
    DiaryWeather.shower: Offset(327.03, 154.06),
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
            // 2739:39799 아이콘 y=232, 2739:39798 문구 y=317 — 칸 top 144.74 기준.
            ? Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 232 - 144.74),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/images/icon_diary_photo_add.svg',
                        width: 96,
                        height: 79,
                      ),
                      const SizedBox(height: 317 - 232 - 79),
                      Text('사진 추가하기', style: kCaptionStyle.copyWith(height: 1)),
                    ],
                  ),
                ),
              )
            // 사진은 가로선 아래(3496:10751 y=183.38~)만 채운다. 위는 날짜 줄이 쓴다.
            : Padding(
                padding: const EdgeInsets.only(top: 183.36 - 144.74),
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
