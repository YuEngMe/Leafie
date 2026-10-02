import 'package:yeso_plant/services/leafie_api_client.dart';

// 필드 이름은 현재 백엔드 기준 camelCase(deviceId, soilPercent 등)이며,
// 열린 이슈 #109에 따라 바뀔 수 있다. 바뀌면 이 파일의 fromJson만 고친다.

abstract interface class _WireEnum {
  String get value;
}

enum SensorDeviceStatus implements _WireEnum {
  unclaimed('UNCLAIMED'),
  claimed('CLAIMED');

  const SensorDeviceStatus(this.value);
  @override
  final String value;
}

enum SensorDeviceClaimStatus implements _WireEnum {
  pending('PENDING'),
  completed('COMPLETED'),
  expired('EXPIRED'),
  cancelled('CANCELLED');

  const SensorDeviceClaimStatus(this.value);
  @override
  final String value;
}

enum SensorConnection implements _WireEnum {
  noDevice('NO_DEVICE'),
  noData('NO_DATA'),
  stale('STALE'),
  active('ACTIVE');

  const SensorConnection(this.value);
  @override
  final String value;
}

/// 지표 판정(#124). 정보가 모자라면 UNKNOWN이고 [SensorMetricAssessment.reason]에
/// 사유가 온다.
enum SensorLevel implements _WireEnum {
  unknown('UNKNOWN'),
  low('LOW'),
  ok('OK'),
  high('HIGH');

  const SensorLevel(this.value);
  @override
  final String value;
}

/// 토양 수분 또는 조도 한 지표의 판정. 토양은 상대 %(`relative_percent`),
/// 조도는 하루 누적 lux·h(`lux_hours`)이고, [lower]·[upper]는 종별 기준이다.
/// 기준값은 백엔드의 초기 추정치(provisional)다.
class SensorMetricAssessment {
  const SensorMetricAssessment({
    required this.state,
    required this.unit,
    this.value,
    this.lower,
    this.upper,
    this.reason,
  });

  factory SensorMetricAssessment.fromJson(Map<String, dynamic> json) {
    final unit = json['unit'];
    final value = json['value'];
    final lower = json['lower'];
    final upper = json['upper'];
    final reason = json['reason'];
    if (unit is! String ||
        (value != null && value is! num) ||
        (lower != null && lower is! num) ||
        (upper != null && upper is! num) ||
        (reason != null && reason is! String)) {
      throw const FormatException('Invalid sensor assessment');
    }
    return SensorMetricAssessment(
      state: _enumFrom(
        SensorLevel.values,
        json['state'],
        'Invalid sensor assessment',
      ),
      unit: unit,
      value: (value as num?)?.toDouble(),
      lower: (lower as num?)?.toDouble(),
      upper: (upper as num?)?.toDouble(),
      reason: reason as String?,
    );
  }

  final SensorLevel state;
  final String unit;
  final double? value;
  final double? lower;
  final double? upper;
  final String? reason;
}

/// 홈 `room.sensor`와 센서 상태 API의 `assessment`(같은 구조).
class SensorAssessment {
  const SensorAssessment({
    required this.connection,
    required this.soil,
    required this.light,
  });

  factory SensorAssessment.fromJson(Map<String, dynamic> json) {
    final soil = json['soil'];
    final light = json['light'];
    if (soil is! Map<String, dynamic> || light is! Map<String, dynamic>) {
      throw const FormatException('Invalid sensor assessment');
    }
    return SensorAssessment(
      connection: _enumFrom(
        SensorConnection.values,
        json['connection'],
        'Invalid sensor assessment',
      ),
      soil: SensorMetricAssessment.fromJson(soil),
      light: SensorMetricAssessment.fromJson(light),
    );
  }

  final SensorConnection connection;
  final SensorMetricAssessment soil;
  final SensorMetricAssessment light;
}

abstract interface class SensorRepository {
  /// 이미 등록된 기기는 200, 새 기기는 201이며 둘 다 같은 응답을 돌려준다.
  Future<SensorDeviceData> registerDevice(String deviceId);

  Future<String> createClaim(String deviceId);

  Future<SensorDeviceClaimStatus> getClaimStatus(String claimToken);

  Future<List<SensorDeviceListItem>> listDevices();

  Future<void> releaseDevice(String deviceId);

