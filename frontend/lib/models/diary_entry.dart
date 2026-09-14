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

/// 날짜 줄 오른쪽의 상태 아이콘 다섯 가지. 미선택은 회색(4524:20),
/// 선택은 오렌지(4524:21) — 2026-09-14 디자이너 교체분.
enum DiaryWeather {
  sunny('sun', '맑음', 21.024, 21.023),
  partlyCloudy('partly', '구름 조금', 24.93, 19.99),
  cloudy('cloud', '흐림', 25.365, 14.634),
  rainy('rain', '비', 19.70, 21.23),
  shower('drop', '소나기', 17.671, 19.092);

  const DiaryWeather(this.assetName, this.label, this.width, this.height);

  final String assetName;
  final String label;
  final double width;
  final double height;

  /// 미선택(회색 #CCCBCB).
  String get asset => 'assets/images/icon_weather_${assetName}_off.svg';

  /// 선택(오렌지 #FFB52A).
  String get selectedAsset => 'assets/images/icon_weather_${assetName}_on.svg';

  static DiaryWeather? byName(String? name) {
    if (name == null) return null;
    for (final w in values) {
      if (w.name == name) return w;
    }
    return null;
  }
}
