import 'package:shared_preferences/shared_preferences.dart';

/// 홈 대사 큐(#123)에서 이미 보여 준 이벤트 id를 기기에 남긴다.
///
/// 서버는 소비 여부를 기록하지 않고, 같은 날 홈을 다시 불러오면 같은 이벤트를
/// 다시 준다. 앱이 보여 준 순간 id를 저장해 다시 띄우지 않는다. event_id는
/// 서버가 만든 고유값이라 계정·식물로 나누지 않고 한 목록에 최근 것만 둔다.
class HomeDialogueSeenStore {
  const HomeDialogueSeenStore();

  static const _key = 'home_seen_dialogue_events_v1';

  /// 큐는 하루치라 오래된 id는 필요 없다. 최근 것만 남긴다.
  static const _limit = 300;

  Future<Set<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const []).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> markSeen(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = [...?prefs.getStringList(_key)]
        ..remove(eventId)
        ..add(eventId);
      final trimmed = ids.length > _limit
          ? ids.sublist(ids.length - _limit)
          : ids;
      await prefs.setStringList(_key, trimmed);
    } catch (_) {
      // 저장에 실패하면 다음에 한 번 더 보일 뿐이라 화면을 막지 않는다.
    }
  }
}
