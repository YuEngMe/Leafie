import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/screens/calendar_screen.dart';
import 'package:yeso_plant/services/diary_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/diary_components.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// Figma "다이어리"(2739:34592). 달력에서 날짜를 고르면 그 날 글로 넘어간다.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    this.plantId,
    this.resolvePlantIdIfMissing = true,
    this.store,
    this.today,
    this.showBottomNav = true,
  });

  final bool showBottomNav;
  final String? plantId;
  final bool resolvePlantIdIfMissing;

  final DiaryStore? store;

  /// 테스트에서 오늘을 고정한다.
  final DateTime? today;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late final DiaryStore _store =
      widget.store ??
      ApiDiaryStore(
        plantId: widget.plantId,
        resolvePlantIdIfMissing: widget.resolvePlantIdIfMissing,
      );
  late final DateTime _today = widget.today ?? DateTime.now();
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _selected = _today;
  List<DiaryEntry> _entries = const [];
  int _reloadVersion = 0;
  bool _openingDay = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final version = ++_reloadVersion;
    final requestedMonth = _month;
    try {
      final entries = await _store.loadMonth(requestedMonth);
      if (!mounted || version != _reloadVersion || requestedMonth != _month) {
        return;
      }
      setState(() => _entries = entries);
    } on LeafieApiException {
      // 인증이 없는 위젯 테스트와 네트워크 오류에서도 달력은 계속 보인다.
    }
  }

  Future<void> _openDay(DateTime date) async {
    if (_openingDay) return;
    _openingDay = true;
    setState(() => _selected = date);
    try {
      final loaded = await _store.loadDay(date);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => DiaryEntryScreen(
            entry: loaded ?? DiaryEntry(date: date),
            entryExists: loaded != null,
            plantId: widget.plantId,
            store: _store,
          ),
        ),
      );
      if (!mounted) return;
      await _reload();
    } catch (error) {
      if (!mounted) return;
      _showDiaryError(
        context,
        error,
        action: '다이어리를 열지 못했어요.',
        bottomMargin:
            AppLayout.homeBottomNavHeight *
                MediaQuery.sizeOf(context).height /
                AppLayout.referenceViewport.height +
            12,
      );
    } finally {
      if (mounted) {
        _openingDay = false;
      }
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      // 배경 일러스트가 상태바 뒤까지 이어진다(2739:34593). 시안 좌표를
      // 화면 절대값 그대로 쓸 수 있게 앱바를 띄운다.
      extendBodyBehindAppBar: true,
      appBar: YesoAppBar(
        title: '다이어리',
        backgroundColor: Colors.transparent,
        backIconColor: kOrangeMain,
      ),
      body: DiaryScaffoldBody(
        onFabPressed: () => _openDay(_selected),
        paperTabs: _paperTabs(
          previousLabel: '이전 달',
          nextLabel: '다음 달',
          onPrevious: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
        ),
        onNavTap: !widget.showBottomNav
            ? null
            : (tab) => switch (tab) {
                // 다이어리는 이미 여기다. 홈·마이는 뒤로 돌아가면 된다.
                FigmaNavIcon.home || FigmaNavIcon.my => Navigator.pop(context),
                FigmaNavIcon.calendar => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CalendarScreen()),
                ),
                _ => null,
              },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DiaryCalendar(
              month: _month,
              selected: _selected,
              onSelect: _openDay,
              markedDays: {
                for (final e in _entries)
                  if (e.date.year == _month.year &&
                      e.date.month == _month.month)
                    e.date.day,
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 앱바 오른쪽 편집 아이콘(2739:34955).
class _EditAction extends StatelessWidget {
  const _EditAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // 3345:792 / 3496:10734: x354 y52. 앱바(46~92) 오른쪽 끝 48×46
    // 상자 안에서 위 6, 왼쪽 0(= 402 − 19.344 − 28.656)에 놓는다.
    return Semantics(
      button: true,
      label: '오늘 다이어리 쓰기',
      child: GestureDetector(
        key: const ValueKey('diary-appbar-edit'),
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: YesoAppBar.height,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 6,
                child: SvgPicture.asset(
                  'assets/images/icon_diary_edit.svg',
                  width: DiaryLayout.editIcon.width,
                  height: DiaryLayout.editIcon.height,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 달 넘김 버튼(3496:11993, 3496:11996). 색과 방향만 다르다.
class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.label,
    required this.pointsLeft,
    required this.onPressed,
  });

  final String label;
  final bool pointsLeft;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Semantics(
        label: label,
        button: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: pointsLeft ? kDiaryPrevGreen : kDiaryNextPink,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 4,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -4,
              top: -0.9,
              child: SvgPicture.asset(
                pointsLeft
                    ? 'assets/images/icon_diary_prev.svg'
                    : 'assets/images/icon_diary_next.svg',
                width: pointsLeft ? 53 : 52,
                height: 50.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _paperTabs({
  required String previousLabel,
  required String nextLabel,
  required VoidCallback onPrevious,
  required VoidCallback onNext,
}) => [
  Positioned.fromRect(
    rect: DiaryLayout.prevButton,
    child: _MonthButton(
      label: previousLabel,
      pointsLeft: true,
      onPressed: onPrevious,
    ),
  ),
  Positioned.fromRect(
    rect: DiaryLayout.nextButton,
    child: _MonthButton(label: nextLabel, pointsLeft: false, onPressed: onNext),
  ),
];

/// Figma "다이어리 작성"(2739:39308)과 "읽기"(2739:39860).
///
/// 시안은 두 화면이지만 같은 종이에 글이 있느냐 없느냐만 다르다.
class DiaryEntryScreen extends StatefulWidget {
  const DiaryEntryScreen({
    super.key,
    required this.entry,
    this.entryExists = false,
    this.plantId,
    this.imagePicker,
    this.store,
  });

  final DiaryEntry entry;
  final bool entryExists;
  final String? plantId;

  /// 위젯 테스트에서 갈아끼운다.
  final ImagePicker? imagePicker;
  final DiaryStore? store;

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late DiaryEntry _entry = widget.entry;
  late final _titleController = TextEditingController(text: widget.entry.title);
  late final _bodyController = TextEditingController(text: widget.entry.body);
  late String? _photoPath = widget.entry.photoPath;
  late String? _photoUrl = widget.entry.photoUrl;
  late String? _mediaFileId = widget.entry.mediaFileId;
  late DiaryWeather? _weather = widget.entry.weather;
  late DiaryEntry? _persistedEntry = widget.entryExists || !widget.entry.isEmpty
      ? widget.entry
      : null;
  late bool _recordExists = widget.entryExists || !widget.entry.isEmpty;
  bool _submitting = false;
  int _photoRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    // '저장하기'(3631:2600)는 글 읽기(3496:10291)에만 있고 빈 글쓰기
    // (2739:39308)에는 없다. 내용이 생기는 순간 나타나게 입력을 듣는다.
    _titleController.addListener(_refresh);
    _bodyController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_submitting) return;
    final requestVersion = ++_photoRequestVersion;
    final requestedDate = _entry.date;
    final XFile? picked;
    try {
      picked = await (widget.imagePicker ?? ImagePicker()).pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진을 불러오지 못했어요.')));
      return;
    }
    if (picked == null ||
        !mounted ||
        requestVersion != _photoRequestVersion ||
        !DiaryEntry.sameDay(requestedDate, _entry.date)) {
      return;
    }
    setState(() => _photoPath = picked!.path);
  }

  /// 앞뒤 버튼. 쓴 글을 저장하고 옆 날짜로 넘어간다.
  Future<void> _shiftDay(int delta) async {
    if (_submitting) return;
    final next = _entry.date.add(Duration(days: delta));
    final store = widget.store;
    if (store != null) {
      await _runSubmission(() async {
        await _persistCurrent();
        final loaded = await store.loadDay(next);
        final nextEntry = loaded ?? DiaryEntry(date: next);
        if (!mounted) return;
        _setCurrentEntry(nextEntry, exists: loaded != null);
      });
      return;
    }
    _setCurrentEntry(DiaryEntry(date: next), exists: false);
  }

  DiaryEntry _currentEntry() => DiaryEntry(
    date: _entry.date,
    title: _titleController.text,
    body: _bodyController.text,
    photoPath: _photoPath,
    photoUrl: _photoUrl,
    mediaFileId: _mediaFileId,
    weather: _weather,
  );

  Future<void> _persistCurrent() async {
    final store = widget.store;
    final current = _currentEntry();
    if (store == null || _sameEntry(current, _persistedEntry)) return;
    if (current.isEmpty) {
      if (_recordExists) await store.delete(current.date);
      _recordExists = false;
    } else {
      await store.save(current);
      _recordExists = true;
    }
    _persistedEntry = current;
  }

  Future<void> _runSubmission(Future<void> Function() operation) async {
    if (_submitting) return;
    _photoRequestVersion++;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        _showDiaryError(context, error, action: '저장하지 못했어요.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _exit() => _runSubmission(() async {
    await _persistCurrent();
    if (!mounted) return;
    Navigator.pop(context);
  });

  Future<void> _openCalendar() => _runSubmission(() async {
    await _persistCurrent();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarScreen(plantId: widget.plantId),
      ),
    );
  });

  void _setCurrentEntry(DiaryEntry entry, {required bool exists}) {
    _photoRequestVersion++;
    setState(() {
      _entry = entry;
      _persistedEntry = exists ? entry : null;
      _recordExists = exists;
      _titleController.text = entry.title;
      _bodyController.text = entry.body;
      _photoPath = entry.photoPath;
      _photoUrl = entry.photoUrl;
      _mediaFileId = entry.mediaFileId;
      _weather = entry.weather;
    });
  }

  /// 시안 2739:39851 '2026년 7월 15일 토요일'.
  String get _dateLabel {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    final d = _entry.date;
    return '${d.year}년 ${d.month}월 ${d.day}일 ${names[d.weekday - 1]}요일';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 뒤로가기로 나가도 쓴 글을 잃지 않는다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: kBackgroundWhite,
        extendBodyBehindAppBar: true,
        appBar: YesoAppBar(
          title: '다이어리',
          backgroundColor: Colors.transparent,
          backIconColor: kOrangeMain,
          actions: [_EditAction(onPressed: () => _exit())],
        ),
        body: AbsorbPointer(
          absorbing: _submitting,
          child: DiaryScaffoldBody(
            paperTabs: _paperTabs(
              previousLabel: '이전 날',
              nextLabel: '다음 날',
              onPrevious: () => _shiftDay(-1),
              onNext: () => _shiftDay(1),
            ),
            // 시안(2739:39643)은 글쓰기에도 하단 네비를 둔다.
            onNavTap: (tab) => switch (tab) {
              FigmaNavIcon.home || FigmaNavIcon.my => _exit(),
              FigmaNavIcon.calendar => _openCalendar(),
              _ => null,
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 사진칸 3496:10622.
                Positioned(
                  left: 46,
                  top: 144.74,
                  width: 304,
                  height: 259.58,
                  child: DiaryPhotoBox(
                    photoPath: _photoPath,
                    photoUrl: _photoUrl,
                    onTap: _pickPhoto,
                  ),
                ),
                // 날짜 줄. 사진칸 위쪽에 겹쳐 놓인다(2739:39851).
                Positioned(
                  left: 54,
                  top: 149,
                  child: Text(
                    _dateLabel,
                    style: kSmallStyle.copyWith(
                      height: 23 / 14,
                      color: kTextDark,
                    ),
                  ),
                ),
                // 3496:10620 세로 구분선, 3496:10619 가로선.
                const Positioned(
                  left: 212.63,
                  top: 144.74,
                  child: SizedBox(
                    width: 1,
                    height: 38.72,
                    child: ColoredBox(color: kOrangeMain),
                  ),
                ),
                const Positioned(
                  left: 46,
                  top: 183.36,
                  width: 304,
                  height: 1,
                  child: ColoredBox(color: kOrangeMain),
                ),
                DiaryWeatherPicker(
                  selected: _weather,
                  onSelect: (w) => setState(() => _weather = w),
                ),
                // 본문칸 3496:10623.
                const Positioned(
                  left: 46,
                  top: 415,
                  width: 304,
                  height: 290,
                  child: _BodyBox(),
                ),
                // 시안(2739:39792)은 '제목: 귀여운 새싹이'처럼 접두사가 글자
                // 앞에 붙어 있다. 힌트로 두면 값을 넣는 순간 사라진다.
                // 3496:10624 글자 상자 424.71~445.09의 중심에 23px 줄을 맞춘다.
                // 2026-09-11 디자이너 요청: 안쪽 여백을 조금 더 준다(좌우 +8).
                Positioned(
                  left: 63,
                  top: 423.4,
                  width: 270,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '제목: ',
                        style: kItemStyle.copyWith(color: kTextDark),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          readOnly: _submitting,
                          style: kItemStyle.copyWith(color: kTextDark),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 3496:10621 제목 밑줄, 3496:10625 본문.
                const Positioned(
                  left: 46,
                  top: 454.74,
                  width: 304,
                  height: 1,
                  child: ColoredBox(color: kOrangeMain),
                ),
                // 본문은 시안(3496:10625)보다 여백 8·행간 23→27로 조금 여유 있게
                // (2026-09-11 디자이너 요청).
                Positioned(
                  left: 62,
                  top: 466,
                  width: 272,
                  // 아래 '저장하기'(683)와 겹치지 않게 675까지.
                  height: 209,
                  child: TextField(
                    controller: _bodyController,
                    readOnly: _submitting,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    // 3496:10625 / 2739:39795: 16 Regular(400). kBodyStyle은
                    // Medium이라 굵기만 내린다.
                    style: kBodyStyle.copyWith(
                      fontWeight: FontWeight.w400,
                      height: 27 / 16,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '다이어리를 기록하세요',
                      hintStyle: kBodyStyle.copyWith(
                        fontWeight: FontWeight.w400,
                        height: 27 / 16,
                        color: kGrayLightest,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                // 저장하기(3631:2600): 본문칸 오른쪽 아래 글자 링크, x303 y683
                // 9.488px Medium #444. 글자는 작지만 누르는 범위는 48px로 둔다.
                // 빈 글쓰기 시안(2739:39308)에는 없다.
                if (!_currentEntry().isEmpty)
                  Positioned(
                    left: 303 + 17 - 24,
                    top: 683 + 5.5 - 24,
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _exit(),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Semantics(
                          button: true,
                          child: Text(
                            '저장하기',
                            style: kSmallStyle.copyWith(
                              fontSize: 9.488,
                              fontWeight: FontWeight.w500,
                              height: 1,
                              color: kTextDark,
                            ),
                          ),
                        ),
                      ),
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

bool _sameEntry(DiaryEntry entry, DiaryEntry? other) =>
    other != null &&
    DiaryEntry.sameDay(entry.date, other.date) &&
    entry.title == other.title &&
    entry.body == other.body &&
    entry.photoPath == other.photoPath &&
    entry.photoUrl == other.photoUrl &&
    entry.mediaFileId == other.mediaFileId &&
    entry.weather == other.weather;

void _showDiaryError(
  BuildContext context,
  Object error, {
  required String action,
  double? bottomMargin,
}) {
  final detail = error is LeafieApiException ? error.message : action;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: bottomMargin == null ? null : SnackBarBehavior.floating,
      margin: bottomMargin == null
          ? null
          : EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
      content: Text('$detail 다시 시도해주세요.'),
    ),
  );
}

class _BodyBox extends StatelessWidget {
  const _BodyBox();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(border: Border.all(color: kOrangeMain)),
    child: const SizedBox.expand(),
  );
}
