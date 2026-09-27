/// Mail is separate from chat messages and notification counts.
class PlantLetter {
  const PlantLetter({
    required this.id,
    required this.recipient,
    required this.sender,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.plantId,
    String? preview,
    this.contentLoaded = true,
  }) : preview = preview ?? body;
  final String id;
  final String? plantId;
  final String recipient;
  final String sender;
  final String body;
  final String preview;
  final DateTime createdAt;
  final bool isRead;
  final bool contentLoaded;
}

/// Integration boundary for the authenticated plant mailbox API.
abstract interface class PlantLetterRepository {
  Future<List<PlantLetter>> listLetters(String plantId);
  Future<PlantLetter> getLetter(String plantId, String letterId);
  Future<void> markRead(String plantId, String letterId);
  Future<void> deleteLetter(String plantId, String letterId);

  /// 이 식물의 안 읽은 편지 수. 홈 우편함 배지에 쓴다.
  Future<int> unreadCount(String plantId);
}
