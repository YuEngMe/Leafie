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
    required this.room,
    required this.todayEvents,
    required this.unreadLetterCount,
    required this.unreadNotificationCount,
  });

  factory HomeDashboardData.fromJson(Map<String, dynamic> json) {
    final plantJson = json['plant'];
    final roomJson = json['room'];
    final eventsJson = json['today_events'];
    final unreadLetters = json['unread_letter_count'];
    final unreadCount = json['unread_notification_count'];
    if (plantJson != null && plantJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid home plant');
    }
    if (roomJson != null && roomJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid home room');
    }
    if (eventsJson is! List ||
        unreadLetters is! int ||
        unreadCount is! int) {
      throw const FormatException('Invalid home payload');
    }

    return HomeDashboardData(
      plant: plantJson == null ? null : HomePlantData.fromJson(plantJson),
      room: roomJson == null ? null : HomeRoomData.fromJson(roomJson),
      todayEvents: List.unmodifiable(
        eventsJson.map((event) {
          if (event is! Map<String, dynamic>) {
            throw const FormatException('Invalid home event');
          }
          return HomeTodayEvent.fromJson(event);
        }),
      ),
      unreadLetterCount: unreadLetters,
      unreadNotificationCount: unreadCount,
    );
  }

  final HomePlantData? plant;
  final HomeRoomData? room;
  final List<HomeTodayEvent> todayEvents;
  final int unreadLetterCount;
  final int unreadNotificationCount;
}

class HomePlantData {
  const HomePlantData({
    required this.id,
    required this.nickname,
    required this.personalityType,
    required this.colorId,
    required this.hairId,
    required this.startedOn,
    required this.daysTogether,
    required this.primaryPhotoUrl,
  });

  factory HomePlantData.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nickname = json['nickname'];
    final personalityType = json['personality_type'];
    final colorId = json['color_id'];
    final hairId = json['hair_id'];
    final startedOn = json['started_on'];
    final daysTogether = json['days_together'];
    final primaryPhotoUrl = json['primary_photo_url'];
    if (id is! String ||
        nickname is! String ||
        nickname.isEmpty ||
        personalityType is! String ||
        personalityType.isEmpty ||
        colorId is! String ||
        hairId is! String ||
        startedOn is! String ||
        daysTogether is! int ||
        daysTogether < 0 ||
        (primaryPhotoUrl != null && primaryPhotoUrl is! String)) {
      throw const FormatException('Invalid home plant');
    }
    return HomePlantData(
      id: id,
      nickname: nickname,
      personalityType: personalityType,
      colorId: colorId,
      hairId: hairId,
      startedOn: startedOn,
      daysTogether: daysTogether,
      primaryPhotoUrl: primaryPhotoUrl as String?,
    );
  }

  final String id;
  final String nickname;
  final String personalityType;
  final String colorId;
  final String hairId;
  final String startedOn;
  final int daysTogether;
  final String? primaryPhotoUrl;
}

class HomeRoomData {
  const HomeRoomData({
    required this.backgroundPhase,
    required this.dialogueKey,
    required this.dialogue,
  });

  factory HomeRoomData.fromJson(Map<String, dynamic> json) {
    final backgroundPhase = json['background_phase'];
    final dialogueKey = json['dialogue_key'];
    final dialogue = json['dialogue'];
    if (backgroundPhase is! String ||
        backgroundPhase.isEmpty ||
        dialogueKey is! String ||
        dialogueKey.isEmpty ||
        (dialogue != null && dialogue is! String)) {
      throw const FormatException('Invalid home room');
    }
    return HomeRoomData(
      backgroundPhase: backgroundPhase,
      dialogueKey: dialogueKey,
      dialogue: dialogue as String?,
    );
  }

  final String backgroundPhase;
  final String dialogueKey;
  final String? dialogue;
}

class HomeTodayEvent {
  const HomeTodayEvent({required this.careType, required this.completable});

  factory HomeTodayEvent.fromJson(Map<String, dynamic> json) {
    final careType = json['care_type'];
    final completable = json['completable'];
    if (careType is! String || careType.isEmpty || completable is! bool) {
      throw const FormatException('Invalid home event');
    }
    return HomeTodayEvent(careType: careType, completable: completable);
  }

  final String careType;
  final bool completable;
}
