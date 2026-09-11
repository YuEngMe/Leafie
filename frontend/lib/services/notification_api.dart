import 'package:yeso_plant/services/leafie_api_client.dart';

abstract interface class NotificationRepository {
  Future<NotificationPage> getNotifications({
    String? cursor,
    bool unreadOnly = false,
    int limit = 20,
  });

  Future<NotificationData> markRead(String notificationId);

  Future<void> markAllRead();

  Future<NotificationDevice> registerDevice({
    required NotificationDevicePlatform platform,
    required String installationId,
  });

  Future<void> revokeDevice(String deviceId);
}

class NotificationApi implements NotificationRepository {
  NotificationApi({LeafieApiClient? client})
    : _client = client ?? LeafieApiClient();

  final LeafieApiClient _client;

  @override
  Future<NotificationPage> getNotifications({
    String? cursor,
    bool unreadOnly = false,
    int limit = 20,
  }) async {
    final response = await _client.get(
      '/notifications',
      queryParameters: {
        'cursor': ?cursor,
        'unread_only': unreadOnly.toString(),
        'limit': limit.toString(),
      },
    );
    try {
      return NotificationPage.fromJson(response);
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '알림 목록을 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }

  @override
  Future<NotificationData> markRead(String notificationId) async {
    final response = await _client.post(
      '/notifications/$notificationId/read',
      body: const {},
    );
    try {
      return NotificationData.fromJson(response);
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '알림 상태를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }

  @override
  Future<void> markAllRead() =>
      _client.post('/notifications/read-all', body: const {});

  @override
  Future<NotificationDevice> registerDevice({
    required NotificationDevicePlatform platform,
    required String installationId,
  }) async {
    final normalized = installationId.trim();
    if (normalized.isEmpty) {
      throw const LeafieApiException(
        code: 'INVALID_DEVICE_TOKEN',
        message: '기기 토큰을 확인할 수 없습니다.',
        statusCode: 422,
      );
    }
    final response = await _client.post(
      '/devices',
      body: {'platform': platform.apiValue, 'installation_id': normalized},
    );
    try {
      return NotificationDevice.fromJson(response);
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '기기 등록 결과를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }

  @override
  Future<void> revokeDevice(String deviceId) =>
      _client.delete('/devices/$deviceId');
}

enum NotificationDevicePlatform {
  ios('IOS'),
  android('ANDROID');

  const NotificationDevicePlatform(this.apiValue);

  final String apiValue;
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.nextCursor,
    required this.hasNext,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawCursor = json['next_cursor'];
    final rawHasNext = json['has_next'];
    if (rawItems is! List ||
        (rawCursor != null && rawCursor is! String) ||
        rawHasNext is! bool) {
      throw const FormatException('Invalid notification page');
    }
    final items = <NotificationData>[];
    for (final item in rawItems) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid notification item');
      }
      items.add(NotificationData.fromJson(item));
    }
    return NotificationPage(
      items: List.unmodifiable(items),
      nextCursor: rawCursor as String?,
      hasNext: rawHasNext,
    );
  }

  final List<NotificationData> items;
  final String? nextCursor;
  final bool hasNext;
}

class NotificationData {
  const NotificationData({
    required this.id,
    required this.plantId,
    required this.type,
    required this.title,
    required this.body,
    required this.sourceType,
    required this.sourceId,
    required this.readAt,
    required this.createdAt,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final plantId = json['plant_id'];
    final type = json['type'];
    final title = json['title'];
    final body = json['body'];
    final sourceType = json['source_type'];
    final sourceId = json['source_id'];
    final readAtText = json['read_at'];
    final createdAtText = json['created_at'];
    final createdAt = createdAtText is String
        ? DateTime.tryParse(createdAtText)
        : null;
    final readAt = readAtText is String ? DateTime.tryParse(readAtText) : null;
    if (id is! String ||
        (plantId != null && plantId is! String) ||
        type is! String ||
        title is! String ||
        body is! String ||
        (sourceType != null && sourceType is! String) ||
        (sourceId != null && sourceId is! String) ||
        (readAtText != null && readAt == null) ||
        createdAt == null) {
      throw const FormatException('Invalid notification');
    }
    return NotificationData(
      id: id,
      plantId: plantId as String?,
      type: type,
      title: title,
      body: body,
      sourceType: sourceType as String?,
      sourceId: sourceId as String?,
      readAt: readAt,
      createdAt: createdAt,
    );
  }

  NotificationData copyWith({DateTime? readAt}) => NotificationData(
    id: id,
    plantId: plantId,
    type: type,
    title: title,
    body: body,
    sourceType: sourceType,
    sourceId: sourceId,
    readAt: readAt ?? this.readAt,
    createdAt: createdAt,
  );

  bool get isRead => readAt != null;

  final String id;
  final String? plantId;
  final String type;
  final String title;
  final String body;
  final String? sourceType;
  final String? sourceId;
  final DateTime? readAt;
  final DateTime createdAt;
}

class NotificationDevice {
  const NotificationDevice({
    required this.id,
    required this.platform,
    required this.createdAt,
  });

  factory NotificationDevice.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final platformText = json['platform'];
    final createdAtText = json['created_at'];
    final createdAt = createdAtText is String
        ? DateTime.tryParse(createdAtText)
        : null;
    final platform = NotificationDevicePlatform.values
        .where((value) => value.apiValue == platformText)
        .firstOrNull;
    if (id is! String || platform == null || createdAt == null) {
      throw const FormatException('Invalid notification device');
    }
    return NotificationDevice(id: id, platform: platform, createdAt: createdAt);
  }

  final String id;
  final NotificationDevicePlatform platform;
  final DateTime createdAt;
}
