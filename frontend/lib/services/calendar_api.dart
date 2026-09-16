import 'dart:math';

import 'package:yeso_plant/services/leafie_api_client.dart';

const Set<String> _calendarItemTypes = {
  'WATERING',
  'REPOTTING',
  'FERTILIZING',
  'PRUNING',
};

abstract interface class CalendarRepository {
  Future<List<CalendarItemData>> listCalendar(
    String plantId,
    DateTime from,
    DateTime to, {
    Iterable<String>? types,
  });

  Future<void> completeEvent(String eventId, {DateTime? performedOn});

  Future<void> createEvent(
    String plantId, {
    required String type,
    required String title,
    required DateTime dueDate,
  });
}

class CalendarApi implements CalendarRepository {
  CalendarApi({LeafieApiClient? client})
    : _client = client ?? LeafieApiClient();

  final LeafieApiClient _client;

  @override
  Future<List<CalendarItemData>> listCalendar(
    String plantId,
    DateTime from,
    DateTime to, {
    Iterable<String>? types,
  }) async {
    final requestedTypes = types
        ?.map((type) => type.trim())
        .where((type) => type.isNotEmpty)
        .toList(growable: false);
    if (requestedTypes != null &&
        requestedTypes.any((type) => !_calendarItemTypes.contains(type))) {
      throw const LeafieApiException(
        code: 'INVALID_CALENDAR_TYPES',
        message: '캘린더 필터 값을 확인해 주세요.',
        statusCode: 422,
      );
    }
    final typeFilter = requestedTypes?.join(',');
    final response = await _client.get(
      '/plants/$plantId/calendar',
      queryParameters: {
        'from': _dateOnly(from),
        'to': _dateOnly(to),
        if (typeFilter != null && typeFilter.isNotEmpty) 'types': typeFilter,
      },
    );

    try {
      final rawItems = response['items'];
      if (rawItems is! List) {
        throw const FormatException('Invalid calendar items');
      }
      return List.unmodifiable(
        rawItems.map((rawItem) {
          if (rawItem is! Map<String, dynamic>) {
            throw const FormatException('Invalid calendar item');
          }
          return CalendarItemData.fromJson(rawItem);
        }),
      );
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '캘린더 정보를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }

  @override
  Future<void> completeEvent(String eventId, {DateTime? performedOn}) async {
    await _client.post(
      '/care-events/$eventId/complete',
      body: {if (performedOn != null) 'performed_on': _dateOnly(performedOn)},
    );
  }

  @override
  Future<void> createEvent(
    String plantId, {
    required String type,
    required String title,
    required DateTime dueDate,
  }) async {
    await _client.post(
      '/plants/$plantId/care-events',
      body: {
        'client_event_id': _uuidV4(),
        'type': type,
        'title': title,
        'due_date': _dateOnly(dueDate),
      },
    );
  }
}

class CalendarItemData {
  const CalendarItemData({
    required this.id,
    required this.date,
    required this.type,
    required this.status,
    required this.viewStatus,
    required this.title,
    required this.source,
    required this.completable,
  });

  factory CalendarItemData.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final date = _parseDateOnly(json['date']);
    final type = json['type'];
    final status = json['status'];
    final viewStatus = json['view_status'];
    final title = json['title'];
    final source = json['source'];
    final completable = json['completable'];

    if (id is! String ||
        id.isEmpty ||
        date == null ||
        type is! String ||
        !_calendarItemTypes.contains(type) ||
        (status != null && status is! String) ||
        (viewStatus != null && viewStatus is! String) ||
        (title != null && title is! String) ||
        (source != null && source is! String) ||
        completable is! bool) {
      throw const FormatException('Invalid calendar item');
    }

    return CalendarItemData(
      id: id,
      date: date,
      type: type,
      status: status as String?,
      viewStatus: viewStatus as String?,
      title: title as String?,
      source: source as String?,
      completable: completable,
    );
  }

  final String id;
  final DateTime date;
  final String type;
  final String? status;
  final String? viewStatus;
  final String? title;
  final String? source;
  final bool completable;
}

String _dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? _parseDateOnly(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final parts = value.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime(parts[0], parts[1], parts[2]);
  if (_dateOnly(parsed) != value) return null;
  return parsed;
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
