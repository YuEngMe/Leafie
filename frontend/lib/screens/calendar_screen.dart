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
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

enum CalendarViewMode { month, week }

/// Figma 월간 3341:2 / 주간 2687:15303 관리 캘린더.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.plantId,
    this.plantName,
    this.plantPhotoUrl,
    this.repository,
    this.loadHome,
    this.today,
    this.diaryBuilder,
  });

  final String? plantId;
  final String? plantName;
  final String? plantPhotoUrl;
  final CalendarRepository? repository;
  final Future<HomeDashboardData> Function()? loadHome;
  final DateTime? today;
  final WidgetBuilder? diaryBuilder;

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
  String? _plantName;
  String? _plantPhotoUrl;
  List<CalendarItemData> _items = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _completingIds = {};
  int _loadSequence = 0;

  @override
  void initState() {
    super.initState();
    _plantId = widget.plantId;
    _plantName = widget.plantName;
    _plantPhotoUrl = widget.plantPhotoUrl;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_plantId == null) {
      try {
        final home = await (widget.loadHome ?? HomeApi().fetchHome)();
        if (!mounted) return;
        _plantId = home.plant?.id;
        _plantName = home.plant?.nickname;
        _plantPhotoUrl = home.plant?.primaryPhotoUrl;
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

  Future<void> _loadCalendar() async {
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
    setState(() {
      _loading = true;
      _error = null;
    });
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
      });
    } on LeafieApiException catch (error) {
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
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
      await _repository.completeEvent(item.id, performedOn: _today);
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
    final result = await showModalBottomSheet<_NewCalendarEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewEventSheet(initialDate: _selected),
    );
    if (result == null || !mounted) return;
    try {
      await _repository.createEvent(
        plantId,
        type: result.type,
        title: result.title,
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
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: AppLayout.referenceViewport.width,
            height: AppLayout.referenceViewport.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/home_bg_default.png',
                    fit: BoxFit.fill,
                  ),
                ),
                _CalendarHeader(
                  photoUrl: _plantPhotoUrl,
                  plantName: _plantName,
                  mode: _mode,
                  onModeChanged: _changeMode,
                ),
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
                    left: 13,
                    right: 13,
                    top: 562,
                    height: 150,
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
                      onRetry: _loadCalendar,
                    ),
                  )
                else
                  Positioned(
                    left: 13,
                    right: 13,
                    top: 316,
                    height: 397,
                    child: _WeekAgenda(
                      weekStart: _startOfWeek(_selected),
                      items: _items,
                      loading: _loading,
                      error: _error,
                      completingIds: _completingIds,
                      onComplete: _complete,
                      onRetry: _loadCalendar,
                    ),
                  ),
                Positioned(
                  left: 326,
                  top: 726,
                  width: 53,
                  height: 53,
                  child: GestureDetector(
                    key: const ValueKey('calendar-add'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _showCreateSheet,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0x33000000), blurRadius: 4),
                        ],
                      ),
                      child: SvgPicture.asset('assets/images/calendar_fab.svg'),
                    ),
                  ),
                ),
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
                        MaterialPageRoute(builder: (_) => const MyPageScreen()),
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
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.photoUrl,
    required this.plantName,
    required this.mode,
    required this.onModeChanged,
  });

  final String? photoUrl;
  final String? plantName;
  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 23,
          top: 50,
          width: 41,
          height: 41,
          child: Semantics(
            label: plantName == null ? '식물 프로필' : '$plantName 프로필',
            image: true,
            child: ClipOval(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: kAppleGreen, width: 1),
                ),
                child: photoUrl == null
                    ? Padding(
                        padding: const EdgeInsets.all(5),
                        child: Image.asset(
                          'assets/images/leafie_character_sprout.png',
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/leafie_character_sprout.png',
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 60,
          child: Center(child: Text('캘린더', style: kTitleStyle)),
        ),
        Positioned(
          left: 335,
          top: 58,
          child: _ModeSwitch(mode: mode, onChanged: onModeChanged),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 25,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kOrangeMain, width: 1),
      ),
      child: Row(
        children: [
          _modeButton('월', CalendarViewMode.month),
          _modeButton('주', CalendarViewMode.week),
        ],
      ),
    );
  }

  Widget _modeButton(String label, CalendarViewMode value) {
    final selected = mode == value;
    return Expanded(
      child: GestureDetector(
        key: ValueKey('calendar-mode-${value.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? kOrangeMain : Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              label,
              style: kCaptionStyle.copyWith(
                color: selected ? Colors.white : kTextDark,
                fontSize: 11,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.items,
    required this.onSelect,
    required this.onShift,
  });

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
    const gridWidth = 351.0;
    final cellWidth = gridWidth / 7;
    final cellHeight = 283.0 / rows;
    return Stack(
      children: [
        const Positioned(
          left: 10,
          top: 123,
          width: 381,
          height: 424,
          child: _PaperPanel(),
        ),
        const _PaperPins(top: 110),
        Positioned(
          left: 133,
          top: 141,
          width: 136,
          height: 28,
          child: _PeriodNavigation(
            label: '${month.year}. ${month.month}',
            onShift: onShift,
          ),
        ),
        for (var i = 0; i < 7; i++)
          Positioned(
            left: 26 + i * cellWidth,
            top: 194,
            width: cellWidth,
            child: Center(
              child: Text(
                _weekdays[i],
                style: kSmallStyle.copyWith(
                  color: kBrightOrange,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        for (var index = 0; index < rows * 7; index++)
          Positioned(
            left: 26 + (index % 7) * cellWidth,
            top: 232 + (index ~/ 7) * cellHeight,
            width: cellWidth,
            height: cellHeight,
            child: _MonthDayCell(
              date: index >= leading && index - leading < days
                  ? DateTime(month.year, month.month, index - leading + 1)
                  : null,
              selected: selected,
              items: index >= leading && index - leading < days
                  ? items
                        .where(
                          (item) => _sameDay(
                            item.date,
                            DateTime(
                              month.year,
                              month.month,
                              index - leading + 1,
                            ),
                          ),
                        )
                        .toList()
                  : const [],
              onSelect: onSelect,
            ),
          ),
      ],
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: value == null ? null : () => onSelect(value),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: kBrightOrange, width: 0.6),
        ),
        child: value == null
            ? const SizedBox.expand()
            : Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 7,
                    child: Center(
                      child: Text(
                        '${value.day}',
                        style: kBodyStyle.copyWith(
                          color: isSelected ? kBrightOrange : kTextDark,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 3,
                      child: Center(
                        child: CalendarEventIcon(
                          type: items.first.type,
                          width: 17,
                          height: 23,
                        ),
                      ),
                    ),
                ],
              ),
      ),
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
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    const cellWidth = 350.0 / 7;
    return Stack(
      children: [
        const Positioned(
          left: 10,
          top: 132,
          width: 381,
          height: 166,
          child: _PaperPanel(),
        ),
        const _PaperPins(top: 119),
        Positioned(
          left: 133,
          top: 142,
          width: 136,
          height: 28,
          child: _PeriodNavigation(
            label: '${selected.year}. ${selected.month}',
            onShift: onShift,
          ),
        ),
        for (var i = 0; i < 7; i++) ...[
          Positioned(
            left: 26 + i * cellWidth,
            top: 190,
            width: cellWidth,
            child: Center(
              child: Text(
                _weekdays[i],
                style: kSmallStyle.copyWith(
                  color: kBrightOrange,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            left: 26 + i * cellWidth,
            top: 222,
            width: cellWidth,
            height: 57,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(days[i]),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: kBrightOrange, width: 0.6),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 8,
                      child: Center(
                        child: Text(
                          '${days[i].day}',
                          style: kBodyStyle.copyWith(
                            color: _sameDay(days[i], selected)
                                ? kBrightOrange
                                : kTextDark,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    if (items.any((item) => _sameDay(item.date, days[i])))
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 2,
                        child: Center(
                          child: CalendarEventIcon(
                            type: items
                                .firstWhere(
                                  (item) => _sameDay(item.date, days[i]),
                                )
                                .type,
                            width: 17,
                            height: 23,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PaperPanel extends StatelessWidget {
  const _PaperPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
      child: const CustomPaint(painter: _CalendarPaperPainter()),
    );
  }
}

class _CalendarPaperPainter extends CustomPainter {
  const _CalendarPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(26);
    final paint = Paint()..strokeWidth = 0.35;
    for (var i = 0; i < 700; i++) {
      paint.color = Color.fromARGB(18, 150, 150, 150 + random.nextInt(25));
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + random.nextDouble() * 7, y + random.nextDouble() * 5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CalendarPaperPainter oldDelegate) => false;
}

class _PaperPins extends StatelessWidget {
  const _PaperPins({required this.top});

  final double top;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final left in const [36.0, 352.0])
          Positioned(
            left: left,
            top: top,
            width: 14,
            height: 51,
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFFFECA6),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 14, height: 14),
                  ),
                ),
                Positioned(
                  left: 3,
                  top: 0,
                  width: 9,
                  height: 43,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD3D3D3),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PeriodNavigation extends StatelessWidget {
  const _PeriodNavigation({required this.label, required this.onShift});

  final String label;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chevron(-1, Icons.chevron_left),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: kTitleStyle.copyWith(fontSize: 20, height: 1),
            ),
          ),
        ),
        _chevron(1, Icons.chevron_right),
      ],
    );
  }

  Widget _chevron(int delta, IconData icon) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onShift(delta),
    child: SizedBox(
      width: 27,
      height: 28,
      child: Icon(icon, color: kBrightOrange, size: 26),
    ),
  );
}

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
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final title = _sameDay(selected, today)
        ? '오늘 할 일'
        : '${selected.year}. ${selected.month}.${selected.day} ${_weekdayLabel(selected)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 22, bottom: 7),
          child: Text(
            title,
            style: kBodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
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
  final VoidCallback onRetry;

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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final entry = groups.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 22, bottom: 7),
              child: Text(
                '${entry.key.year}. ${entry.key.month}.${entry.key.day} ${_weekdayLabel(entry.key)}',
                style: kBodyStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            for (var i = 0; i < entry.value.length; i++) ...[
              _CalendarEventCard(
                item: entry.value[i],
                completing: completingIds.contains(entry.value[i].id),
                onComplete: () => onComplete(entry.value[i]),
              ),
              if (i != entry.value.length - 1) const SizedBox(height: 9),
            ],
          ],
        );
      },
    );
  }
}

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
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: kOrangeMain),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: TextButton(
          onPressed: onRetry,
          child: Text('$error\n다시 불러오기', textAlign: TextAlign.center),
        ),
      );
    }
    if (items.isEmpty) return const _EmptyAgenda();
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) => _CalendarEventCard(
        item: items[index],
        completing: completingIds.contains(items[index].id),
        onComplete: () => onComplete(items[index]),
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      '등록된 일정이 없어요.',
      style: kCaptionStyle.copyWith(color: kTextDark),
    ),
  );
}

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({
    required this.item,
    required this.completing,
    required this.onComplete,
  });

  final CalendarItemData item;
  final bool completing;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final completed = item.status == 'COMPLETED';
    return Container(
      height: 51,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 4,
            offset: Offset(1, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 10,
            width: 26,
            height: 31,
            child: CalendarEventIcon(type: item.type),
          ),
          Positioned(
            left: 95.29,
            top: 0,
            width: 108.61,
            height: 51,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _eventTitle(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kBodyStyle.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Positioned(
            left: 214.15,
            top: 0,
            width: 78,
            height: 51,
            child: Center(
              child: Text(
                '${item.date.year}. ${item.date.month}.${item.date.day} ${_weekdayLabel(item.date)}',
                maxLines: 1,
                style: kCaptionStyle.copyWith(color: kTextLight, fontSize: 11),
              ),
            ),
          ),
          Positioned(
            left: 323,
            top: 0,
            width: 51,
            height: 51,
            child: GestureDetector(
              key: ValueKey('calendar-complete-${item.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: item.completable && !completing ? onComplete : null,
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
                    : Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: completed ? kOrangeMain : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: completed
                                ? kOrangeMain
                                : const Color(0xFFE7E7E7),
                          ),
                        ),
                        child: completed
                            ? const Icon(
                                Icons.check_rounded,
                                size: 19,
                                color: Colors.white,
                              )
                            : null,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CalendarEventIcon extends StatelessWidget {
  const CalendarEventIcon({
    super.key,
    required this.type,
    this.width = 26,
    this.height = 31,
  });

  final String type;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final asset = switch (type) {
      'WATERING' => 'assets/images/calendar_event_water.svg',
      'REPOTTING' => 'assets/images/calendar_event_repot.svg',
      'FERTILIZING' => 'assets/images/calendar_event_fertilize.svg',
      _ => null,
    };
    if (asset != null) {
      final naturalSize = switch (type) {
        'WATERING' => const Size(17, 24),
        'REPOTTING' => const Size(26, 25),
        'FERTILIZING' => const Size(19, 31),
        _ => Size(width, height),
      };
      final scale = math.min(
        width / naturalSize.width,
        height / naturalSize.height,
      );
      return Center(
        child: SvgPicture.asset(
          asset,
          width: naturalSize.width * scale,
          height: naturalSize.height * scale,
        ),
      );
    }
    return Icon(
      type == 'PRUNING' ? Icons.content_cut_rounded : Icons.eco_rounded,
      size: math.min(width, height),
      color: kOrangeMain,
    );
  }
}

class _NewCalendarEvent {
  const _NewCalendarEvent({
    required this.type,
    required this.title,
    required this.date,
  });

  final String type;
  final String title;
  final DateTime date;
}

class _NewEventSheet extends StatefulWidget {
  const _NewEventSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_NewEventSheet> createState() => _NewEventSheetState();
}

class _NewEventSheetState extends State<_NewEventSheet> {
  String _type = 'FERTILIZING';
  late DateTime _date = widget.initialDate;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: kOrangeMain)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '일정 추가',
              style: kTitleStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _typeChoice('FERTILIZING', '비료 주기')),
                const SizedBox(width: 12),
                Expanded(child: _typeChoice('PRUNING', '가지치기')),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _pickDate,
              style: OutlinedButton.styleFrom(
                foregroundColor: kTextDark,
                side: const BorderSide(color: kOrangeMain),
                minimumSize: const Size.fromHeight(51),
                shape: const StadiumBorder(),
              ),
              child: Text('${_date.year}. ${_date.month}.${_date.day}'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                final title = _type == 'FERTILIZING' ? '비료 주기' : '가지치기';
                Navigator.pop(
                  context,
                  _NewCalendarEvent(type: _type, title: title, date: _date),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: kOrangeMain,
                minimumSize: const Size.fromHeight(51),
                shape: const StadiumBorder(),
              ),
              child: const Text('등록하기', style: kButtonStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChoice(String value, String label) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        height: 51,
        decoration: BoxDecoration(
          color: selected ? kPaleYellow : Colors.white,
          border: Border.all(color: selected ? kOrangeMain : kGrayLightest),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Center(child: Text(label, style: kBodyStyle)),
      ),
    );
  }
}

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _startOfWeek(DateTime value) =>
    _dateOnly(value).subtract(Duration(days: value.weekday % 7));

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _weekdayLabel(DateTime date) => _weekdays[date.weekday % 7];

String _eventTitle(CalendarItemData item) {
  final custom = item.title?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  return switch (item.type) {
    'WATERING' => '물 주기',
    'REPOTTING' => '분갈이',
    'FERTILIZING' => '비료 주기',
    'PRUNING' => '가지치기',
    'CONDITION' => '상태 기록',
    _ => '식물 관리',
  };
}
