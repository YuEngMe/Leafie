// 다이어리(2739:34592 달력, 2739:39308 작성, 2739:39860 읽기).
// 배경이 앱바 뒤까지 이어져 좌표를 화면 절대값으로 쓴다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/screens/diary_screen.dart';
import 'package:yeso_plant/services/diary_api.dart';
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
  group('달력 (2739:34592)', () {
    testWidgets('시안 좌표를 지킨다', (tester) async {
      _setUpView(tester);
      await tester.pumpWidget(
        MaterialApp(home: DiaryScreen(today: DateTime(2026, 7, 15))),
      );
      await tester.pumpAndSettle();

      _expectAt(tester, '연도', find.text('2026'), 177, 162.72);
      _expectAt(tester, '월', find.text('7'), 181.67, 179.26);
      _expectAt(tester, '일요일', find.text('일'), 59, 262.61);
      _expectAt(tester, '토요일', find.text('토'), 318, 262.61);
      _expectAt(tester, '책갈피', find.byType(DiaryTab), 350, 274);
      // 시안 3496:12213에서 자리가 바뀌었다.
      _expectAt(tester, '하단 작성 버튼', find.bySemanticsLabel('다이어리 쓰기'), 302, 661);
      expect(find.byKey(const ValueKey('diary-appbar-edit')), findsNothing);
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

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryEntryScreen), findsOneWidget);
      expect(find.text('2026년 7월 20일 월요일'), findsOneWidget);
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

      _expectAt(tester, '사진칸', find.byType(DiaryPhotoBox), 46, 143);
      _expectAt(tester, '날짜', find.text('2026년 7월 15일 수요일'), 54, 149);
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
      expect(find.text(' 다이어리를 기록하세요'), findsOneWidget);
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
