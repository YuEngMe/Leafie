import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/diary_entry.dart';
import 'package:yeso_plant/screens/diary_screen.dart';
import 'package:yeso_plant/services/diary_api.dart';
import 'package:yeso_plant/services/home_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/widgets/diary_components.dart';

const _plantA = 'plant-a';
const _plantB = 'plant-b';

void main() {
  test('명시한 plantId는 Home 선택값과 무관하게 모든 다이어리 CRUD를 고정한다', () async {
    final requests = <LeafieHttpRequest>[];
    final client = LeafieApiClient(
      baseUrl: 'http://localhost:8000/api/v1',
      accessTokenProvider: () async => 'test-token',
      transport: (request) async {
        requests.add(request);

        if (request.uri.path == '/api/v1/home') {
          return const LeafieHttpResponse(
            statusCode: 200,
            body:
                '{"plant":{"id":"plant-b","nickname":"둘째","days_together":2,"primary_photo_url":null},"character":null,"today_events":[],"unread_notification_count":0}',
          );
        }
        if (request.method == 'GET' &&
            request.uri.path == '/api/v1/plants/$_plantA/diaries') {
          return const LeafieHttpResponse(
            statusCode: 200,
            body:
                '{"entries":[{"id":"entry-a","diary_date":"2026-09-15","weather":"SUNNY","title":"첫째 기록","has_photo":false}]}',
          );
        }
        if (request.method == 'GET' &&
            request.uri.path == '/api/v1/plants/$_plantA/diaries/2026-09-15') {
          return LeafieHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              'id': 'entry-a',
              'plant_id': _plantA,
              'diary_date': '2026-09-15',
              'weather': 'SUNNY',
              'title': '첫째 기록',
              'content': '새 잎이 났다.',
              'media': null,
              'created_at': '2026-09-15T00:00:00Z',
              'updated_at': '2026-09-15T00:00:00Z',
            }),
          );
        }
        if (request.method == 'PUT' || request.method == 'DELETE') {
          return const LeafieHttpResponse(statusCode: 204, body: '');
        }
        return const LeafieHttpResponse(
          statusCode: 500,
          body:
              '{"error":{"code":"UNEXPECTED_REQUEST","message":"unexpected"}}',
        );
      },
    );
    final store = ApiDiaryStore(
      plantId: _plantA,
      client: client,
      homeApi: HomeApi(client: client),
    );
    final date = DateTime(2026, 9, 15);

    final monthEntries = await store.loadMonth(DateTime(2026, 9));
    final dayEntry = await store.loadDay(date);
    await store.save(
      DiaryEntry(
        date: date,
        title: '수정한 기록',
        body: '물을 줬다.',
        weather: DiaryWeather.sunny,
      ),
    );
    await store.delete(date);

    expect(monthEntries.single.date, date);
    expect(dayEntry?.title, '첫째 기록');
    expect(requests.map((request) => request.method), [
      'GET',
      'GET',
      'PUT',
      'DELETE',
    ]);
    expect(
      requests.map((request) => request.uri.path),
      everyElement(startsWith('/api/v1/plants/$_plantA/diaries')),
    );
    expect(
      requests,
      isNot(
        contains(
          isA<LeafieHttpRequest>().having(
            (request) => request.uri.path,
            'path',
            '/api/v1/home',
          ),
        ),
      ),
    );
    expect(
      requests.map((request) => request.uri.path),
      everyElement(isNot(contains(_plantB))),
    );
  });

  test('plantId가 없고 fallback이 꺼져 있으면 요청 전에 실패한다', () async {
    final requests = <LeafieHttpRequest>[];
    final client = LeafieApiClient(
      baseUrl: 'http://localhost:8000/api/v1',
      accessTokenProvider: () async => 'test-token',
      transport: (request) async {
        requests.add(request);
        return const LeafieHttpResponse(statusCode: 200, body: '{}');
      },
    );
    final store = ApiDiaryStore(
      plantId: null,
      resolvePlantIdIfMissing: false,
      client: client,
      homeApi: HomeApi(client: client),
    );

    await expectLater(
      store.loadMonth(DateTime(2026, 9)),
      throwsA(
        isA<LeafieApiException>()
            .having((error) => error.code, 'code', 'PLANT_NOT_FOUND')
            .having((error) => error.statusCode, 'statusCode', 404),
      ),
    );
    expect(requests, isEmpty);
  });

  testWidgets('교체된 plant 화면은 이전 plant의 늦은 날짜 응답을 무시한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final plantAStore = _PendingDayStore();
    final plantBStore = _EmptyStore();

    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          key: const ValueKey(_plantA),
          plantId: _plantA,
          store: plantAStore,
          today: DateTime(2026, 9, 15),
        ),
      ),
    );
    await tester.pump();

    final calendar = tester.widget<DiaryCalendar>(find.byType(DiaryCalendar));
    calendar.onSelect(DateTime(2026, 9, 15));
    await tester.pump();
    expect(plantAStore.loadDayCalls, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          key: const ValueKey(_plantB),
          plantId: _plantB,
          store: plantBStore,
          today: DateTime(2026, 9, 15),
        ),
      ),
    );
    await tester.pump();
    plantAStore.pendingDay.complete(
      DiaryEntry(date: DateTime(2026, 9, 15), title: 'A의 늦은 응답'),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<DiaryScreen>(find.byType(DiaryScreen)).plantId,
      _plantB,
    );
    expect(find.byType(DiaryEntryScreen), findsNothing);
  });
}

class _EmptyStore implements DiaryStore {
  @override
  Future<void> delete(DateTime date) async {}

  @override
  Future<DiaryEntry?> loadDay(DateTime date) async => null;

  @override
  Future<List<DiaryEntry>> loadMonth(DateTime month) async => const [];

  @override
  Future<void> save(DiaryEntry entry) async {}
}

class _PendingDayStore extends _EmptyStore {
  final pendingDay = Completer<DiaryEntry?>();
  int loadDayCalls = 0;

  @override
  Future<DiaryEntry?> loadDay(DateTime date) {
    loadDayCalls++;
    return pendingDay.future;
  }
}
