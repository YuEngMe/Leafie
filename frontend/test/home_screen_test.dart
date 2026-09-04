// 홈은 모든 사용자가 로그인 직후 보는 화면이라, 이름·D+·말풍선이 상수로
// 남아 있으면 남의 식물이 보인다. 세션에서 읽는지 여기서 잠근다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/home_screen.dart';

User _userWithPlant(Map<String, Object?> plant) => User(
  id: 'test-user',
  appMetadata: const {},
  userMetadata: {'leafie_plant': plant},
  aud: 'authenticated',
  createdAt: DateTime.now().toIso8601String(),
);

void main() {
  testWidgets('식물 이름과 D+를 세션에서 읽는다', (tester) async {
    final plant = HomePlant.of(
      _userWithPlant({
        'name': '씩씩이',
        'started_on': DateTime.now()
            .subtract(const Duration(days: 9))
            .toIso8601String(),
        'character': {'personality_type': 'OUTGOING'},
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(plant: plant, signOut: () async {}),
      ),
    );

    expect(find.text('씩씩이 방'), findsOneWidget);
    // 등록한 날이 1일차라 9일 전이면 D+ 10.
    expect(find.text('D+ 10'), findsOneWidget);

    // 시안이 그린 더미가 남아 있으면 안 된다.
    expect(find.text('새싹이 방'), findsNothing);
    expect(find.text('D+ 1281'), findsNothing);
  });

  testWidgets('말풍선은 성격을 따라간다', (tester) async {
    final chic = HomePlant.of(
      _userWithPlant({
        'name': '까칠이',
        'started_on': DateTime.now().toIso8601String(),
        'character': {'personality_type': 'CHIC'},
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(plant: chic, signOut: () async {}),
      ),
    );

    expect(find.text('흠'), findsOneWidget);
    expect(find.text('별로야'), findsOneWidget);
    // 활발한 성격의 대사가 섞이면 안 된다.
    expect(find.text('신난다'), findsNothing);
  });

  testWidgets('등록 전에는 기본 문구로 뜬다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(signOut: () async {})),
    );

    // 세션도 식물도 없지만 화면은 떠야 한다.
    expect(find.text('새싹이 방'), findsOneWidget);
    expect(find.text('D+ 1'), findsOneWidget);
  });

  testWidgets('이름이 비어 있으면 등록 전으로 본다', (tester) async {
    final plant = HomePlant.of(
      _userWithPlant({'name': '', 'character': const {}}),
    );

    expect(plant, isNull);
  });

  group('HomePlant', () {
    test('등록한 날이 1일차다', () {
      final plant = HomePlant(
        name: '씩씩이',
        startedOn: DateTime.now(),
        personalityType: 'OUTGOING',
      );
      expect(plant.dayCount, 1);
    });

    test('started_on이 없으면 1일차로 둔다', () {
      const plant = HomePlant(
        name: '씩씩이',
        startedOn: null,
        personalityType: null,
      );
      expect(plant.dayCount, 1);
    });

    test('모르는 성격은 기본 대사를 쓴다', () {
      const plant = HomePlant(
        name: '씩씩이',
        startedOn: null,
        personalityType: 'UNKNOWN_TYPE',
      );
      expect(plant.moodLines, ['히히', '신난다', '좋은 하루야!']);
    });
  });
}
