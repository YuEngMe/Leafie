import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/screens/calendar_screen.dart';
import 'package:yeso_plant/services/diary_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/diary_components.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// Figma "다이어리"(2739:34592). 달력에서 날짜를 고르면 그 날 글로 넘어간다.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, this.store, this.today});

  final DiaryStore? store;

  /// 테스트에서 오늘을 고정한다.
  final DateTime? today;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late final DiaryStore _store = widget.store ?? ApiDiaryStore();
  late final DateTime _today = widget.today ?? DateTime.now();
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _selected = _today;
  List<DiaryEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final entries = await _store.loadMonth(_month);
      if (mounted) setState(() => _entries = entries);
    } on LeafieApiException {
      // 인증이 없는 위젯 테스트와 네트워크 오류에서도 달력은 계속 보인다.
    }
  }

  Future<void> _openDay(DateTime date) async {
    setState(() => _selected = date);
    final DiaryEntry entry;
    try {
      entry = await _store.loadDay(date) ?? DiaryEntry(date: date);
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    final saved = await Navigator.push<DiaryEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEntryScreen(entry: entry, store: _store),
      ),
    );
    if (saved == null || !mounted) return;

    try {
      if (saved.isEmpty) {
        await _store.delete(saved.date);
      } else {
        await _store.save(saved);
      }
      await _reload();
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
        onNavTap: (tab) => switch (tab) {
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
            Positioned.fromRect(rect: DiaryLayout.tab, child: const DiaryTab()),
            Positioned.fromRect(
              rect: DiaryLayout.prevButton,
              child: _MonthButton(
                label: '이전 달',
                pointsLeft: true,
                color: kDiaryPrevGreen,
                onPressed: () => _shiftMonth(-1),
              ),
            ),
            Positioned.fromRect(
              rect: DiaryLayout.nextButton,
              child: _MonthButton(
                label: '다음 달',
                pointsLeft: false,
                color: kDiaryNextPink,
                onPressed: () => _shiftMonth(1),
              ),
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
    return IconButton(
      onPressed: onPressed,
      icon: SvgPicture.asset(
        'assets/images/icon_diary_edit.svg',
        width: DiaryLayout.editIcon.width,
        height: DiaryLayout.editIcon.height,
      ),
      key: const ValueKey('diary-appbar-edit'),
      tooltip: '오늘 다이어리 쓰기',
    );
  }
}

/// 달 넘김 버튼(3496:11993, 3496:11996). 색과 방향만 다르다.
class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.label,
    required this.pointsLeft,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool pointsLeft;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Semantics(
        label: label,
        button: true,
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
          child: Center(
            child: CustomPaint(
              // 시안 Polygon 59는 폭 12.7 x 높이 22.4다. Material 화살표
              // 아이콘은 이보다 훨씬 커서 직접 그린다.
              size: const Size(12.67, 22.44),
              painter: _ArrowPainter(pointsLeft: pointsLeft),
            ),
          ),
        ),
      ),
    );
  }
}

/// 모서리가 살짝 둥근 삼각형(3496:11993 Polygon 59).
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.pointsLeft});

  final bool pointsLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.save();
    if (!pointsLeft) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas.drawPath(path, Paint()..color = kBackgroundWhite);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.pointsLeft != pointsLeft;
}

/// Figma "다이어리 작성"(2739:39308)과 "읽기"(2739:39860).
///
/// 시안은 두 화면이지만 같은 종이에 글이 있느냐 없느냐만 다르다.
class DiaryEntryScreen extends StatefulWidget {
  const DiaryEntryScreen({
    super.key,
    required this.entry,
    this.imagePicker,
    this.store,
  });

  final DiaryEntry entry;

  /// 위젯 테스트에서 갈아끼운다.
  final ImagePicker? imagePicker;
  final DiaryStore? store;

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late final _titleController = TextEditingController(text: widget.entry.title);
  late final _bodyController = TextEditingController(text: widget.entry.body);
  late String? _photoPath = widget.entry.photoPath;
  late final String? _photoUrl = widget.entry.photoUrl;
  late DiaryWeather? _weather = widget.entry.weather;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
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
    if (picked == null || !mounted) return;
    setState(() => _photoPath = picked!.path);
  }

  /// 앞뒤 버튼. 쓴 글을 저장하고 옆 날짜로 넘어간다.
  Future<void> _shiftDay(int delta) async {
    final next = widget.entry.date.add(Duration(days: delta));
    final store = widget.store;
    if (store != null) {
      try {
        final current = _currentEntry();
        if (current.isEmpty) {
          await store.delete(current.date);
        } else {
          await store.save(current);
        }
        final nextEntry = await store.loadDay(next) ?? DiaryEntry(date: next);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DiaryEntryScreen(
              entry: nextEntry,
              store: store,
              imagePicker: widget.imagePicker,
            ),
          ),
        );
      } on LeafieApiException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEntryScreen(entry: DiaryEntry(date: next)),
      ),
    );
  }

  DiaryEntry _currentEntry() => widget.entry.copyWith(
    title: _titleController.text,
    body: _bodyController.text,
    photoPath: _photoPath,
    photoUrl: _photoUrl,
    weather: _weather,
  );

  void _save() => Navigator.pop(context, _currentEntry());

  /// 시안 2739:39851 '2026년 7월 15일 토요일'.
  String get _dateLabel {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    final d = widget.entry.date;
    return '${d.year}년 ${d.month}월 ${d.day}일 ${names[d.weekday - 1]}요일';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 뒤로가기로 나가도 쓴 글을 잃지 않는다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _save();
      },
      child: Scaffold(
        backgroundColor: kBackgroundWhite,
        extendBodyBehindAppBar: true,
        appBar: YesoAppBar(
          title: '다이어리',
          backgroundColor: Colors.transparent,
          backIconColor: kOrangeMain,
          actions: [_EditAction(onPressed: _save)],
        ),
        body: DiaryScaffoldBody(
          // 시안(2739:39643)은 글쓰기에도 하단 네비를 둔다.
          onNavTap: (tab) => switch (tab) {
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
              Positioned(
                left: 55,
                top: 423.4,
                width: 286,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('제목: ', style: kItemStyle.copyWith(color: kTextDark)),
                    Expanded(
                      child: TextField(
                        controller: _titleController,
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
              Positioned(
                left: 54,
                top: 460,
                width: 288,
                height: 232,
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: kBodyStyle.copyWith(height: 23 / 16),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '다이어리를 기록하세요',
                    hintStyle: kBodyStyle.copyWith(
                      height: 23 / 16,
                      color: kGrayLightest,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: DiaryLayout.tab,
                child: const DiaryTab(),
              ),
              // 글쓰기의 앞뒤 버튼(3173:185)은 달력보다 위, 493·561에 있다.
              Positioned.fromRect(
                rect: DiaryLayout.entryPrevButton,
                child: _MonthButton(
                  label: '이전 날',
                  pointsLeft: true,
                  color: kDiaryPrevGreen,
                  onPressed: () => _shiftDay(-1),
                ),
              ),
              Positioned.fromRect(
                rect: DiaryLayout.entryNextButton,
                child: _MonthButton(
                  label: '다음 날',
                  pointsLeft: false,
                  color: kDiaryNextPink,
                  onPressed: () => _shiftDay(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BodyBox extends StatelessWidget {
  const _BodyBox();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(border: Border.all(color: kOrangeMain)),
    child: const SizedBox.expand(),
  );
}
