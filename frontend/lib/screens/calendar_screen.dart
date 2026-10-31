import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/screens/my_page_screen.dart';
import 'package:yeso_plant/services/calendar_api.dart';
import 'package:yeso_plant/services/home_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/period_swipe.dart';
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/widgets/calendar_new_event_sheet.dart';
import 'package:yeso_plant/widgets/calendar_pieces.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/leafie_toast.dart';
import 'package:yeso_plant/widgets/retry_feedback.dart';

enum CalendarViewMode { month, week }

/// Figma 월간 3341:2 / 주간 2687:15303 관리 캘린더.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.plantId,
    this.repository,
    this.loadHome,
    this.today,
    this.diaryBuilder,
    this.showBottomNav = true,
  });

  final String? plantId;
  final CalendarRepository? repository;
  final Future<HomeDashboardData> Function()? loadHome;
  final DateTime? today;
  final WidgetBuilder? diaryBuilder;
  final bool showBottomNav;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CalendarRepository _repository =
      widget.repository ?? CalendarApi();
  late final DateTime _today = _dateOnly(widget.today ?? DateTime.now());
  late DateTime _selected = _today;
  late DateTime _visibleMonth = DateTime(_today.year, _today.month);
  CalendarViewMode _mode = CalendarViewMode.month;
  String? _plantId;
  List<CalendarItemData> _items = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _completingIds = {};
  int _loadSequence = 0;

  @override
  void initState() {
    super.initState();
    _plantId = widget.plantId;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_plantId == null) {
      try {
        final home = await (widget.loadHome ?? HomeApi().fetchHome)();
        if (!mounted) return;
        _plantId = home.plant?.id;
      } on LeafieApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = error.message;
        });
        return;
      }
    }
    await _loadCalendar();
  }

  DateTimeRange get _queryRange {
    if (_mode == CalendarViewMode.week) {
      final start = _startOfWeek(_selected);
      return DateTimeRange(
        start: start,
        end: start.add(const Duration(days: 6)),
      );
    }
    return DateTimeRange(
      start: DateTime(_visibleMonth.year, _visibleMonth.month),
      end: DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0),
    );
  }

  /// [keepError]면 오류 문구와 '다시 불러오기'를 둔 채 불러온다. 진행은
  /// 그 버튼(RetryFeedback)이 보여 준다.
  Future<void> _loadCalendar({bool keepError = false}) async {
    final plantId = _plantId;
    if (plantId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '등록된 식물을 찾을 수 없어요.';
      });
      return;
    }
    final sequence = ++_loadSequence;
    if (!keepError) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final range = _queryRange;
      final items = await _repository.listCalendar(
        plantId,
        range.start,
        range.end,
      );
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } on LeafieApiException catch (error) {
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<bool> _retryCalendar() async {
    await _loadCalendar(keepError: true);
    return mounted && _error == null;
  }

  void _selectDate(DateTime date) {
    final normalized = _dateOnly(date);
    setState(() {
      _selected = normalized;
      _visibleMonth = DateTime(normalized.year, normalized.month);
    });
    if (_mode == CalendarViewMode.week) _loadCalendar();
  }

  void _changeMode(CalendarViewMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _visibleMonth = DateTime(_selected.year, _selected.month);
    });
    _loadCalendar();
  }

  void _shiftPeriod(int delta) {
    setState(() {
      if (_mode == CalendarViewMode.month) {
        _visibleMonth = DateTime(
          _visibleMonth.year,
          _visibleMonth.month + delta,
        );
        _selected = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
      } else {
        _selected = _selected.add(Duration(days: delta * 7));
        _visibleMonth = DateTime(_selected.year, _selected.month);
      }
    });
    _loadCalendar();
  }

  Future<void> _complete(CalendarItemData item) async {
    if (!item.completable || _completingIds.contains(item.id)) return;
    setState(() => _completingIds.add(item.id));
    try {
      // 지난 날짜의 일정을 뒤늦게 완료하면 그날 한 것으로 기록한다. 늘 오늘을
      // 보내면 다음 예정일이 실제보다 늦게 잡힌다. 서버는 미래 날짜를 받지
      // 않으므로 오늘을 넘지 않게 자른다.
      final future = item.date.isAfter(_today);
      final performedOn = future ? _today : item.date;
      await _repository.completeEvent(item.id, performedOn: performedOn);
      if (mounted) {
        // 체크한 일정이 목록에서 조용히 사라져 헷갈린다는 요청(디자이너 답
        // 2-A). 미래 일정은 오늘 한 일로 기록되므로 그렇게 알려 준다.
        // TODO(design): 문구는 디자이너 확정 전 임시 문구.
        unawaited(
          showLeafieToast(
            context,
            text: future ? '오늘 한 일로 기록했어요' : '일정을 완료했어요',
            top: 744,
          ),
        );
      }
      await _loadCalendar();
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _completingIds.remove(item.id));
    }
  }

  Future<void> _showCreateSheet() async {
    final plantId = _plantId;
    if (plantId == null) return;
    final result = await showCalendarNewEventSheet(
      context,
      initialDate: _selected,
    );
    if (result == null || !mounted) return;
    try {
      await _repository.createEvent(
        plantId,
        careType: result.careType,
        dueDate: result.date,
      );
      _selected = result.date;
      _visibleMonth = DateTime(result.date.year, result.date.month);
      await _loadCalendar();
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHomeGreen,
      // 좌우로 밀면 꺾쇠와 같이 이전·다음 달(주간 보기면 주)로 넘긴다.
      body: PeriodSwipe(
        onPrevious: () => _shiftPeriod(-1),
        onNext: () => _shiftPeriod(1),
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: AppLayout.referenceViewport.width,
              height: AppLayout.referenceViewport.height,
              child: Stack(
                children: [
                  // 시안(4534:4708 홈 배경_기본)은 홈 배경을 흰 바탕에 70%로
                  // 옅게 깐다. 다이어리 배경 PNG가 바로 그 합성본이라(픽셀
                  // 255−0.7×(255−홈) 일치) 같은 에셋을 쓴다.
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/diary_background.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                  _CalendarHeader(mode: _mode, onModeChanged: _changeMode),
                  if (_mode == CalendarViewMode.month)
                    _MonthCalendar(
                      month: _visibleMonth,
                      selected: _selected,
                      items: _items,
                      onSelect: _selectDate,
                      onShift: _shiftPeriod,
                    )
                  else
                    _WeekCalendar(
                      selected: _selected,
                      items: _items,
                      onSelect: _selectDate,
                      onShift: _shiftPeriod,
                    ),
                  if (_mode == CalendarViewMode.month)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      // 처음 들어왔을 때 둘째 카드(653~704)까지는 온전히 보여야
                      // 한다(2026-09-13 디자이너). 목록 바닥을 759로 두면 페이드
                      // 55px이 정확히 704부터 시작해 셋째 카드부터 사라진다.
                      // + 버튼(730~775)은 목록 위에 그려지므로 겹쳐도 된다.
                      bottom: 115,
                      child: _MonthAgenda(
                        selected: _selected,
                        today: _today,
                        items: _items
                            .where((item) => _sameDay(item.date, _selected))
                            .toList(),
                        loading: _loading,
                        error: _error,
                        completingIds: _completingIds,
                        onComplete: _complete,
                        onRetry: _retryCalendar,
                      ),
                    )
                  else
                    // 2687:17819 첫 헤딩 y=327, 카드 x=14.
                    Positioned(
                      left: 14,
                      width: 374,
                      top: 327,
                      height: 388,
                      child: _WeekAgenda(
                        weekStart: _startOfWeek(_selected),
                        items: _items,
                        loading: _loading,
                        error: _error,
                        completingIds: _completingIds,
                        onComplete: _complete,
                        onRetry: _retryCalendar,
                      ),
                    ),
                  // 3341:493 원 45x45 @ (342,730). 에셋 캔버스 52.833은 그림자
                  // 여백 3.917을 사방에 두르고 있어 그만큼 당겨 앉힌다.
                  Positioned(
                    left: 342 - 3.917,
                    top: 730 - 3.917,
                    width: 52.833,
                    height: 52.833,
                    child: GestureDetector(
                      key: const ValueKey('calendar-add'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _showCreateSheet,
                      child: CustomPaint(
                        painter: const FabShadowPainter(),
                        child: SvgPicture.asset(
                          'assets/images/calendar_fab.svg',
                        ),
                      ),
                    ),
                  ),
                  if (widget.showBottomNav)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AppBottomNav(
                        onTap: (tab) => switch (tab) {
                          FigmaNavIcon.home => Navigator.pop(context),
                          FigmaNavIcon.diary =>
                            widget.diaryBuilder == null
                                ? Navigator.pop(context)
                                : Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: widget.diaryBuilder!,
                                    ),
                                  ),
                          FigmaNavIcon.my => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyPageScreen(),
                            ),
                          ),
                          _ => null,
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// flutter_svg omits SVG filters. Reproduce only the exported circle's shadow;
/// the circle and plus glyph themselves remain the unmodified Figma asset.

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({required this.mode, required this.onModeChanged});

  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 3341:333 왼쪽 위 식물 프로필 원은 디자이너 답(1-A)으로 뺐다.
        // 3345:667 '캘린더' 43x19 x=179 y=60 → 16 Medium. 타이틀 스타일(kTitleStyle)은 너무 컸다.
        const Positioned(
          left: 0,
          right: 0,
          top: 60,
          height: 19,
          child: Center(
            child: Text('캘린더', style: kBodyStyle, textHeightBehavior: _tight),
          ),
        ),
        // 알약은 y=58이고, 위아래로 넓힌 터치 상자만큼 위로 올려 둔다.
        Positioned(
          left: 335,
          top:
              58 -
              (CalendarModeSwitch.hitHeight - CalendarModeSwitch.height) / 2,
          child: CalendarModeSwitch(
            weekSelected: mode == CalendarViewMode.week,
            onChanged: (week) => onModeChanged(
              week ? CalendarViewMode.week : CalendarViewMode.month,
            ),
          ),
        ),
      ],
    );
  }
}