  Future<PlantSensorDevice> connectPlantDevice(String plantId, String deviceId);

  Future<void> disconnectPlantDevice(String plantId);

  Future<PlantSensorStatus> getPlantSensorStatus(String plantId);
}

class SensorApi implements SensorRepository {
  SensorApi({LeafieApiClient? client}) : _client = client ?? LeafieApiClient();

  final LeafieApiClient _client;

  @override
  Future<SensorDeviceData> registerDevice(String deviceId) async {
    final response = await _client.post(
      '/sensor-devices',
      body: {'deviceId': deviceId},
    );
    return _parse(response, SensorDeviceData.fromJson);
  }

  @override
  Future<String> createClaim(String deviceId) async {
    final response = await _client.post(
      '/sensor-devices/$deviceId/claims',
      body: const {},
    );
    return _parse(response, (json) {
      final token = json['claimToken'];
      if (token is! String || token.isEmpty) {
        throw const FormatException('Invalid sensor claim');
      }
      return token;
    });
  }

  @override
  Future<SensorDeviceClaimStatus> getClaimStatus(String claimToken) async {
    final response = await _client.get('/sensor-device-claims/$claimToken');
    return _parse(
      response,
      (json) => _enumFrom(
        SensorDeviceClaimStatus.values,
        json['status'],
        'Invalid sensor claim status',
      ),
    );
  }

  @override
  Future<List<SensorDeviceListItem>> listDevices() async {
    final response = await _client.get('/sensor-devices');
    return _parse(response, (json) {
      final rawItems = json['items'];
      if (rawItems is! List) {
        throw const FormatException('Invalid sensor devices');
      }
      return List.unmodifiable(
        rawItems.map((rawItem) {
          if (rawItem is! Map<String, dynamic>) {
            throw const FormatException('Invalid sensor device');
          }
          return SensorDeviceListItem.fromJson(rawItem);
        }),
      );
    });
  }

  @override
  Future<void> releaseDevice(String deviceId) async {
    await _client.delete('/sensor-devices/$deviceId');
  }

  @override
  Future<PlantSensorDevice> connectPlantDevice(
    String plantId,
    String deviceId,
  ) async {
    final response = await _client.put(
      '/plants/$plantId/sensor-device',
      body: {'deviceId': deviceId},
    );
    return _parse(response, PlantSensorDevice.fromJson);
  }

  @override
  Future<void> disconnectPlantDevice(String plantId) async {
    await _client.delete('/plants/$plantId/sensor-device');
  }

  @override
  Future<PlantSensorStatus> getPlantSensorStatus(String plantId) async {
    final response = await _client.get('/plants/$plantId/sensor/status');
    return _parse(response, PlantSensorStatus.fromJson);
  }
}

T _parse<T>(
  Map<String, dynamic> response,
  T Function(Map<String, dynamic>) parser,
) {
  try {
    return parser(response);
  } on FormatException {
    throw const LeafieApiException(
      code: 'INVALID_RESPONSE',
      message: '센서 정보를 확인할 수 없습니다.',
      statusCode: 502,
    );
  }
}

class SensorDeviceData {
  const SensorDeviceData({required this.deviceId, required this.status});

  factory SensorDeviceData.fromJson(Map<String, dynamic> json) {
    final deviceId = json['deviceId'];
    if (deviceId is! String || deviceId.isEmpty) {
      throw const FormatException('Invalid sensor device');
    }
    return SensorDeviceData(
      deviceId: deviceId,
      status: _enumFrom(
        SensorDeviceStatus.values,
        json['status'],
        'Invalid sensor device',
      ),
    );
  }

  final String deviceId;
  final SensorDeviceStatus status;
}

class SensorDeviceListItem {
  const SensorDeviceListItem({
    required this.deviceId,
    required this.status,
    this.lastSeenAt,
    this.plantId,
    this.lux,
    this.soilPercent,
    this.measuredAt,
  });

