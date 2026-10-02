import 'package:yeso_plant/services/notification_api.dart';

/// 알림을 눌렀을 때 열 화면. 서버 `source_type`별로 정해진다.
sealed class NotificationTarget {
  const NotificationTarget();
}

/// 편지 알림(LETTER) → 그 식물의 우편함.
final class MailboxTarget extends NotificationTarget {
  const MailboxTarget(this.plantId);
  final String plantId;
}

/// 진단 완료 알림(DIAGNOSIS) → 진단 상세.
final class DiagnosisTarget extends NotificationTarget {
  const DiagnosisTarget(this.diagnosisId);
  final String diagnosisId;
}

/// 관리 일정 알림(CARE_EVENT) → 그 식물의 캘린더.
final class CalendarTarget extends NotificationTarget {
  const CalendarTarget(this.plantId);
  final String plantId;
}

/// 센서 알림(SENSOR_EVENT, #124) → 그 식물의 방(게이지 펼침).
final class PlantHomeTarget extends NotificationTarget {
  const PlantHomeTarget(this.plantId);
  final String plantId;
}

/// 이동할 곳을 알 수 없으면(모르는 종류, 식물·원본 id 누락) null이다.
/// 이때는 읽음 처리만 하고 알림 목록에 머문다.
NotificationTarget? notificationTargetOf(NotificationData notification) {
  final plantId = notification.plantId;
  final sourceId = notification.sourceId;
  return switch (notification.sourceType) {
    'LETTER' when plantId != null => MailboxTarget(plantId),
    'DIAGNOSIS' when sourceId != null => DiagnosisTarget(sourceId),
    'CARE_EVENT' when plantId != null => CalendarTarget(plantId),
    'SENSOR_EVENT' when plantId != null => PlantHomeTarget(plantId),
    _ => null,
  };
}
