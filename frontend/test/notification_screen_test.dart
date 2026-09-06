import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/notification_screen.dart';
import 'package:yeso_plant/services/notification_api.dart';
import 'package:yeso_plant/theme/app_layout.dart';

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this.notifications);

  final List<NotificationData> notifications;
  bool unreadOnly = false;
  int markAllCount = 0;
  final List<String> markedIds = [];

  @override
  Future<NotificationPage> getNotifications({
    String? cursor,
    bool unreadOnly = false,
    int limit = 20,
  }) async {
    this.unreadOnly = unreadOnly;
    return NotificationPage(
      items: notifications
          .where((notification) => !unreadOnly || !notification.isRead)
          .toList(),
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
    markAllCount++;
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

NotificationData _notification({required String id, DateTime? readAt}) =>
    NotificationData(
      id: id,
      plantId: null,
      type: 'WATERING_REMINDER',
      title: id == 'unread' ? '물을 줄 시간이에요' : '진단이 완료됐어요',
      body: '새싹이의 상태를 확인해 주세요.',
      sourceType: null,
      sourceId: null,
      readAt: readAt,
      createdAt: DateTime.now(),
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
    expect(find.text('물을 줄 시간이에요'), findsOneWidget);
    expect(find.text('진단이 완료됐어요'), findsOneWidget);
    expect(find.byKey(const Key('unread-unread')), findsOneWidget);
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
    expect(find.byKey(const Key('unread-unread')), findsNothing);
  });

  testWidgets('전체 읽음과 안 읽음 필터를 서버 계약으로 호출한다', (tester) async {
    final repository = _FakeNotificationRepository([
      _notification(id: 'unread'),
    ]);
    await _pumpScreen(tester, repository);

    await tester.tap(find.byKey(const Key('notification-read-all')));
    await tester.pump();
    expect(repository.markAllCount, 1);

    await tester.tap(find.text('안 읽음'));
    await tester.pump();
    expect(repository.unreadOnly, isTrue);
    expect(find.text('읽지 않은 알림이 없어요.'), findsOneWidget);
  });
}
