// 홈은 API가 반환한 데이터만 표시해야 한다. 세션 fallback과 Figma 예시값이
// 남아 있으면 다른 사용자의 데이터처럼 보이므로 여기서 회귀를 막는다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/services/home_api.dart';
import 'package:yeso_plant/services/plant_management_api.dart';

void main() {
  testWidgets('전달받은 실제 식물 이름과 D+를 표시한다', (tester) async {
    final plant = HomePlant(
      name: '씩씩이',
      startedOn: DateTime.now().subtract(const Duration(days: 9)),
      personalityType: 'OUTGOING',
    );

    await tester.pumpWidget(MaterialApp(home: HomeScreen(plant: plant)));

    expect(find.text('씩씩이 방'), findsOneWidget);
    // 등록한 날이 1일차라 9일 전이면 D+ 10.
    expect(find.text('D+ 10'), findsOneWidget);

    // 시안이 그린 더미가 남아 있으면 안 된다.
    expect(find.text('새싹이 방'), findsNothing);
    expect(find.text('D+ 1281'), findsNothing);
  });

  testWidgets('서버 대사가 없으면 예시 말풍선을 표시하지 않는다', (tester) async {
    const chic = HomePlant(
      name: '까칠이',
      startedOn: null,
      personalityType: 'CHIC',
    );

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(plant: chic, initialGaugesExpanded: false)),
    );

    expect(find.text('흠'), findsNothing);
    expect(find.text('별로야'), findsNothing);
    expect(find.text('신난다'), findsNothing);
  });

  testWidgets('등록 전에는 가짜 식물 대신 등록 안내가 뜬다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loadHome: () async => const HomeDashboardData(
            plant: null,
            room: null,
            todayEvents: [],
            unreadLetterCount: 0,
            unreadNotificationCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('내 식물'), findsOneWidget);
    expect(find.textContaining('등록된 식물이 없어요.'), findsOneWidget);
    expect(find.text('새싹이 방'), findsNothing);
    expect(find.text('D+ 1'), findsNothing);
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

    test('서버가 등록 당일 0일을 보내도 화면에는 D+ 1로 보인다', () {
      const plant = HomePlant(
        name: '새싹이',
        startedOn: null,
        personalityType: null,
        daysTogether: 0,
      );
      expect(plant.dayCount, 1);
    });
  });

  group('HomeTimePeriod', () {
    test('시간대 경계에서 배경 variant를 바꾼다', () {
      const cases = <int, HomeTimePeriod>{
        0: HomeTimePeriod.evening,
        2: HomeTimePeriod.evening,
        3: HomeTimePeriod.afternoon,
        5: HomeTimePeriod.afternoon,
        6: HomeTimePeriod.day,
        14: HomeTimePeriod.day,
        15: HomeTimePeriod.afternoon,
        17: HomeTimePeriod.afternoon,
        18: HomeTimePeriod.evening,
        19: HomeTimePeriod.lateEvening,
        23: HomeTimePeriod.lateEvening,
      };

      for (final entry in cases.entries) {
        expect(
          HomeTimePeriod.fromDateTime(DateTime(2026, 9, 5, entry.key)),
          entry.value,
          reason: '${entry.key}시 배경',
        );
      }
    });
  });

  testWidgets('센서 API 전에는 조도 습도 예시 수치를 표시하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          plant: HomePlant(
            name: '실제식물',
            startedOn: null,
            personalityType: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('기기연결이 필요합니다'), findsOneWidget);
    final message = tester.widget<Text>(find.text('기기연결이 필요합니다'));
    expect(message.style?.fontSize, 21);
    expect(message.style?.fontWeight, FontWeight.w600);
    expect(tester.getTopLeft(find.text('기기연결이 필요합니다')).dy, 683);
    await tester.runAsync(() async {
      final context = tester.element(find.byType(HomeScreen));
      for (final widget in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(widget.image, context);
      }
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_device_required_402.png'),
    );
    expect(find.textContaining('43%'), findsNothing);
    expect(find.textContaining('10%'), findsNothing);
    expect(find.textContaining('65%'), findsNothing);
    expect(find.textContaining('80%'), findsNothing);
    expect(find.byKey(const ValueKey('home-environment-card')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home-environment-collapse')));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-environment-card')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-environment-card')));
    await tester.pump();
    expect(find.text('기기연결이 필요합니다'), findsOneWidget);
  });

  testWidgets('햇빛 요청에서 해를 누르면 감사 상태가 된다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          plant: HomePlant(
            name: '실제식물',
            startedOn: null,
            personalityType: null,
          ),
          initialScene: HomeScene.needsLight,
          initialGaugesExpanded: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('나 햇빛이 부족해..'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-period-control')));
    await tester.pump();

    expect(find.text('아 따뜻해~고마워!'), findsOneWidget);
    expect(find.text('나 햇빛이 부족해..'), findsNothing);
  });

  testWidgets('GET /home 결과로 이름과 D+를 갱신한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          loadHome: () async => const HomeDashboardData(
            plant: HomePlantData(
              id: 'plant-id',
              nickname: '서버새싹',
              personalityType: 'OUTGOING',
              colorId: 'color_orange_01',
              hairId: 'hair_sprout',
              startedOn: '2026-05-01',
              daysTogether: 128,
              primaryPhotoUrl: null,
            ),
            room: HomeRoomData(
              backgroundPhase: 'DAY',
              dialogueKey: 'NORMAL',
              dialogue: null,
            ),
            todayEvents: [],
            unreadLetterCount: 0,
            unreadNotificationCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('서버새싹 방'), findsOneWidget);
    expect(find.text('D+ 128'), findsOneWidget);
  });

  testWidgets('홈 화살표로 다음 식물을 선택하고 홈 데이터를 다시 조회한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _FakePlantManagementRepository([
      _managedPlant('plant-a', '첫째', selected: true),
      _managedPlant('plant-b', '둘째'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          plant: const HomePlant(
            id: 'plant-a',
            name: '첫째',
            startedOn: null,
            personalityType: null,
          ),
          plantRepository: repository,
          loadHomeForPlant: (plantId) async => HomeDashboardData(
            plant: HomePlantData(
              id: plantId!,
              nickname: plantId == 'plant-b' ? '둘째' : '첫째',
              personalityType: 'OUTGOING',
              colorId: 'color_orange_01',
              hairId: 'hair_sprout',
              startedOn: '2026-05-01',
              daysTogether: 3,
              primaryPhotoUrl: null,
            ),
            room: const HomeRoomData(
              backgroundPhase: 'DAY',
              dialogueKey: 'NORMAL',
              dialogue: null,
            ),
            todayEvents: const [],
            unreadLetterCount: 0,
            unreadNotificationCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-next-plant')));
    await tester.pumpAndSettle();

    expect(repository.selectedIds, ['plant-b']);
    expect(find.text('둘째 방'), findsOneWidget);
    expect(find.text('D+ 3'), findsOneWidget);
  });
}

