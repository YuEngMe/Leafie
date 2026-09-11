import 'package:yeso_plant/services/leafie_api_client.dart';

class HomeApi {
  HomeApi({LeafieApiClient? client}) : _client = client ?? LeafieApiClient();

  final LeafieApiClient _client;

  Future<HomeDashboardData> fetchHome({String? plantId}) async {
    final response = await _client.get(
      '/home',
      queryParameters: {'plant_id': ?plantId},
    );
    try {
      return HomeDashboardData.fromJson(response);
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '홈 정보를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.plant,
    required this.character,
    required this.todayEvents,
    required this.unreadNotificationCount,
  });

  factory HomeDashboardData.fromJson(Map<String, dynamic> json) {
    final plantJson = json['plant'];
    final characterJson = json['character'];
    final eventsJson = json['today_events'];
    final unreadCount = json['unread_notification_count'];
    if (plantJson != null && plantJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid home plant');
    }
    if (characterJson != null && characterJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid home character');
    }
    if (eventsJson is! List || unreadCount is! int) {
      throw const FormatException('Invalid home payload');
    }

    return HomeDashboardData(
      plant: plantJson == null ? null : HomePlantData.fromJson(plantJson),
      character: characterJson == null
          ? null
          : HomeCharacterData.fromJson(characterJson),
      todayEvents: List.unmodifiable(
        eventsJson.map((event) {
          if (event is! Map<String, dynamic>) {
            throw const FormatException('Invalid home event');
          }
          return HomeTodayEvent.fromJson(event);
        }),
      ),
      unreadNotificationCount: unreadCount,
    );
  }

  final HomePlantData? plant;
  final HomeCharacterData? character;
  final List<HomeTodayEvent> todayEvents;
  final int unreadNotificationCount;
}

class HomePlantData {
  const HomePlantData({
    required this.id,
    required this.nickname,
    required this.daysTogether,
    required this.primaryPhotoUrl,
  });

  factory HomePlantData.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nickname = json['nickname'];
    final daysTogether = json['days_together'];
    final primaryPhotoUrl = json['primary_photo_url'];
    if (id is! String ||
        nickname is! String ||
        nickname.isEmpty ||
        daysTogether is! int ||
        daysTogether < 0 ||
        (primaryPhotoUrl != null && primaryPhotoUrl is! String)) {
      throw const FormatException('Invalid home plant');
    }
    return HomePlantData(
      id: id,
      nickname: nickname,
      daysTogether: daysTogether,
      primaryPhotoUrl: primaryPhotoUrl as String?,
    );
  }

  final String id;
  final String nickname;
  final int daysTogether;
  final String? primaryPhotoUrl;
}

class HomeCharacterData {
  const HomeCharacterData({
    required this.personalityType,
    required this.dialogue,
  });

  factory HomeCharacterData.fromJson(Map<String, dynamic> json) {
    final personalityType = json['personality_type'];
    final dialogue = json['dialogue'];
    if (personalityType is! String ||
        personalityType.isEmpty ||
        (dialogue != null && dialogue is! String)) {
      throw const FormatException('Invalid home character');
    }
    return HomeCharacterData(
      personalityType: personalityType,
      dialogue: dialogue as String?,
    );
  }

  final String personalityType;
  final String? dialogue;
}

class HomeTodayEvent {
  const HomeTodayEvent({required this.type, required this.completable});

  factory HomeTodayEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final completable = json['completable'];
    if (type is! String || type.isEmpty || completable is! bool) {
      throw const FormatException('Invalid home event');
    }
    return HomeTodayEvent(type: type, completable: completable);
  }

  final String type;
  final bool completable;
}
