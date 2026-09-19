import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/screens/diary_screen.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/services/diary_api.dart';
import 'package:yeso_plant/services/home_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/widgets/diary_components.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/main_tab_shell.dart';

Finder _navIcon(FigmaNavIcon icon) => find.byWidgetPredicate(
  (widget) => widget is FigmaBottomNavIcon && widget.icon == icon,
);

void _setUpView(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.reset);
}

class _ReliableStore implements DiaryStore {
  final entries = <DiaryEntry>[];
  final savedDates = <DateTime>[];
  int loadMonthCount = 0;
  int loadDayCount = 0;
  int loadDayFailuresRemaining = 0;
  int deleteCount = 0;
  int deleteFailuresRemaining = 0;
  int failuresRemaining = 0;
  Object failure = const LeafieApiException(
    code: 'SAVE_FAILED',
    message: '저장하지 못했어요.',
    statusCode: 503,
  );
  Completer<void>? pendingSave;

  @override
  Future<List<DiaryEntry>> loadMonth(DateTime month) async {
    loadMonthCount++;
    return entries
        .where(
          (entry) =>
              entry.date.year == month.year && entry.date.month == month.month,
        )
        .toList();
  }

  @override
  Future<DiaryEntry?> loadDay(DateTime date) async {
    loadDayCount++;
    if (loadDayFailuresRemaining > 0) {
      loadDayFailuresRemaining--;
      throw failure;
    }
    for (final entry in entries) {
      if (DiaryEntry.sameDay(entry.date, date)) return entry;
    }
    return null;
  }

  @override
  Future<void> save(DiaryEntry entry) async {
    savedDates.add(entry.date);
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw failure;
    }
    final pending = pendingSave;
    if (pending != null) await pending.future;
    entries
      ..removeWhere((saved) => DiaryEntry.sameDay(saved.date, entry.date))
      ..add(entry);
  }

  @override
  Future<void> delete(DateTime date) async {
    deleteCount++;
    if (deleteFailuresRemaining > 0) {
      deleteFailuresRemaining--;
      throw failure;
    }
    entries.removeWhere((entry) => DiaryEntry.sameDay(entry.date, date));
  }
}