ManagedPlant _managedPlant(
  String id,
  String nickname, {
  bool selected = false,
}) => ManagedPlant(
  id: id,
  nickname: nickname,
  speciesReferenceId: 'species-$id',
  speciesDisplayName: '몬스테라',
  primaryPhotoUrl: null,
  personalityType: 'OUTGOING',
  colorId: 'color_orange_01',
  hairId: 'hair_sprout',
  startedOn: DateTime.now()
      .toUtc()
      .add(const Duration(hours: 9))
      .subtract(const Duration(days: 3)),
  placeName: '거실',
  isSelected: selected,
);

class _FakePlantManagementRepository implements PlantManagementRepository {
  _FakePlantManagementRepository(this.plants);

  List<ManagedPlant> plants;
  final List<String?> selectedIds = [];

  @override
  Future<List<ManagedPlant>> listPlants() async => plants;

  @override
  Future<ManagedPlant> getPlant(String plantId) async =>
      plants.firstWhere((plant) => plant.id == plantId);

  @override
  Future<String?> selectPlant(String? plantId) async {
    selectedIds.add(plantId);
    plants = [
      for (final plant in plants)
        plant.copyWith(isSelected: plant.id == plantId),
    ];
    return plantId;
  }

  @override
  Future<void> deletePlant(String plantId) async {}

  @override
  Future<ManagedPlant> updateAppearance(
    String plantId, {
    String? colorId,
    String? hairId,
  }) => throw UnimplementedError();

  @override
  Future<ManagedPlant> updatePlant(
    String plantId, {
    String? nickname,
    String? placeName,
    String? personalityType,
  }) => throw UnimplementedError();
}
