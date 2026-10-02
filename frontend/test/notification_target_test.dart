import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/notification_api.dart';
import 'package:yeso_plant/services/notification_target.dart';

NotificationData _notification({
  String? sourceType,
  String? sourceId = 'source-1',
  String? plantId = 'plant-1',
}) => NotificationData(
  id: 'n-1',
  plantId: plantId,
  type: 'ANY',
  title: '제목',
  body: '본문',
  sourceType: sourceType,
  sourceId: sourceId,
  readAt: null,
  createdAt: DateTime(2026, 9, 25),
);

void main() {
  test('편지 알림은 그 식물의 우편함으로 간다', () {
    final target = notificationTargetOf(_notification(sourceType: 'LETTER'));
    expect(target, isA<MailboxTarget>());
    expect((target! as MailboxTarget).plantId, 'plant-1');
  });

  test('진단 알림은 원본 id의 진단 상세로 간다', () {
    final target = notificationTargetOf(_notification(sourceType: 'DIAGNOSIS'));
    expect(target, isA<DiagnosisTarget>());
    expect((target! as DiagnosisTarget).diagnosisId, 'source-1');
  });

  test('관리 일정 알림은 그 식물의 캘린더로 간다', () {
    final target = notificationTargetOf(
      _notification(sourceType: 'CARE_EVENT'),
    );
    expect(target, isA<CalendarTarget>());
    expect((target! as CalendarTarget).plantId, 'plant-1');
  });

  test('센서 알림은 그 식물의 방으로 간다', () {
    final target = notificationTargetOf(
      _notification(sourceType: 'SENSOR_EVENT'),
    );
    expect(target, isA<PlantHomeTarget>());
    expect((target! as PlantHomeTarget).plantId, 'plant-1');
  });

  test('모르는 종류이거나 필요한 id가 없으면 이동하지 않는다', () {
    expect(notificationTargetOf(_notification(sourceType: null)), isNull);
    expect(notificationTargetOf(_notification(sourceType: 'UNKNOWN')), isNull);
    expect(
      notificationTargetOf(_notification(sourceType: 'LETTER', plantId: null)),
      isNull,
    );
    expect(
      notificationTargetOf(
        _notification(sourceType: 'DIAGNOSIS', sourceId: null),
      ),
      isNull,
    );
  });
}