void main() {
  testWidgets('탭 안의 작성 로드 오류는 하단 네비 위에 표시하고 편집기를 열지 않는다', (tester) async {
    _setUpView(tester);
    final store = _ReliableStore()
      ..loadDayFailuresRemaining = 1
      ..failure = const LeafieApiException(
        code: 'LOAD_FAILED',
        message: '다이어리를 불러오지 못했어요.',
        statusCode: 503,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabShell(
          home: const SizedBox.expand(),
          diaryBuilder: (_) => DiaryScreen(
            store: store,
            today: DateTime(2026, 7, 15),
            showBottomNav: false,
          ),
          calendarBuilder: (_) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_navIcon(FigmaNavIcon.diary));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('다이어리 쓰기'));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryEntryScreen), findsNothing);
    final errorText = find.textContaining('다이어리를 불러오지 못했어요.');
    expect(errorText, findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect((snackBar.margin! as EdgeInsets).bottom, greaterThan(79));
    final errorTextRect = tester.getRect(errorText);
    final bottomNavRect = tester.getRect(find.byType(AppBottomNav));
    expect(errorTextRect.bottom, lessThan(bottomNavRect.top));
  });

  testWidgets('홈의 diary는 식물별 scope를 쓰고 같은 식물 탭 상태는 유지한다', (tester) async {
    _setUpView(tester);
    final repository = _PlantRepository([
      _managedPlant('plant-a', '첫째', selected: true),
      _managedPlant('plant-b', '둘째'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          plant: const HomePlant(
            id: 'plant-a',
            name: '첫째',
            startedOn: null,
            personalityType: null,
          ),
          period: HomeTimePeriod.day,
          plantRepository: repository,
          loadHomeForPlant: (plantId) async => HomeDashboardData(
            plant: HomePlantData(
              id: plantId!,
              nickname: plantId == 'plant-b' ? '둘째' : '첫째',
              personalityType: 'OUTGOING',
              colorId: 'green',
              hairId: 'hair_sprout',
              startedOn: '2026-09-15',
              daysTogether: 3,
              primaryPhotoUrl: null,
            ),
            room: const HomeRoomData(
              backgroundPhase: 'DAY',
              dialogueKey: 'NORMAL',
              dialogue: null,
            ),
            todayEvents: const [],
            unreadLetterCount: 0,
            unreadNotificationCount: 0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(_navIcon(FigmaNavIcon.diary));
    await tester.pumpAndSettle();
    var diary = tester.widget<DiaryScreen>(find.byType(DiaryScreen));
    final plantAState = tester.state(find.byType(DiaryScreen));
    expect(diary.plantId, 'plant-a');

    final initialMonth = tester
        .widget<DiaryCalendar>(find.byType(DiaryCalendar))
        .month;
    await tester.tap(find.bySemanticsLabel('다음 달'));
    await tester.pumpAndSettle();
    final nextMonth = DateTime(initialMonth.year, initialMonth.month + 1);
    expect(
      tester.widget<DiaryCalendar>(find.byType(DiaryCalendar)).month,
      nextMonth,
    );
    await tester.tap(_navIcon(FigmaNavIcon.home));
    await tester.pumpAndSettle();
    await tester.tap(_navIcon(FigmaNavIcon.diary));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(DiaryScreen)), same(plantAState));
    expect(
      tester.widget<DiaryCalendar>(find.byType(DiaryCalendar)).month,
      nextMonth,
    );

    await tester.tap(_navIcon(FigmaNavIcon.home));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-next-plant')));
    await tester.pumpAndSettle();
    await tester.tap(_navIcon(FigmaNavIcon.diary));
    await tester.pumpAndSettle();
    diary = tester.widget<DiaryScreen>(find.byType(DiaryScreen));
    expect(repository.selectedIds, ['plant-b']);
    expect(diary.plantId, 'plant-b');
    expect(tester.state(find.byType(DiaryScreen)), isNot(same(plantAState)));
    final now = DateTime.now();
    expect(
      tester.widget<DiaryCalendar>(find.byType(DiaryCalendar)).month,
      DateTime(now.year, now.month),
    );
  });

  testWidgets('식물이 없는 홈 diary는 전역 선택 식물을 다시 조회하지 않는다', (tester) async {
    _setUpView(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          plant: HomePlant(
            id: null,
            name: '없음',
            startedOn: null,
            personalityType: null,
          ),
          period: HomeTimePeriod.day,
        ),
      ),
    );
    await tester.tap(_navIcon(FigmaNavIcon.diary));
    await tester.pumpAndSettle();
    final diary = tester.widget<DiaryScreen>(find.byType(DiaryScreen));
    expect(diary.plantId, isNull);
    expect(diary.resolvePlantIdIfMissing, isFalse);
  });

  testWidgets('저장 실패는 초안을 보존하고 같은 화면에서 재시도한다', (tester) async {
    _setUpView(tester);
    final store = _ReliableStore()..failuresRemaining = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(store: store, today: DateTime(2026, 7, 15)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '보존할 제목');
    await tester.enterText(find.byType(TextField).last, '보존할 본문');
    await tester.tap(find.bySemanticsLabel('맑음'));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(DiaryEntryScreen), findsOneWidget);
    expect(find.text('보존할 제목'), findsOneWidget);
    expect(find.text('보존할 본문'), findsOneWidget);
    expect(find.textContaining('다시 시도'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEntryScreen), findsNothing);
    expect(store.savedDates, hasLength(2));
    expect(store.entries.single.title, '보존할 제목');
    expect(store.entries.single.body, '보존할 본문');
    expect(store.entries.single.weather, DiaryWeather.sunny);
  });

  testWidgets('지연 저장 중 이중 탭과 뒤로가기는 요청을 늘리거나 pop하지 않는다', (tester) async {
    _setUpView(tester);
    final save = Completer<void>();
    final store = _ReliableStore()..pendingSave = save;
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(store: store, today: DateTime(2026, 7, 15)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '한 번만');

    final saveButton = find.byKey(const ValueKey('diary-appbar-edit'));
    await tester.tap(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(store.savedDates, hasLength(1));
    expect(find.byType(DiaryEntryScreen), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .every((field) => field.readOnly),
      isTrue,
    );
    save.complete();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEntryScreen), findsNothing);
  });

  testWidgets('다음 날 이동 실패는 원래 날짜와 초안을 보존하고 재시도한다', (tester) async {
    _setUpView(tester);
    final store = _ReliableStore()..failuresRemaining = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryEntryScreen(
          entry: DiaryEntry(date: DateTime(2026, 7, 15)),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '이동 전 초안');

    await tester.tap(find.bySemanticsLabel('다음 날'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 7월 15일 수요일'), findsOneWidget);
    expect(find.text('이동 전 초안'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('다음 날'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 7월 16일 목요일'), findsOneWidget);
    expect(store.savedDates, hasLength(2));
    expect(store.savedDates.every((date) => date.day == 15), isTrue);
  });

  testWidgets('새 빈 글을 나갈 때 DELETE하지 않는다', (tester) async {
    _setUpView(tester);
    final store = _ReliableStore();
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
    expect(store.deleteCount, 0);
    expect(find.byType(DiaryEntryScreen), findsNothing);
  });

  testWidgets('날짜를 이동해도 원래 부모 route가 마지막 close 후 목록을 갱신한다', (tester) async {
    _setUpView(tester);
    final store = _ReliableStore();
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(store: store, today: DateTime(2026, 7, 15)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '15일');
    await tester.tap(find.bySemanticsLabel('다음 날'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '16일');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(DiaryScreen), findsOneWidget);
    expect(
      store.entries.map((entry) => entry.title),
      containsAll(['15일', '16일']),
    );
    expect(store.loadMonthCount, greaterThanOrEqualTo(2));
  });

  testWidgets('비 API 저장 오류도 표시하고 초안을 유지한다', (tester) async {
    _setUpView(tester);
    final store = _ReliableStore()
      ..failuresRemaining = 1
      ..failure = Exception('filesystem failed');
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryEntryScreen(
          entry: DiaryEntry(date: DateTime(2026, 7, 15)),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '사라지면 안 됨');
    await tester.tap(find.byKey(const ValueKey('diary-appbar-edit')));
    await tester.pumpAndSettle();

    expect(find.text('사라지면 안 됨'), findsOneWidget);
    expect(find.textContaining('다시 시도'), findsOneWidget);
  });

  testWidgets('저장 성공 뒤 다음 날 로드 실패를 재시도해도 다시 저장하지 않는다', (tester) async {
    _setUpView(tester);
    final store = _NextDayFailureStore();
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryEntryScreen(
          entry: DiaryEntry(date: DateTime(2026, 7, 15)),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '한 번 저장');

    await tester.tap(find.bySemanticsLabel('다음 날'));
    await tester.pumpAndSettle();
    expect(store.savedDates, hasLength(1));
    expect(find.text('2026년 7월 15일 수요일'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('다음 날'));
    await tester.pumpAndSettle();
    expect(store.savedDates, hasLength(1));
    expect(find.text('2026년 7월 16일 목요일'), findsOneWidget);
  });

  testWidgets('선택한 사진도 저장 실패 뒤 그대로 남아 재시도할 수 있다', (tester) async {
    _setUpView(tester);
    final store = _ReliableStore()..failuresRemaining = 1;
    final photoPath = File('assets/images/diary_background.png').absolute.path;
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryEntryScreen(
          entry: DiaryEntry(date: DateTime(2026, 7, 15)),
          store: store,
          imagePicker: _ImmediatePicker(photoPath),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DiaryPhotoBox));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '사진 초안');
    await tester.tap(find.bySemanticsLabel('맑음'));
    await tester.tap(find.byKey(const ValueKey('diary-appbar-edit')));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryEntryScreen), findsOneWidget);
    expect(
      tester.widget<DiaryPhotoBox>(find.byType(DiaryPhotoBox)).photoPath,
      photoPath,
    );

    await tester.tap(find.byKey(const ValueKey('diary-appbar-edit')));
    await tester.pumpAndSettle();
    expect(store.savedDates, hasLength(2));
    expect(store.entries.single.title, '사진 초안');
    expect(store.entries.single.weather, DiaryWeather.sunny);
    expect(store.entries.single.photoPath, photoPath);
  });

  testWidgets('기존 글 삭제 실패도 editor를 유지하고 재시도 후에만 닫는다', (tester) async {
    _setUpView(tester);
    final store = _ReliableStore()..deleteFailuresRemaining = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryEntryScreen(
          entry: DiaryEntry(date: DateTime(2026, 7, 15), body: '기존 글'),
          entryExists: true,
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEntryScreen), findsOneWidget);
    expect(store.deleteCount, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEntryScreen), findsNothing);
    expect(store.deleteCount, 2);
  });

  testWidgets('홈 마이 캘린더 이동도 저장 실패 시 현재 editor에 남는다', (tester) async {
    _setUpView(tester);
    for (final tab in [
      FigmaNavIcon.home,
      FigmaNavIcon.my,
      FigmaNavIcon.calendar,
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final store = _ReliableStore()..failuresRemaining = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEntryScreen(
            key: ValueKey(tab),
            entry: DiaryEntry(date: DateTime(2026, 7, 15)),
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '이동 전 초안');
      await tester.tap(_navIcon(tab));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryEntryScreen), findsOneWidget, reason: tab.label);
      expect(find.text('이동 전 초안'), findsOneWidget, reason: tab.label);
      expect(store.savedDates, hasLength(1), reason: tab.label);
    }
  });
}

