import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/calendar_screen.dart';
import 'package:yeso_plant/services/calendar_api.dart';

void main() {
  testWidgets('월간 일정과 선택한 날짜의 할 일을 보여준다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeCalendarRepository(
      items: [
        _item(
          id: 'watering-1',
          date: DateTime(2026, 7, 15),
          careType: 'WATERING',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          plantId: 'plant-1',
          plantName: '새싹이',
          repository: repository,
          today: DateTime(2026, 7, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('캘린더'), findsOneWidget);
    expect(find.text('2026. 7'), findsOneWidget);
    expect(find.text('오늘 할 일'), findsOneWidget);
    expect(find.text('물 주기'), findsOneWidget);
    expect(repository.requests, [
      _CalendarRequest(
        plantId: 'plant-1',
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 31),
      ),
    ]);
  });

  testWidgets('주간 모드로 바꾸면 선택 날짜가 속한 일주일을 조회한다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeCalendarRepository(items: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          plantId: 'plant-1',
          repository: repository,
          today: DateTime(2026, 7, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calendar-mode-week')));
    await tester.pumpAndSettle();

    expect(repository.requests, hasLength(2));
    expect(
      repository.requests.last,
      _CalendarRequest(
        plantId: 'plant-1',
        from: DateTime(2026, 7, 12),
        to: DateTime(2026, 7, 18),
      ),
    );
    expect(find.text('2026. 7.15 수'), findsNothing);
    expect(find.text('등록된 일정이 없어요.'), findsOneWidget);
  });

  testWidgets('완료 가능한 일정을 누르면 완료 API를 호출하고 다시 조회한다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeCalendarRepository(
      items: [
        _item(id: 'repot-1', date: DateTime(2026, 7, 15), careType: 'REPOTTING'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          plantId: 'plant-1',
          repository: repository,
          today: DateTime(2026, 7, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calendar-complete-repot-1')));
    await tester.pumpAndSettle();

    expect(repository.completedEventIds, ['repot-1']);
    expect(repository.completedOn, [DateTime(2026, 7, 15)]);
    expect(repository.requests, hasLength(2));
  });

  testWidgets('일정 추가 시트에서 비료 주기를 골라 등록한다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeCalendarRepository(items: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          plantId: 'plant-1',
          repository: repository,
          today: DateTime(2026, 7, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calendar-add')));
    await tester.pumpAndSettle();
    // 시안 3429:1163에는 제목이 없고 `확인` 버튼과 3열 휠만 있다.
    expect(find.text('일정 추가'), findsNothing);
    expect(find.text('확인'), findsOneWidget);
    expect(find.text('2026년'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-type-FERTILIZING')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('calendar-new-event-confirm')));
    await tester.pumpAndSettle();

    expect(repository.createdEvents, [
      _CreatedEvent(
        plantId: 'plant-1',
        careType: 'FERTILIZING',
        dueDate: DateTime(2026, 7, 15),
      ),
    ]);
    expect(repository.requests, hasLength(2));
  });
}

void _setIPhone16ProViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.reset);
}

CalendarItemData _item({
  required String id,
  required DateTime date,
  required String careType,
}) => CalendarItemData(
  id: id,
  date: date,
  careType: careType,
  status: 'SCHEDULED',
  viewStatus: 'UPCOMING',
  source: 'USER',
  completable: true,
);

class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository({required this.items});

  final List<CalendarItemData> items;
  final List<_CalendarRequest> requests = [];
  final List<String> completedEventIds = [];
  final List<DateTime?> completedOn = [];
  final List<_CreatedEvent> createdEvents = [];

  @override
  Future<List<CalendarItemData>> listCalendar(
    String plantId,
    DateTime from,
    DateTime to, {
    Iterable<String>? types,
  }) async {
    requests.add(_CalendarRequest(plantId: plantId, from: from, to: to));
    return items
        .where((item) => !item.date.isBefore(from) && !item.date.isAfter(to))
        .toList(growable: false);
  }

  @override
  Future<void> completeEvent(String eventId, {DateTime? performedOn}) async {
    completedEventIds.add(eventId);
    completedOn.add(performedOn);
  }

  @override
  Future<void> createEvent(
    String plantId, {
    required String careType,
    required DateTime dueDate,
  }) async {
    createdEvents.add(
      _CreatedEvent(plantId: plantId, careType: careType, dueDate: dueDate),
    );
  }
}

class _CalendarRequest {
  const _CalendarRequest({
    required this.plantId,
    required this.from,
    required this.to,
  });

  final String plantId;
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is _CalendarRequest &&
      plantId == other.plantId &&
      from == other.from &&
      to == other.to;

  @override
  int get hashCode => Object.hash(plantId, from, to);
}

class _CreatedEvent {
  const _CreatedEvent({
    required this.plantId,
    required this.careType,
    required this.dueDate,
  });

  final String plantId;
  final String careType;
  final DateTime dueDate;

  @override
  bool operator ==(Object other) =>
      other is _CreatedEvent &&
      plantId == other.plantId &&
      careType == other.careType &&
      dueDate == other.dueDate;

  @override
  int get hashCode => Object.hash(plantId, careType, dueDate);
}