  factory SensorDeviceListItem.fromJson(Map<String, dynamic> json) {
    final deviceId = json['deviceId'];
    final plantId = json['plantId'];
    final lux = json['lux'];
    final soilPercent = json['soilPercent'];
    if (deviceId is! String ||
        deviceId.isEmpty ||
        (plantId != null && plantId is! String) ||
        (lux != null && lux is! num) ||
        (soilPercent != null && soilPercent is! int)) {
      throw const FormatException('Invalid sensor device');
    }
    return SensorDeviceListItem(
      deviceId: deviceId,
      status: _enumFrom(
        SensorDeviceStatus.values,
        json['status'],
        'Invalid sensor device',
      ),
      lastSeenAt: _parseNullableDateTime(json['lastSeenAt']),
      plantId: plantId as String?,
      lux: (lux as num?)?.toDouble(),
      soilPercent: soilPercent as int?,
      measuredAt: _parseNullableDateTime(json['measuredAt']),
    );
  }

  final String deviceId;
  final SensorDeviceStatus status;
  final DateTime? lastSeenAt;
  final String? plantId;
  final double? lux;
  final int? soilPercent;
  final DateTime? measuredAt;
}

class PlantSensorDevice {
  const PlantSensorDevice({required this.plantId, required this.deviceId});

  factory PlantSensorDevice.fromJson(Map<String, dynamic> json) {
    final plantId = json['plantId'];
    final deviceId = json['deviceId'];
    if (plantId is! String ||
        plantId.isEmpty ||
        deviceId is! String ||
        deviceId.isEmpty) {
      throw const FormatException('Invalid plant sensor device');
    }
    return PlantSensorDevice(plantId: plantId, deviceId: deviceId);
  }

  final String plantId;
  final String deviceId;
}

class SensorLatestReading {
  const SensorLatestReading({
    required this.receivedAt,
    this.lux,
    this.soilPercent,
    this.measuredAt,
  });

  factory SensorLatestReading.fromJson(Map<String, dynamic> json) {
    final lux = json['lux'];
    final soilPercent = json['soilPercent'];
    final receivedAt = _parseNullableDateTime(json['receivedAt']);
    if ((lux != null && lux is! num) ||
        (soilPercent != null && soilPercent is! int) ||
        receivedAt == null) {
      throw const FormatException('Invalid sensor reading');
    }
    return SensorLatestReading(
      lux: (lux as num?)?.toDouble(),
      soilPercent: soilPercent as int?,
      measuredAt: _parseNullableDateTime(json['measuredAt']),
      receivedAt: receivedAt,
    );
  }

  final double? lux;
  final int? soilPercent;
  final DateTime? measuredAt;
  final DateTime receivedAt;
}

class SensorDailyLight {
  const SensorDailyLight({required this.date, required this.luxHours});

  factory SensorDailyLight.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final luxHours = json['luxHours'];
    if (date == null || luxHours is! num) {
      throw const FormatException('Invalid sensor daily light');
    }
    return SensorDailyLight(date: date, luxHours: luxHours.toDouble());
  }

  final DateTime date;
  final double luxHours;
}

class PlantSensorStatus {
  const PlantSensorStatus({
    required this.plantId,
    required this.connection,
    this.deviceId,
    this.latest,
    this.dailyLight,
  });

  factory PlantSensorStatus.fromJson(Map<String, dynamic> json) {
    final plantId = json['plantId'];
    final deviceId = json['deviceId'];
    final latest = json['latest'];
    final dailyLight = json['dailyLight'];
    if (plantId is! String ||
        plantId.isEmpty ||
        (deviceId != null && deviceId is! String) ||
        (latest != null && latest is! Map<String, dynamic>) ||
        (dailyLight != null && dailyLight is! Map<String, dynamic>)) {
      throw const FormatException('Invalid sensor status');
    }
    return PlantSensorStatus(
      plantId: plantId,
      deviceId: deviceId as String?,
      connection: _enumFrom(
        SensorConnection.values,
        json['connection'],
        'Invalid sensor status',
      ),
      latest: latest == null
          ? null
          : SensorLatestReading.fromJson(latest as Map<String, dynamic>),
      dailyLight: dailyLight == null
          ? null
          : SensorDailyLight.fromJson(dailyLight as Map<String, dynamic>),
    );
  }

  final String plantId;
  final String? deviceId;
  final SensorConnection connection;
  final SensorLatestReading? latest;
  final SensorDailyLight? dailyLight;
}

T _enumFrom<T extends _WireEnum>(List<T> values, Object? raw, String message) {
  for (final value in values) {
    if (raw is String && value.value == raw) return value;
  }
  throw FormatException(message);
}

DateTime? _parseNullableDateTime(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Invalid sensor datetime');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException('Invalid sensor datetime');
  return parsed;
}