const _tight = TextHeightBehavior(
  applyHeightToFirstAscent: false,
  applyHeightToLastDescent: false,
);

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.items,
    required this.onSelect,
    required this.onShift,
  });

  // 3341:498 격자: 첫 셀 (26.04, 232.571), 셀 50.132 x 56.525.
  static const double gridLeft = 26.04;
  static const double gridTop = 232.571;
  static const double cellWidth = 50.132;
  static const double cellHeight = 56.525;

  final DateTime month;
  final DateTime selected;
  final List<CalendarItemData> items;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final rows = math.max(5, ((leading + days) / 7).ceil());
    return Stack(
      children: [
        // 3341:394 종이 380x423 @ (11, 122.96).
        const Positioned(
          left: 11,
          top: 122.961,
          child: CalendarPaper(width: 380, height: 423),
        ),
        calendarPins(week: false),
        // 3341:401 라벨 중심 (201.45, 154.18) / 3341:402 꺾쇠 (143.348, 149).
        CalendarPeriodBar.placeAt(
          left: 143.348,
          top: 146,
          bar: CalendarPeriodBar(
            label: '${month.year}. ${month.month}',
            onShift: onShift,
          ),
        ),
        // 3341:408~414 요일 16 SemiBold #FF8834. 격자 셀과 어긋나게 앉는다:
        // 첫 글자 x=43.084, 간격 50.132, 폭 14.037 → 중심 50.10 / 100.23 / ...
        for (var i = 0; i < 7; i++)
          Positioned(
            left: 43.084 + i * cellWidth,
            top: 196,
            width: 14.037,
            height: 21.571,
            child: Center(
              child: Text(
                _weekdays[i],
                style: kItemStyle.copyWith(color: kBrightOrange),
                textHeightBehavior: _tight,
              ),
            ),
          ),
        for (var index = 0; index < rows * 7; index++)
          Positioned(
            left: gridLeft + (index % 7) * cellWidth,
            top: gridTop + (index ~/ 7) * cellHeight,
            width: cellWidth,
            height: cellHeight,
            child: _DayCell(
              date: index >= leading && index - leading < days
                  ? DateTime(month.year, month.month, index - leading + 1)
                  : null,
              selected: selected,
              items: items,
              onSelect: onSelect,
            ),
          ),
      ],
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({
    required this.selected,
    required this.items,
    required this.onSelect,
    required this.onShift,
  });

  final DateTime selected;
  final List<CalendarItemData> items;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final start = _startOfWeek(selected);
    return Stack(
      children: [
        // 2687:15578 종이 379x165 @ (11, 132).
        const Positioned(
          left: 11,
          top: 132,
          child: CalendarPaper(width: 379, height: 165),
        ),
        calendarPins(week: true),
        // 2687:15579 라벨 (159, 152) / 2687:15580 꺾쇠 (144, 155).
        CalendarPeriodBar.placeAt(
          left: 144,
          top: 152,
          bar: CalendarPeriodBar(
            label: '${selected.year}. ${selected.month}',
            onShift: onShift,
          ),
        ),
        // 3345:528~534 요일 (43, 186) 14x21.571, 간격 50 → 중심 50 / 100 / ...
        for (var i = 0; i < 7; i++) ...[
          Positioned(
            left: 43 + i * 50.0,
            top: 186,
            width: 14,
            height: 21.571,
            child: Center(
              child: Text(
                _weekdays[i],
                style: kItemStyle.copyWith(color: kBrightOrange),
                textHeightBehavior: _tight,
              ),
            ),
          ),
          // 3345:510 셀 (26, 222.571) 50x56.525.
          Positioned(
            left: 26 + i * 50.0,
            top: 222.571,
            width: 50,
            height: 56.525,
            child: _DayCell(
              date: start.add(Duration(days: i)),
              selected: selected,
              items: items,
              onSelect: onSelect,
            ),
          ),
        ],
      ],
    );
  }
}