ManagedPlant _managedPlant(
  String id,
  String nickname, {
  bool selected = false,
}) => ManagedPlant(
  id: id,
  nickname: nickname,
  speciesReferenceId: 'species-$id',
  speciesDisplayName: '몬스테라',
  primaryPhotoUrl: null,
  personalityType: 'OUTGOING',
  colorId: 'color_orange_01',
  hairId: 'hair_sprout',
  startedOn: DateTime.now()
      .toUtc()
      .add(const Duration(hours: 9))
      .subtract(const Duration(days: 3)),
  placeName: '거실',
  isSelected: selected,
);

class _PlantRepository implements PlantManagementRepository {
  _PlantRepository(this.plants);

  List<ManagedPlant> plants;
  final selectedIds = <String?>[];

  @override
  Future<List<ManagedPlant>> listPlants() async => plants;

  @override
  Future<ManagedPlant> getPlant(String plantId) async =>
      plants.firstWhere((plant) => plant.id == plantId);

  @override
  Future<String?> selectPlant(String? plantId) async {
    selectedIds.add(plantId);
    plants = [
      for (final plant in plants)
        plant.copyWith(isSelected: plant.id == plantId),
    ];
    return plantId;
  }

  @override
  Future<void> deletePlant(String plantId) async {}

  @override
  Future<ManagedPlant> updateAppearance(
    String plantId, {
    String? colorId,
    String? hairId,
  }) => throw UnimplementedError();

  @override
  Future<ManagedPlant> updatePlant(
    String plantId, {
    String? nickname,
    String? placeName,
  }) => throw UnimplementedError();
}

class _NextDayFailureStore extends _ReliableStore {
  bool failNextLoad = true;

  @override
  Future<DiaryEntry?> loadDay(DateTime date) async {
    if (date.day == 16 && failNextLoad) {
      failNextLoad = false;
      throw Exception('load failed');
    }
    return super.loadDay(date);
  }
}

class _ImmediatePicker extends ImagePicker {
  _ImmediatePicker(this.path);

  final String path;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile(path);
}
