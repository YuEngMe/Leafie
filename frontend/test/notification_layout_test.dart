// 알림 화면(Figma 3448:2) 좌표 회귀 테스트.
// 시안: "오늘의 알림" 3448:49 (x34 y140, Paperlogy 16 w600 #444),
// "지난 알림" 3456:4904 (x34 y413.196),
// 타일 3448:26 (x14 y169 374×58.196, radius 50, 흰 배경 + 그림자 0 0 4 rgba(0,0,0,.18)),
// 제목 3448:28 (x109.293, 16 w500 #1F2E21),
// 점 3448:113 (x355 지름 8.188, 안읽음 #FF5E5E / 읽음 #CCCBCB 3456:4891).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/notification_screen.dart';
import 'package:yeso_plant/services/notification_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/notification_tile.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';

class _StubRepository implements NotificationRepository {
  _StubRepository(this.items);

  final List<NotificationData> items;

  @override
  Future<NotificationPage> getNotifications({
    String? cursor,
    bool unreadOnly = false,
    int limit = 20,
  }) async => NotificationPage(items: items, nextCursor: null, hasNext: false);

  @override
  Future<NotificationData> markRead(String notificationId) async =>
      items.firstWhere((item) => item.id == notificationId);

  @override
  Future<void> markAllRead() async {}

  @override
  Future<NotificationDevice> registerDevice({
    required NotificationDevicePlatform platform,
    required String installationId,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeDevice(String deviceId) => throw UnimplementedError();
}

NotificationData _item({
  required String id,
  required String title,
  required DateTime createdAt,
  DateTime? readAt,
}) => NotificationData(
  id: id,
  plantId: null,
  type: 'WATERING_REMINDER',
  title: title,
  body: '',
  sourceType: null,
  sourceId: null,
  readAt: readAt,
  createdAt: createdAt,
);

Future<void> _pump(WidgetTester tester, List<NotificationData> items) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: NotificationScreen(repository: _StubRepository(items))),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('오늘/지난 두 절과 타일이 시안 좌표에 앉는다', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    final yesterday = today.subtract(const Duration(days: 1));
    await _pump(tester, [
      _item(id: 'a', title: '새싹이는 물이 필요해요', createdAt: today),
      _item(id: 'b', title: '씩씩이는 햇빛이 필요해요', createdAt: today),
      _item(
        id: 'c',
        title: '새싹이의 편지가 도착했어요',
        createdAt: yesterday,
        readAt: yesterday,
      ),
    ]);

    // 절 헤더.
    final todayHeader = tester.getRect(find.text('오늘의 알림'));
    expect(todayHeader.left, closeTo(34, 1));
    expect(todayHeader.top, closeTo(140, 1));
    final headerStyle = tester.widget<Text>(find.text('오늘의 알림')).style!;
    expect(headerStyle.fontSize, 16);
    expect(headerStyle.fontWeight, FontWeight.w600);
    expect(headerStyle.color, kTextDark);

    // 첫 타일: x14 y169 374×58.196.
    final first = tester.getRect(find.byKey(const Key('notification-a')));
    expect(first.left, closeTo(14, 1));
    expect(first.top, closeTo(169, 1));
    expect(first.width, closeTo(374, 1));
    expect(first.height, closeTo(58.196, 1));

    // 두 번째 타일 top 242.196 (간격 15).
    final second = tester.getRect(find.byKey(const Key('notification-b')));
    expect(second.top, closeTo(242.196, 1));

    // "지난 알림" 잉크 top 413.196 — 시안은 오늘 타일 3개지만 여기선 2개라
    // 마지막 오늘 타일 바닥(300.392)에서 40 아래를 확인한다.
    final pastHeader = tester.getRect(find.text('지난 알림'));
    expect(pastHeader.left, closeTo(34, 1));
    expect(pastHeader.top, closeTo(second.bottom + 40, 1));

    // 지난 절 첫 타일은 헤더 잉크에서 29 아래.
    final third = tester.getRect(find.byKey(const Key('notification-c')));
    expect(third.top, closeTo(pastHeader.top + 29, 1));
  });

  testWidgets('타일 제목·점·모양이 시안값과 같다', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    await _pump(tester, [
      _item(id: 'unread', title: '새싹이는 물이 필요해요', createdAt: today),
      _item(
        id: 'read',
        title: '토토의 편지가 도착했어요',
        createdAt: today,
        readAt: today,
      ),
    ]);

    // 제목 x=109.293, 16 w500 #1F2E21.
    final title = tester.getRect(find.text('새싹이는 물이 필요해요'));
    expect(title.left, closeTo(109.293, 1));
    final titleStyle = tester.widget<Text>(find.text('새싹이는 물이 필요해요')).style!;
    expect(titleStyle.fontSize, 16);
    expect(titleStyle.fontWeight, FontWeight.w500);
    expect(titleStyle.color, kNotificationTitleColor);

    // 점: x=355, 지름 8.188, 안읽음/읽음 색 구분.
    for (final entry in {
      'unread': kNotificationDotUnread,
      'read': kNotificationDotRead,
    }.entries) {
      final finder = find.byKey(Key('notification-dot-${entry.key}'));
      final rect = tester.getRect(finder);
      expect(rect.left, closeTo(355, 1), reason: '${entry.key} 점 x');
      expect(rect.width, closeTo(8.188, 1), reason: '${entry.key} 점 지름');
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: finder, matching: find.byType(DecoratedBox)),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, entry.value, reason: '${entry.key} 점 색');
      expect(decoration.shape, BoxShape.circle);
    }

    // 알약 배경: 흰색 + radius 50 + 그림자, 테두리 없음. 읽음/안읽음 동일.
    for (final id in ['unread', 'read']) {
      final tile = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is NotificationTile && widget.notification.id == id,
              ),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = tile.decoration as BoxDecoration;
      expect(decoration.color, kBackgroundWhite, reason: '$id 배경');
      expect(decoration.border, isNull, reason: '$id 테두리 없음');
      expect(decoration.boxShadow!.single.blurRadius, 4);
      expect(decoration.boxShadow!.single.color, const Color(0x2E000000));
      expect(
        decoration.borderRadius,
        BorderRadius.circular(50),
        reason: '$id radius',
      );
    }

    // 캐릭터(몸통+얼굴)가 Material 아이콘을 대체했다. 타일마다 하나.
    expect(find.byType(PlantCharacterArt), findsNWidgets(2));
    expect(find.byIcon(Icons.water_drop_outlined), findsNothing);
  });

  testWidgets('시안에 없는 필터칩·전체읽음·본문·시각을 그리지 않는다', (tester) async {
    final now = DateTime.now();
    await _pump(tester, [
      _item(
        id: 'a',
        title: '새싹이는 물이 필요해요',
        createdAt: DateTime(now.year, now.month, now.day, 9),
      ),
    ]);

    expect(find.text('전체'), findsNothing);
    expect(find.text('안 읽음'), findsNothing);
    expect(find.text('전체 읽음'), findsNothing);
    expect(find.byKey(const Key('notification-read-all')), findsNothing);
  });
}