/// 월간·주간이 같이 쓰는 날짜 칸. 격자선 1px, 숫자 16 SemiBold,
/// 셀 왼쪽에서 8 / 위에서 7.762 (3341:419, 3345:511).
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.items,
    required this.onSelect,
  });

  final DateTime? date;
  final DateTime selected;
  final List<CalendarItemData> items;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final value = date;
    final isSelected = value != null && _sameDay(value, selected);
    final dayItems = value == null
        ? const <CalendarItemData>[]
        : items.where((item) => _sameDay(item.date, value)).toList();
    final marks = _marksFor(dayItems);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: value == null ? null : () => onSelect(value),
      child: DecoratedBox(
        // 시안 칸(4534:5069~)은 1px 선을 칸 경계 가운데에 긋는다. 이웃 칸
        // 선이 같은 자리에 겹쳐 격자선이 1px로 보인다. 안쪽 선이면 2px가 된다.
        decoration: BoxDecoration(
          border: Border.all(
            color: kBrightOrange,
            width: 1,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
        child: value == null
            ? const SizedBox.expand()
            : Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 7.762,
                    width: 22,
                    height: 19,
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        '${value.day}',
                        style: kItemStyle.copyWith(
                          color: isSelected ? kBrightOrange : kTextDark,
                        ),
                        textHeightBehavior: _tight,
                      ),
                    ),
                  ),
                  for (final (i, mark) in marks.indexed)
                    _markAt(mark, shift: _kMarkShift * (marks.length - 1 - i)),
                ],
              ),
      ),
    );
  }
}

