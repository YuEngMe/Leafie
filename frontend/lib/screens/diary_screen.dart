import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/diary_components.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 날짜별 다이어리 저장소. dio가 붙기 전까지는 세션에 담아 둔다.
///
/// 닉네임·식물과 같은 방식이라 서버가 생기면 이 클래스만 갈아끼우면 된다.
class DiaryStore {
  const DiaryStore();

  static const _key = 'leafie_diary';

  Future<List<DiaryEntry>> load() async {
    try {
      final raw =
          Supabase.instance.client.auth.currentUser?.userMetadata?[_key];
      if (raw is! String) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map(DiaryEntry.fromJson).nonNulls.toList();
    } catch (_) {
      // Supabase를 초기화하지 않은 위젯 테스트에서도 화면은 떠야 한다.
      return const [];
    }
  }

  Future<void> save(List<DiaryEntry> entries) async {
    // TODO(1-E): dio 붙이면 다이어리 API로 바꾼다.
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        data: {_key: jsonEncode(entries.map((e) => e.toJson()).toList())},
      ),
    );
  }
}

/// Figma "다이어리"(2739:34592). 달력에서 날짜를 고르면 그 날 글로 넘어간다.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, this.store = const DiaryStore(), this.today});

  final DiaryStore store;

  /// 테스트에서 오늘을 고정한다.
  final DateTime? today;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
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
    final entries = await widget.store.load();
    if (mounted) setState(() => _entries = entries);
  }

  DiaryEntry _entryFor(DateTime date) => _entries.firstWhere(
    (e) => DiaryEntry.sameDay(e.date, date),
    orElse: () => DiaryEntry(date: date),
  );

  Future<void> _openDay(DateTime date) async {
    setState(() => _selected = date);
    final saved = await Navigator.push<DiaryEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEntryScreen(entry: _entryFor(date)),
      ),
    );
    if (saved == null || !mounted) return;

    final next = [
      ..._entries.where((e) => !DiaryEntry.sameDay(e.date, saved.date)),
      if (!saved.isEmpty) saved,
    ]..sort((a, b) => a.date.compareTo(b.date));
    setState(() => _entries = next);
    await widget.store.save(next);
  }

  void _shiftMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
  });

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
        actions: [_EditAction(onPressed: () => _openDay(_selected))],
      ),
      body: DiaryScaffoldBody(
        onFabPressed: () => _openDay(_selected),
        onNavTap: (tab) => switch (tab) {
          // 다이어리는 이미 여기다. 홈·마이는 뒤로 돌아가면 된다.
          FigmaNavIcon.home || FigmaNavIcon.my => Navigator.pop(context),
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
                icon: Icons.arrow_left,
                color: kDiaryPrevGreen,
                onPressed: () => _shiftMonth(-1),
              ),
            ),
            Positioned.fromRect(
              rect: DiaryLayout.nextButton,
              child: _MonthButton(
                label: '다음 달',
                icon: Icons.arrow_right,
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
      tooltip: '오늘 다이어리 쓰기',
    );
  }
}

/// 달 넘김 버튼(2739:38803, 2739:38804). 시안은 색만 다른 삼각형이다.
class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
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
          child: Icon(icon, color: kBackgroundWhite, size: 28),
        ),
      ),
    );
  }
}

/// Figma "다이어리 작성"(2739:39308)과 "읽기"(2739:39860).
///
/// 시안은 두 화면이지만 같은 종이에 글이 있느냐 없느냐만 다르다.
class DiaryEntryScreen extends StatefulWidget {
  const DiaryEntryScreen({super.key, required this.entry, this.imagePicker});

  final DiaryEntry entry;

  /// 위젯 테스트에서 갈아끼운다.
  final ImagePicker? imagePicker;

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late final _titleController = TextEditingController(text: widget.entry.title);
  late final _bodyController = TextEditingController(text: widget.entry.body);
  late String? _photoPath = widget.entry.photoPath;
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
  void _shiftDay(int delta) {
    final next = widget.entry.date.add(Duration(days: delta));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEntryScreen(entry: DiaryEntry(date: next)),
      ),
    );
  }

  void _save() => Navigator.pop(
    context,
    widget.entry.copyWith(
      title: _titleController.text,
      body: _bodyController.text,
      photoPath: _photoPath,
      weather: _weather,
    ),
  );

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
          actions: [_EditAction(onPressed: _save)],
        ),
        body: DiaryScaffoldBody(
          // 시안(2766:692)은 글쓰기에도 연필 버튼을 둔다. 이미 이 날의
          // 글이므로 누르면 저장하고 나간다.
          onFabPressed: _save,
          // 시안(2739:39643)은 글쓰기에도 하단 네비를 둔다.
          onNavTap: (tab) => switch (tab) {
            FigmaNavIcon.home || FigmaNavIcon.my => Navigator.pop(context),
            _ => null,
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 사진칸 2739:39790.
              Positioned(
                left: 46,
                top: 143,
                width: 304,
                height: 242,
                child: DiaryPhotoBox(photoPath: _photoPath, onTap: _pickPhoto),
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
              // 2739:39788 세로 구분선, 2739:39787 가로선.
              const Positioned(
                left: 212.63,
                top: 143,
                child: SizedBox(
                  width: 1,
                  height: 36.097,
                  child: ColoredBox(color: kOrangeMain),
                ),
              ),
              const Positioned(
                left: 46,
                top: 179,
                width: 304,
                height: 1,
                child: ColoredBox(color: kOrangeMain),
              ),
              DiaryWeatherPicker(
                selected: _weather,
                onSelect: (w) => setState(() => _weather = w),
              ),
              // 본문칸 2739:39859.
              const Positioned(
                left: 46,
                top: 395,
                width: 304,
                height: 266,
                child: _BodyBox(),
              ),
              // 시안(2739:39792)은 '제목: 귀여운 새싹이'처럼 접두사가 글자
              // 앞에 붙어 있다. 힌트로 두면 값을 넣는 순간 사라진다.
              Positioned(
                left: 55,
                top: 403,
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
              const Positioned(
                left: 46,
                top: 432,
                width: 304,
                height: 1,
                child: ColoredBox(color: kOrangeMain),
              ),
              Positioned(
                left: 54,
                top: 437,
                width: 288,
                height: 216,
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: kBodyStyle.copyWith(height: 23 / 16),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: ' 다이어리를 기록하세요',
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
              // 시안(3173:178, 3173:181)은 글쓰기에도 앞뒤 버튼을 둔다.
              Positioned.fromRect(
                rect: DiaryLayout.prevButton,
                child: _MonthButton(
                  label: '이전 날',
                  icon: Icons.arrow_left,
                  color: kDiaryPrevGreen,
                  onPressed: () => _shiftDay(-1),
                ),
              ),
              Positioned.fromRect(
                rect: DiaryLayout.nextButton,
                child: _MonthButton(
                  label: '다음 날',
                  icon: Icons.arrow_right,
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
