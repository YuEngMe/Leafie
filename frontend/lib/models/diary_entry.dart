/// 다이어리 한 편. 날짜마다 최대 하나다.
class DiaryEntry {
  const DiaryEntry({
    required this.date,
    this.title = '',
    this.body = '',
    this.photoPath,
    this.photoUrl,
    this.mediaFileId,
    this.weather,
  });

  /// 시각은 버리고 날짜만 쓴다 — 같은 날은 같은 글이다.
  final DateTime date;
  final String title;
  final String body;

  /// 기기에 저장된 사진 경로. 없으면 '사진 추가하기'가 뜬다.
  final String? photoPath;
  final String? photoUrl;
  final String? mediaFileId;
  final DiaryWeather? weather;

  bool get isEmpty =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      photoPath == null &&
      photoUrl == null;

  DiaryEntry copyWith({
    String? title,
    String? body,
    String? photoPath,
    String? photoUrl,
    String? mediaFileId,
    DiaryWeather? weather,
  }) => DiaryEntry(
    date: date,
    title: title ?? this.title,
    body: body ?? this.body,
    photoPath: photoPath ?? this.photoPath,
    photoUrl: photoUrl ?? this.photoUrl,
    mediaFileId: mediaFileId ?? this.mediaFileId,
    weather: weather ?? this.weather,
  );

  /// 같은 날인지. 시각은 보지 않는다.
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// user_metadata에 담아 두기 위한 형태.
  Map<String, Object?> toJson() => {
    'date': DateTime(date.year, date.month, date.day).toIso8601String(),
    'title': title,
    'body': body,
    'photo_path': photoPath,
    'photo_url': photoUrl,
    'media_file_id': mediaFileId,
    'weather': weather?.name,
  };

  static DiaryEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final date = DateTime.tryParse(raw['date'] as String? ?? '');
    if (date == null) return null;
    return DiaryEntry(
      date: date,
      title: raw['title'] as String? ?? '',
      body: raw['body'] as String? ?? '',
      photoPath: raw['photo_path'] as String?,
      photoUrl: raw['photo_url'] as String?,
      mediaFileId: raw['media_file_id'] as String?,
      weather: DiaryWeather.byName(raw['weather'] as String?),
    );
  }
}

/// 날짜 줄 오른쪽에 놓이는 날씨 여섯 가지(2739:39806 외).
enum DiaryWeather {
  sunny('icon_weather_sun.svg', '맑음', 21.02, 21.02),
  partlyCloudy('icon_weather_partly.svg', '구름 조금', 24.93, 19.99),
  cloudy('icon_weather_cloud.svg', '흐림', 25.36, 14.63),
  rainy('icon_weather_rain.svg', '비', 19.70, 11.08),
  shower('icon_weather_drop.svg', '소나기', 18.19, 21.46);

  const DiaryWeather(this.assetName, this.label, this.width, this.height);

  final String assetName;
  final String label;
  final double width;
  final double height;

  String get asset => 'assets/images/$assetName';

  static DiaryWeather? byName(String? name) {
    if (name == null) return null;
    for (final w in values) {
      if (w.name == name) return w;
    }
    return null;
  }
}