/// 날짜 칸 표식 종류. 그리는 순서이기도 하다(뒤가 위에 겹친다).
///
/// repotFertilize·repotWater는 분갈이와 다른 일정이 같은 날일 때 쓰는
/// 겹침 전용 아이콘이다(디자이너 10/29, 6270:1171·6270:1242). 두 장을
/// 따로 겹치면 주황끼리 한 덩어리로 보였다.
enum _DayMark { repotFertilize, repotWater, repot, fertilize, water }

/// 날짜 칸 표식(켈린더 2, 4534:4708). 칸 왼쪽 위 기준 자리와 크기.
/// 물 4534:5066, 비료 6051:4957, 분갈이 6051:4953.
/// 겹침 아이콘은 금요일 칸(4534:5090·4534:5104) 기준이고, 크기는 내보낸
/// SVG viewBox라 1배로 그린다.
const Map<_DayMark, Rect> _kMarkRects = {
  _DayMark.repotFertilize: Rect.fromLTWH(18.30, 28.09, 29, 23),
  _DayMark.repotWater: Rect.fromLTWH(18.30, 28.83, 28, 24),
  _DayMark.water: Rect.fromLTWH(29.08, 27.59, 17.04, 23.73),
  _DayMark.fertilize: Rect.fromLTWH(28.37, 30.83, 14.24, 22.93),
  _DayMark.repot: Rect.fromLTWH(27.57, 32.68, 19, 17.61),
};

/// 표식이 여럿이면 앞 표식이 이만큼씩 왼쪽으로 비킨다. 예전 시안의 10일 칸
/// (분갈이 6089:2474가 혼자일 때 27.57 → 18.30, 물이 그 위)에서 읽은 값이다.
/// 겹침 아이콘이 생긴 뒤로는 분갈이+비료+물처럼 시안에 없는 조합에만 쓴다.
const double _kMarkShift = 27.57 - 18.30;

