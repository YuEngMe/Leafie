import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/letter_api.dart';

void main() {
  testWidgets('Home에서 목록, 상세, 읽음, 삭제 API를 실제 어댑터로 연결한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const plantId = 'plant-1';
    const letterId = 'letter-1';
    const preview = '오늘도 나를 돌봐 줘서 고마워.';
    final content = List.filled(
      8,
      '오늘 햇빛이 따뜻해서 잎이 더 반짝였어. 내 곁에 있어 줘서 정말 고마워!',
    ).join('\n');
    expect(content.runes.length, greaterThan(100));

    final requests = <LeafieHttpRequest>[];
    final client = LeafieApiClient(
      baseUrl: 'http://localhost:8000/api/v1',
      accessTokenProvider: () async => 'integration-token',
      transport: (request) async {
        requests.add(request);
        final base = <String, Object?>{
          'id': letterId,
          'plant_id': plantId,
          'plant_nickname': '새싹이',
          'diary_id': 'diary-1',
          'diary_date': '2026-09-13',
          'status': 'COMPLETED',
          'preview': preview,
          'generated_at': '2026-09-14T02:00:00Z',
          'published_at': '2026-09-14T03:00:00Z',
        };
        if (request.method == 'GET' && request.uri.path.endsWith('/letters')) {
          return LeafieHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              'items': [
                {...base, 'is_read': false},
              ],
              'next_cursor': null,
            }),
          );
        }
        if (request.method == 'GET') {
          return LeafieHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              ...base,
              'content': content,
              'is_read': false,
              'read_at': null,
            }),
          );
        }
        if (request.method == 'POST') {
          return LeafieHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              ...base,
              'content': content,
              'is_read': true,
              'read_at': '2026-09-14T04:00:00Z',
            }),
          );
        }
        if (request.method == 'DELETE') {
          return const LeafieHttpResponse(statusCode: 204, body: '');
        }
        throw StateError(
          'Unexpected request: ${request.method} ${request.uri}',
        );
      },
    );
    final repository = LetterApi(
      client: client,
      recipientNicknameProvider: () async => '윤지',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          plant: const HomePlant(
            id: plantId,
            name: '새싹이',
            startedOn: null,
            personalityType: null,
          ),
          letterRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-mailbox')));
    for (var i = 0; i < 20; i++) {
      if (find.byKey(const ValueKey('letter-opening')).evaluate().isNotEmpty) {
        break;
      }
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('letter-opening')), findsOneWidget);
    expect(requests, hasLength(2));
    expect(requests.first.method, 'GET');
    expect(requests.first.uri.path, '/api/v1/letters');
    expect(requests.first.uri.queryParameters, {
      'plant_id': plantId,
      'limit': '100',
    });
    expect(requests.last.method, 'GET');
    expect(requests.last.uri.path, '/api/v1/letters/$letterId');
    expect(requests.where((request) => request.method == 'POST'), isEmpty);

    await tester.pump(const Duration(milliseconds: 200));
    expect(requests.where((request) => request.method == 'POST'), isEmpty);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('opened-letter')), findsOneWidget);
    expect(find.text(content), findsOneWidget);
    expect(find.text('TO. 윤지'), findsOneWidget);
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
    expect(requests.last.uri.path, '/api/v1/letters/$letterId/read');
    expect(requests.last.body, isEmpty);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-list')), findsOneWidget);
    await tester.longPress(find.byKey(const ValueKey('mail-$letterId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mail-delete-$letterId')));
    await tester.pumpAndSettle();
    expect(find.text('삭제하시겠습니까?'), findsOneWidget);
    await tester.tap(find.text('네'));
    await tester.pumpAndSettle();

    expect(
      requests.where((request) => request.method == 'DELETE'),
      hasLength(1),
    );
    expect(requests.last.uri.path, '/api/v1/letters/$letterId');
    expect(find.text('아직 도착한 편지가 없어요.'), findsOneWidget);
    expect(
      requests.every(
        (request) =>
            request.headers['authorization'] == 'Bearer integration-token',
      ),
      isTrue,
    );
  });
}
