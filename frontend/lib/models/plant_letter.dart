/// Mail is separate from chat messages and notification counts.
class PlantLetter {
  const PlantLetter({
    required this.id,
    required this.recipient,
    required this.sender,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });
  final String id;
  final String recipient;
  final String sender;
  final String body;
  final DateTime createdAt;
  final bool isRead;
}

/// Integration boundary until the backend supplies a dedicated mail contract.
abstract interface class PlantLetterRepository {
  Future<List<PlantLetter>> listLetters(String plantId);
  Future<void> markRead(String plantId, String letterId);
}
