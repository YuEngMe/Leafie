// 다이어리(2739:34592 달력, 2739:39308 작성, 2739:39860 읽기).
// 배경이 앱바 뒤까지 이어져 좌표를 화면 절대값으로 쓴다.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/screens/diary_screen.dart';
import 'package:yeso_plant/services/diary_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/widgets/diary_components.dart';

/// 시안이 그려진 기기 조건.
void _setUpView(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.reset);
}

void _expectAt(
  WidgetTester tester,
  String label,
  Finder f,
  double x,
  double y,
) {
  final rect = tester.getRect(f.first);
  expect(rect.left, closeTo(x, 3), reason: '$label x');
  expect(rect.top, closeTo(y, 1), reason: '$label y');
}

/// 저장을 흉내만 내는 저장소.
class _MemoryStore implements DiaryStore {
  List<DiaryEntry> entries = const [];
  int saveCount = 0;

  @override
  Future<List<DiaryEntry>> loadMonth(DateTime month) async => entries
      .where(
        (entry) =>
            entry.date.year == month.year && entry.date.month == month.month,
      )
      .toList();

  @override
  Future<DiaryEntry?> loadDay(DateTime date) async {
    for (final entry in entries) {
      if (DiaryEntry.sameDay(entry.date, date)) return entry;
    }
    return null;
  }

  @override
  Future<void> save(DiaryEntry next) async {
    entries = [
      ...entries.where((entry) => !DiaryEntry.sameDay(entry.date, next.date)),
      next,
    ];
    saveCount++;
  }

  @override
  Future<void> delete(DateTime date) async {
    entries = entries
        .where((entry) => !DiaryEntry.sameDay(entry.date, date))
        .toList();
  }
}