/// 그날 일정을 표식 종류로 묶는다. 전용 그림이 없는 종류(가지치기·상태
/// 기록)는 카드처럼 화분으로 그리고, 같은 그림은 한 번만 그린다.
List<_DayMark> _marksFor(List<CalendarItemData> items) {
  final marks = {
    for (final item in items)
      switch (item.careType) {
        'WATERING' => _DayMark.water,
        'FERTILIZING' => _DayMark.fertilize,
        _ => _DayMark.repot,
      },
  };
  // 분갈이는 비료와 먼저 묶고, 비료가 없을 때만 물과 묶는다. 셋 다면
  // 분갈이+비료 위에 물방울이 남는다(시안에 없는 조합).
  if (marks.contains(_DayMark.repot)) {
    final partner = marks.contains(_DayMark.fertilize)
        ? _DayMark.fertilize
        : marks.contains(_DayMark.water)
        ? _DayMark.water
        : null;
    if (partner != null) {
      marks
        ..remove(_DayMark.repot)
        ..remove(partner)
        ..add(
          partner == _DayMark.fertilize
              ? _DayMark.repotFertilize
              : _DayMark.repotWater,
        );
    }
  }
  return marks.toList()..sort((a, b) => a.index.compareTo(b.index));
}

Widget _markAt(_DayMark mark, {required double shift}) {
  final rect = _kMarkRects[mark]!;
  return Positioned(
    key: ValueKey('calendar-cell-mark-${mark.name}'),
    left: rect.left - shift,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: switch (mark) {
      _DayMark.water => SvgPicture.asset(
        'assets/images/calendar_day_drop.svg',
        fit: BoxFit.fill,
      ),
      _DayMark.fertilize => const CalendarEventIcon(type: 'FERTILIZING'),
      _DayMark.repot => const CalendarEventIcon(type: 'REPOTTING'),
      _DayMark.repotFertilize => SvgPicture.asset(
        'assets/images/calendar_day_repot_fertilize.svg',
        fit: BoxFit.fill,
      ),
      _DayMark.repotWater => SvgPicture.asset(
        'assets/images/calendar_day_repot_water.svg',
        fit: BoxFit.fill,
      ),
    },
  );
}

/// 월간 아래 '오늘 할 일' 목록 (3341:362 + 3429:675/689).
class _MonthAgenda extends StatelessWidget {
  const _MonthAgenda({
    required this.selected,
    required this.today,
    required this.items,
    required this.loading,
    required this.error,
    required this.completingIds,
    required this.onComplete,
    required this.onRetry,
  });

  final DateTime selected;
  final DateTime today;
  final List<CalendarItemData> items;
  final bool loading;
  final String? error;
  final Set<String> completingIds;
  final ValueChanged<CalendarItemData> onComplete;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final title = _sameDay(selected, today) ? '오늘 할 일' : _dateLabel(selected);
    return Stack(
      children: [
        // 3341:362 제목 (35, 564.195) 16 SemiBold.
        Positioned(
          left: 35,
          top: 564.195,
          height: 19,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: kItemStyle, textHeightBehavior: _tight),
          ),
        ),
        // 3429:677 첫 카드 top 588.195, 카드 간격 14 (653.195 - 639.195).
        Positioned(
          left: 13,
          top: 588.195,
          width: 374,
          bottom: 0,
          child: _AgendaBody(
            items: items,
            loading: loading,
            error: error,
            completingIds: completingIds,
            onComplete: onComplete,
            onRetry: onRetry,
          ),
        ),
      ],
    );
  }
}

/// 주간 아젠다 (2687:17819 첫 헤딩 y=327, 2687:17820 첫 카드 y=351).
class _WeekAgenda extends StatelessWidget {
  const _WeekAgenda({
    required this.weekStart,
    required this.items,
    required this.loading,
    required this.error,
    required this.completingIds,
    required this.onComplete,
    required this.onRetry,
  });

