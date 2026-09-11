import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/notification_screen.dart';
import 'package:yeso_plant/services/notification_api.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/notification_tile.dart';

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this.notifications);

  final List<NotificationData> notifications;
  final List<String> markedIds = [];

  @override
  Future<NotificationPage> getNotifications({
    String? cursor,
    bool unreadOnly = false,
    int limit = 20,
  }) async {
    return NotificationPage(
      items: List.of(notifications),
      nextCursor: null,
      hasNext: false,
    );
  }

  @override
  Future<NotificationData> markRead(String notificationId) async {
    markedIds.add(notificationId);
    final index = notifications.indexWhere((item) => item.id == notificationId);
    final updated = notifications[index].copyWith(
      readAt: DateTime.utc(2026, 9, 6, 10),
    );
    notifications[index] = updated;
    return updated;
  }

  @override
  Future<void> markAllRead() async {
    for (var index = 0; index < notifications.length; index++) {
      if (!notifications[index].isRead) {
        notifications[index] = notifications[index].copyWith(
          readAt: DateTime.utc(2026, 9, 6, 10),
        );
      }
    }
  }

  @override
  Future<NotificationDevice> registerDevice({
    required NotificationDevicePlatform platform,
    required String installationId,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeDevice(String deviceId) => throw UnimplementedError();
}

NotificationData _notification({
  required String id,
  DateTime? readAt,
  DateTime? createdAt,
}) => NotificationData(
      id: id,
      plantId: null,
      type: 'WATERING_REMINDER',
      title: id == 'unread' ? '물을 줄 시간이에요' : '진단이 완료됐어요',
      body: '새싹이의 상태를 확인해 주세요.',
      sourceType: null,
      sourceId: null,
      readAt: readAt,
      createdAt: createdAt ?? DateTime.now(),
    );

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeNotificationRepository repository, {
  NotificationSelected? onSelected,
}) async {
  tester.view.physicalSize = AppLayout.referenceViewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationScreen(
        repository: repository,
        onNotificationSelected: onSelected,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('402x874에서 알림 목록과 읽음 상태를 표시한다', (tester) async {
    final repository = _FakeNotificationRepository([
      _notification(id: 'unread'),
      _notification(id: 'read', readAt: DateTime.utc(2026, 9, 6, 9)),
    ]);

    await _pumpScreen(tester, repository);

    expect(find.text('알림'), findsOneWidget);
    expect(find.text('오늘의 알림'), findsOneWidget);
    expect(find.text('물을 줄 시간이에요'), findsOneWidget);
    expect(find.text('진단이 완료됐어요'), findsOneWidget);
    // 시안 3448:113 / 3456:4891: 읽음 알림도 점을 그린다(색만 다르다).
    expect(find.byKey(const Key('notification-dot-unread')), findsOneWidget);
    expect(find.byKey(const Key('notification-dot-read')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('안 읽은 알림을 누르면 읽음 처리 후 선택 콜백을 호출한다', (tester) async {
    final repository = _FakeNotificationRepository([
      _notification(id: 'unread'),
    ]);
    NotificationData? selected;
    await _pumpScreen(
      tester,
      repository,
      onSelected: (value) => selected = value,
    );

    await tester.tap(find.byKey(const Key('notification-unread')));
    await tester.pump();

    expect(repository.markedIds, ['unread']);
    expect(selected?.isRead, isTrue);
    // 읽어도 점은 남고 색만 회색으로 바뀐다.
    final dot = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const Key('notification-dot-unread')),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((dot.decoration as BoxDecoration).color, kNotificationDotRead);
  });

  testWidgets('어제 온 알림은 "지난 알림" 절로 내려간다', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final repository = _FakeNotificationRepository([
      _notification(id: 'unread'),
      _notification(id: 'read', readAt: yesterday, createdAt: yesterday),
    ]);

    await _pumpScreen(tester, repository);

    expect(find.text('오늘의 알림'), findsOneWidget);
    expect(find.text('지난 알림'), findsOneWidget);
    final today = tester.getRect(find.text('오늘의 알림'));
    final past = tester.getRect(find.text('지난 알림'));
    expect(past.top, greaterThan(today.top));
  });

  testWidgets('알림이 없으면 빈 문구만 보여준다', (tester) async {
    final repository = _FakeNotificationRepository([]);
    await _pumpScreen(tester, repository);

    expect(find.text('도착한 알림이 없어요.'), findsOneWidget);
    expect(find.byKey(const Key('notification-list')), findsNothing);
  });
}