void main() {
  test('날씨 아이콘은 Figma 순서와 백엔드 의미를 그대로 따른다', () {
    expect(DiaryWeather.values, [
      DiaryWeather.sunny,
      DiaryWeather.partlyCloudy,
      DiaryWeather.cloudy,
      DiaryWeather.snowy,
      DiaryWeather.rainy,
    ]);
    expect(DiaryWeather.values.map((weather) => weather.label), [
      '맑음',
      '구름 조금',
      '흐림',
      '눈',
      '비',
    ]);
    expect(DiaryWeather.values.map((weather) => weather.asset), [
      'assets/images/icon_weather_sun_off.svg',
      'assets/images/icon_weather_partly_off.svg',
      'assets/images/icon_weather_cloud_off.svg',
      'assets/images/icon_weather_rain_off.svg',
      'assets/images/icon_weather_drop_off.svg',
    ]);
    expect(DiaryWeather.values.map((weather) => weather.selectedAsset), [
      'assets/images/icon_weather_sun_on.svg',
      'assets/images/icon_weather_partly_on.svg',
      'assets/images/icon_weather_cloud_on.svg',
      'assets/images/icon_weather_rain_on.svg',
      'assets/images/icon_weather_drop_on.svg',
    ]);
    expect(
      DiaryWeather.values.map((weather) => (weather.width, weather.height)),
      [
        (21.024, 21.023),
        (24.93, 19.99),
        (25.365, 14.634),
        (19.702, 21.225),
        (17.671, 19.092),
      ],
    );
  });

  group('달력 (2739:34592)', () {
    testWidgets('시안 좌표를 지킨다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(home: DiaryScreen(today: DateTime(2026, 7, 15))),
      );
      await tester.pumpAndSettle();

      _expectAt(tester, '연도', find.text('2026'), 177, 162.72);
      _expectAt(tester, '월', find.text('7'), 181.67, 179.26);
      // 3496:12138 / 12144 — 글자 중심 x 64.33, 327.90.
      expect(tester.getCenter(find.text('일')).dx, closeTo(64.33, 1));
      expect(tester.getCenter(find.text('토')).dx, closeTo(327.90, 1));
      expect(tester.getRect(find.text('일')).top, closeTo(262.61, 1));
      _expectAt(tester, '이전 달', find.bySemanticsLabel('이전 달'), 350, 493);
      _expectAt(tester, '다음 달', find.bySemanticsLabel('다음 달'), 351, 561);
      final body = tester.widget<DiaryScaffoldBody>(
        find.byType(DiaryScaffoldBody),
      );
      // 파란 책갈피는 2026-09-11 디자이너 요청으로 뺐다. 앞뒤 버튼 둘만 남는다.
      expect(body.paperTabs, hasLength(2));
      // 시안 3496:12213에서 자리가 바뀌었다.
      _expectAt(tester, '하단 작성 버튼', find.bySemanticsLabel('다이어리 쓰기'), 302, 661);
      expect(find.byKey(const ValueKey('diary-appbar-edit')), findsNothing);
      await tester.runAsync(() async {
        final context = tester.element(find.byType(DiaryScreen));
        for (final asset in [
          'diary_background.png',
          'diary_paper_texture.png',
        ]) {
          await precacheImage(AssetImage('assets/images/$asset'), context);
        }
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(DiaryScreen),
        matchesGoldenFile('goldens/diary_calendar_controls_402.png'),
      );
    });

    testWidgets('글을 쓴 날 칸 오른쪽 아래에 새싹을 그린다(6089:2516)', (tester) async {
      _setUpView(tester);
      final store = _MemoryStore()
        ..entries = [
          DiaryEntry(date: DateTime(2026, 7, 1), title: '첫날'),
          DiaryEntry(date: DateTime(2026, 7, 2), title: '둘째 날'),
          DiaryEntry(date: DateTime(2026, 7, 9), title: '아홉째 날'),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryScreen(today: DateTime(2026, 7, 15), store: store),
        ),
      );
      await tester.pumpAndSettle();

      final sprouts = find.byKey(const ValueKey('diary-written-mark'));
      expect(sprouts, findsNWidgets(3));
      final rects = [for (var i = 0; i < 3; i++) tester.getRect(sprouts.at(i))]
        ..sort(
          (a, b) => a.top == b.top
              ? a.left.compareTo(b.left)
              : a.top.compareTo(b.top),
        );
      // 4534:3781 '다이어리 5': 1일 (199.49, 338.79), 2일 (244, 339),
      // 9일 (244, 405). 16.22×16.49.
      expect(rects[0].left, closeTo(199.49, 1));
      expect(rects[0].top, closeTo(338.79, 1));
      expect(rects[1].left, closeTo(244, 1));
      expect(rects[1].top, closeTo(339, 1));
      expect(rects[2].left, closeTo(244, 1));
      expect(rects[2].top, closeTo(405, 1));
      expect(rects[0].width, closeTo(16.22, 0.1));
      expect(rects[0].height, closeTo(16.49, 0.1));
    });

    testWidgets('그 달의 날짜를 빠짐없이 그린다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(home: DiaryScreen(today: DateTime(2026, 7, 15))),
      );
      await tester.pumpAndSettle();

      // 2026년 7월은 31일까지다.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.text('32'), findsNothing);
    });

    testWidgets('고른 날은 찐 오렌지, 격자선은 칸 경계 가운데 한 줄', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(home: DiaryScreen(today: DateTime(2026, 7, 15))),
      );
      await tester.pumpAndSettle();

      // 4534:4176 고른 날(15) #FF8834, 나머지 #444.
      expect(tester.widget<Text>(find.text('15')).style!.color, kBrightOrange);
      expect(tester.widget<Text>(find.text('16')).style!.color, kTextDark);

      // 4534:4142~ border 0.769를 경계 가운데에 그어 이웃 칸 선이 겹친다.
      final cells = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border?.top.color ==
                kDiaryGridLine,
      );
      expect(cells, findsNWidgets(35));
      final side =
          (tester.widget<DecoratedBox>(cells.first).decoration as BoxDecoration)
              .border!
              .top;
      expect(side.width, 0.769);
      expect(side.strokeAlign, BorderSide.strokeAlignCenter);
    });

    testWidgets('달 넘김 버튼이 월을 바꾼다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(home: DiaryScreen(today: DateTime(2026, 7, 15))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('다음 달'));
      await tester.pumpAndSettle();
      // 8월은 31일까지, 제목은 8.
      expect(find.text('8'), findsWidgets);

      await tester.tap(find.bySemanticsLabel('이전 달'));
      await tester.tap(find.bySemanticsLabel('이전 달'));
      await tester.pumpAndSettle();
      // 6월은 30일까지다.
      expect(find.text('31'), findsNothing);
    });

    testWidgets('여섯 주가 필요한 달도 마지막 주를 그린다', (tester) async {
      _setUpView(tester);
      // 2026-08은 토요일 시작 31일 → 6주.
      await tester.pumpWidget(
        MaterialApp(home: DiaryScreen(today: DateTime(2026, 8, 15))),
      );
      await tester.pumpAndSettle();
      expect(find.text('30'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      // 여섯 줄이 시안 격자 높이(292.89~625.53) 안에 들어온다.
      expect(tester.getRect(find.text('31')).bottom, lessThan(626));
    });

    testWidgets('날짜를 누르면 그 날 글로 넘어간다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryScreen(
            store: _MemoryStore(),
            today: DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryEntryScreen), findsOneWidget);
      expect(find.text('2026년 7월 10일 금요일'), findsOneWidget);
    });

    testWidgets('오늘 이후 날짜는 글을 열지 않고 안내한다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryScreen(
            store: _MemoryStore(),
            today: DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryEntryScreen), findsNothing);
      expect(
        find.text('오늘 이후 날짜에는 다이어리를 쓸 수 없어요.'),
        findsOneWidget,
      );
    });
  });

  group('작성 (2739:39308)', () {
    testWidgets('시안 좌표를 지킨다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEntryScreen(
            entry: DiaryEntry(date: DateTime(2026, 7, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      _expectAt(tester, '사진칸', find.byType(DiaryPhotoBox), 46, 144.74);
      // 3496:10624 / 10625 / 10621 — 읽기 화면 제목·본문·밑줄.
      expect(tester.getRect(find.text('제목: ')).center.dy, closeTo(434.9, 1));
      expect(tester.getRect(find.byType(TextField).last).top, closeTo(466, 1));
      // 빈 글쓰기 시안(2739:39308)에는 저장하기가 없다.
      expect(find.text('저장하기'), findsNothing);
      _expectAt(tester, '날짜', find.text('2026년 7월 15일 수요일'), 54, 149);
      // 앱바 연필(3345:792) x354 y52.
      final edit = tester.getRect(
        find.byKey(const ValueKey('diary-appbar-edit')),
      );
      expect(edit.left, closeTo(354, 1));
      expect(edit.top, closeTo(46, 1));
      final glyph = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('diary-appbar-edit')),
          matching: find.byType(SvgPicture),
        ),
      );
      expect(glyph.left, closeTo(354, 1));
      expect(glyph.top, closeTo(52, 1));
    });

    testWidgets('가장 긴 날짜도 세로 구분선을 넘지 않는다', (tester) async {
      _setUpView(tester);
      // 기기 글꼴이 3% 넓게 측정되는 경우까지 본다.
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.03)),
            child: DiaryEntryScreen(
              entry: DiaryEntry(date: DateTime(2026, 12, 30)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final date = tester.getRect(find.text('2026년 12월 30일 수요일'));
      expect(date.left, closeTo(54, 1));
      expect(date.right, lessThanOrEqualTo(212.63 - 4 + 0.01));
    });

    testWidgets('글이 있으면 저장하기(3631:2600)가 본문칸 오른쪽 아래에 뜬다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEntryScreen(
            entry: DiaryEntry(date: DateTime(2026, 7, 15), title: '귀여운 새싹이'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('저장하기')).center.dy,
        closeTo(683 + 5.5, 2),
      );
      expect(tester.getRect(find.text('저장하기')).center.dx, closeTo(320, 2));
    });

    testWidgets('빈 글에 글자를 치면 저장하기가 나타난다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEntryScreen(
            entry: DiaryEntry(date: DateTime(2026, 7, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('저장하기'), findsNothing);
      await tester.enterText(find.byType(TextField).last, '오늘');
      await tester.pump();
      expect(find.text('저장하기'), findsOneWidget);
    });

    testWidgets('빈 글은 사진 추가와 힌트를 보여준다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEntryScreen(
            entry: DiaryEntry(date: DateTime(2026, 7, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('사진 추가하기'), findsOneWidget);
      expect(find.text('다이어리를 기록하세요'), findsOneWidget);
    });

    group('사진칸은 아이콘·문구만 눌린다(배경은 안 눌린다)', () {
      Future<List<int>> pumpBox(WidgetTester tester, {String? url}) async {
        _setUpView(tester);
        final taps = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Stack(
              children: [
                // 작성 화면과 같은 자리(3496:10622).
                Positioned(
                  left: 46,
                  top: 144.74,
                  width: 304,
                  height: 259.58,
                  child: DiaryPhotoBox(
                    photoPath: null,
                    photoUrl: url,
                    onTap: () => taps.add(1),
                  ),
                ),
              ],
            ),
          ),
        );
        return taps;
      }

      testWidgets('빈 칸의 배경 구석을 누르면 사진을 고르지 않는다', (tester) async {
        final taps = await pumpBox(tester);

        await tester.tapAt(const Offset(46 + 20, 144.74 + 230));
        await tester.tapAt(const Offset(46 + 280, 144.74 + 60));

        expect(taps, isEmpty);
      });

      testWidgets('사진 추가 아이콘과 문구를 누르면 사진을 고른다', (tester) async {
        final taps = await pumpBox(tester);

        await tester.tap(find.byType(SvgPicture));
        await tester.tap(find.text('사진 추가하기'));

        expect(taps, hasLength(2));
      });

      testWidgets('사진이 있으면 사진을 눌러 바꿀 수 있다', (tester) async {
        final taps = await pumpBox(tester, url: 'https://example.com/p.jpg');
        await tester.pump();

        await tester.tapAt(const Offset(46 + 152, 144.74 + 150));

        expect(taps, hasLength(1));
      });
    });

    testWidgets('사진칸 테두리는 사진 위에 그린다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 310,
            height: 260,
            child: DiaryPhotoBox(
              photoPath: null,
              photoUrl: 'https://example.com/photo.jpg',
            ),
          ),
        ),
      );

      // 4534:4244 사진 위로 주황 테두리가 보인다. 뒤에 그리면 사진이 덮는다.
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(DiaryPhotoBox),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(box.position, DecorationPosition.foreground);
      expect((box.decoration as BoxDecoration).border!.top.color, kOrangeMain);
    });

    testWidgets('날씨를 고르면 표시가 바뀐다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEntryScreen(
            entry: DiaryEntry(date: DateTime(2026, 7, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('눈'), findsOneWidget);
      expect(find.bySemanticsLabel('소나기'), findsNothing);
      await tester.tap(find.bySemanticsLabel('맑음'));
      await tester.pumpAndSettle();

      final picker = tester.widget<DiaryWeatherPicker>(
        find.byType(DiaryWeatherPicker),
      );
      expect(picker.selected, DiaryWeather.sunny);
    });
  });

  group('읽기 (2739:39860)', () {
    testWidgets('저장한 글이 그대로 뜬다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEntryScreen(
            entry: DiaryEntry(
              date: DateTime(2026, 7, 15),
              title: '귀여운 새싹이',
              body: '윤지는 정말 웃긴 사람이다.',
              weather: DiaryWeather.sunny,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('귀여운 새싹이'), findsOneWidget);
      expect(find.text('윤지는 정말 웃긴 사람이다.'), findsOneWidget);

      // 날씨도 저장된 값으로 뜬다.
      final picker = tester.widget<DiaryWeatherPicker>(
        find.byType(DiaryWeatherPicker),
      );
      expect(picker.selected, DiaryWeather.sunny);
    });

    testWidgets('뒤로 나가도 쓴 글이 저장된다', (tester) async {
      _setUpView(tester);
      final store = _MemoryStore();
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryScreen(store: store, today: DateTime(2026, 7, 15)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '오늘의 제목');
      await tester.pump();

      // 뒤로가기는 PopScope가 가로채 저장한다.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(store.saveCount, 1);
      expect(store.entries.single.title, '오늘의 제목');
    });

    testWidgets('화면 왼쪽 끝을 밀어 나가도 쓴 글이 저장된다 (디자이너 답 13-B)', (tester) async {
      _setUpView(tester);
      final store = _MemoryStore();
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryScreen(store: store, today: DateTime(2026, 7, 15)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '밀어서 나간 글');
      await tester.pump();

      await tester.dragFrom(const Offset(4, 400), const Offset(220, 0));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryEntryScreen), findsNothing);
      expect(store.entries.single.title, '밀어서 나간 글');
    });

    testWidgets('빈 글은 저장하지 않는다', (tester) async {
      _setUpView(tester);
      final store = _MemoryStore();
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryScreen(store: store, today: DateTime(2026, 7, 15)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(store.entries, isEmpty);
    });
  });

  group('DiaryEntry', () {
    test('같은 날인지 시각을 빼고 본다', () {
      expect(
        DiaryEntry.sameDay(DateTime(2026, 7, 15, 9), DateTime(2026, 7, 15, 23)),
        isTrue,
      );
      expect(
        DiaryEntry.sameDay(DateTime(2026, 7, 15), DateTime(2026, 7, 16)),
        isFalse,
      );
    });

    test('저장했다 읽으면 값이 같다', () {
      final entry = DiaryEntry(
        date: DateTime(2026, 7, 15),
        title: '제목',
        body: '본문',
        weather: DiaryWeather.cloudy,
      );
      final back = DiaryEntry.fromJson(entry.toJson())!;
      expect(back.title, '제목');
      expect(back.body, '본문');
      expect(back.weather, DiaryWeather.cloudy);
      expect(DiaryEntry.sameDay(back.date, entry.date), isTrue);
    });
  });

  group('시안 대조에서 놓쳤던 것들', () {
    testWidgets('제목 앞에 "제목: "이 붙는다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEntryScreen(
            entry: DiaryEntry(date: DateTime(2026, 7, 15), title: '귀여운 새싹이'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 시안 2739:39792는 접두사가 힌트가 아니라 실제로 앞에 붙어 있다.
      expect(find.text('제목: '), findsOneWidget);
      expect(find.text('귀여운 새싹이'), findsOneWidget);
    });

    testWidgets('글쓰기는 네비·앞뒤 버튼·상단 연필이 있다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEntryScreen(
            entry: DiaryEntry(date: DateTime(2026, 7, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.bySemanticsLabel('이전 날'), findsOneWidget);
      expect(find.bySemanticsLabel('다음 날'), findsOneWidget);
      expect(find.byKey(const ValueKey('diary-appbar-edit')), findsOneWidget);
      expect(find.bySemanticsLabel('다이어리 쓰기'), findsNothing);
    });

    testWidgets('키보드가 올라와도 하단 네비는 화면 바닥에 그대로 있다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEntryScreen(
            entry: DiaryEntry(date: DateTime(2026, 7, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(AppBottomNav));

      // iPhone 16 Pro 한글 키보드 높이쯤.
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byType(AppBottomNav)), before);
      expect(before.bottom, 874);
    });

    testWidgets('달력은 그 달에 필요한 주만 그린다', (tester) async {
      _setUpView(tester);
      // 2026년 2월은 1일이 일요일이라 딱 네 주다.
      await tester.pumpWidget(
        MaterialApp(home: DiaryScreen(today: DateTime(2026, 2, 15))),
      );
      await tester.pumpAndSettle();

      // 여섯 주를 고정해 그리면 종이(바닥 680) 밖으로 넘친다.
      final cells = tester.widgetList(find.byType(DecoratedBox)).length;
      expect(cells, greaterThan(0));
      expect(find.text('28'), findsOneWidget);
      expect(find.text('29'), findsNothing);
    });
  });
}