  final DateTime weekStart;
  final List<CalendarItemData> items;
  final bool loading;
  final String? error;
  final Set<String> completingIds;
  final ValueChanged<CalendarItemData> onComplete;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading || error != null) {
      return _AgendaBody(
        items: const [],
        loading: loading,
        error: error,
        completingIds: completingIds,
        onComplete: onComplete,
        onRetry: onRetry,
      );
    }
    final groups = <DateTime, List<CalendarItemData>>{};
    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateItems = items
          .where((item) => _sameDay(item.date, date))
          .toList();
      if (dateItems.isNotEmpty) groups[date] = dateItems;
    }
    if (groups.isEmpty) return const _EmptyAgenda();
    return _FadeBottom(
      child: ListView.builder(
        padding: _FadeBottom.listPadding,
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final entry = groups.entries.elementAt(index);
          return Padding(
            // 앞 그룹 카드 바닥(402) → 다음 헤딩(442) = 40.
            padding: EdgeInsets.only(top: index == 0 ? 0 : 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 헤딩 19 → 카드까지 5 (327+19=346 → 351).
                SizedBox(
                  height: 19,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 21),
                      child: Text(
                        _dateLabel(entry.key),
                        style: kItemStyle,
                        textHeightBehavior: _tight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i != 0) const SizedBox(height: kCardGap),
                  _card(entry.value[i]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(CalendarItemData item) => CalendarEventCard(
    completeKey: ValueKey('calendar-complete-${item.id}'),
    type: item.careType,
    title: _eventTitle(item),
    dateLabel: _dateLabel(item.date),
    completed: item.status == 'COMPLETED',
    completing: completingIds.contains(item.id),
    completable: item.completable,
    onComplete: () => onComplete(item),
  );
}

// 3429:689 y=653.195 - 3429:677 바닥 639.195.
const double kCardGap = 14;

class _AgendaBody extends StatelessWidget {
  const _AgendaBody({
    required this.items,
    required this.loading,
    required this.error,
    required this.completingIds,
    required this.onComplete,
    required this.onRetry,
  });

  final List<CalendarItemData> items;
  final bool loading;
  final String? error;
  final Set<String> completingIds;
  final ValueChanged<CalendarItemData> onComplete;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 14),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kOrangeMain,
            ),
          ),
        ),
      );
    }
    if (error != null) {
      return Align(
        alignment: Alignment.topCenter,
        child: RetryFeedback(
          onRetry: onRetry,
          builder: (context, phase, retry) => TextButton(
            onPressed: retry,
            child: Text(switch (phase) {
              RetryPhase.idle => '$error\n다시 불러오기',
              RetryPhase.busy => '$error\n$kRetryBusyLabel',
              RetryPhase.failed => '$kRetryFailedMessage\n다시 불러오기',
            }, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (items.isEmpty) return const _EmptyAgenda();
    return _FadeBottom(
      child: ListView.separated(
        padding: _FadeBottom.listPadding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: kCardGap),
        itemBuilder: (context, index) {
          final item = items[index];
          return CalendarEventCard(
            completeKey: ValueKey('calendar-complete-${item.id}'),
            type: item.careType,
            title: _eventTitle(item),
            dateLabel: _dateLabel(item.date),
            completed: item.status == 'COMPLETED',
            completing: completingIds.contains(item.id),
            completable: item.completable,
            onComplete: () => onComplete(item),
          );
        },
      ),
    );
  }
}

/// 목록 바닥 [height]px 구간을 불투명→투명으로 깎는다. 카드가 아래로
/// 내려가며 + 버튼 앞에서 뿌옇게 사라진다(2026-09-12 디자이너 요청).
/// 목록에 같은 만큼 bottom padding을 줘서 마지막 카드도 끝까지 올라온다.
class _FadeBottom extends StatelessWidget {
  const _FadeBottom({required this.child});

  static const double height = 55;

  /// 목록과 마스크는 자기 경계에서 자른다. 카드가 목록 폭(374)에 꽉 차
  /// 카드 그림자(흐림 4)가 좌우·위에서 잘리므로 그만큼 바깥으로 넓히고
  /// 같은 만큼 안쪽 여백을 줘 카드 자리는 그대로 둔다.
  static const double shadowRoom = 6;

  static const listPadding = EdgeInsets.fromLTRB(
    shadowRoom,
    shadowRoom,
    shadowRoom,
    height,
  );

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: -shadowRoom,
        right: -shadowRoom,
        top: -shadowRoom,
        bottom: 0,
        child: ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Colors.white, Colors.white, Colors.transparent],
            stops: [0, 1 - height / rect.height, 1],
          ).createShader(Rect.fromLTWH(0, 0, rect.width, rect.height)),
          blendMode: BlendMode.dstIn,
          child: child,
        ),
      ),
    ],
  );
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        '등록된 일정이 없어요.',
        style: kCaptionStyle.copyWith(color: kTextDark),
      ),
    ),
  );
}

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _startOfWeek(DateTime value) =>
    _dateOnly(value).subtract(Duration(days: value.weekday % 7));

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateLabel(DateTime date) =>
    '${date.year}. ${date.month}.${date.day} ${_weekdays[date.weekday % 7]}';

String _eventTitle(CalendarItemData item) {
  return switch (item.careType) {
    'WATERING' => '물 주기',
    'REPOTTING' => '분갈이',
    'FERTILIZING' => '비료 주기',
    _ => '식물 관리',
  };
}
