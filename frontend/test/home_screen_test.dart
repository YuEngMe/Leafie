import 'dart:async';
// 홈은 API가 반환한 데이터만 표시해야 한다. 세션 fallback과 Figma 예시값이
// 남아 있으면 다른 사용자의 데이터처럼 보이므로 여기서 회귀를 막는다.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_letter.dart';
import 'package:yeso_plant/screens/calendar_screen.dart';
import 'package:yeso_plant/screens/diagnosis_screen.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/widgets/room_slide_switcher.dart';
import 'package:yeso_plant/screens/mailbox_screen.dart';
import 'package:yeso_plant/screens/notification_screen.dart';
import 'package:yeso_plant/services/home_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/notification_api.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/services/sensor_api.dart';
import 'package:yeso_plant/theme/app_motion.dart';
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/home_components.dart';
import 'package:yeso_plant/widgets/instant_page_route.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/retry_feedback.dart';

import 'support/device_view.dart';

/// 홈 캐릭터는 circle 바디라 circle 얼굴을 쓴다.
const _defaultFace = 'assets/images/character/face_circle_default.png';
const _happyFace = 'assets/images/character/face_circle_happy.png';

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

  // 아이콘 PNG에는 그림자 여백이 들어 있다. 예전에는 PNG 전체를 노드 크기
  // 상자에 넣어 그림이 작아지거나(전체보기·진단 25~30%) 여백만큼 밀렸다
  // (해 6px 오른쪽·4px 아래). 보이는 그림이 시안 노드 자리에 오는지 잰다.
  testWidgets('홈 아이콘이 그림자 여백을 빼고 시안 노드 자리에 그려진다', (tester) async {
    useDeviceView(tester);

    Rect assetRect(String asset) => tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == asset,
      ),
    );
    void expectRect(Rect actual, Rect expected, String reason) {
      expect(
        actual.left,
        moreOrLessEquals(expected.left, epsilon: 0.01),
        reason: reason,
      );
      expect(
        actual.top,
        moreOrLessEquals(expected.top, epsilon: 0.01),
        reason: reason,
      );
      expect(
        actual.width,
        moreOrLessEquals(expected.width, epsilon: 0.01),
        reason: reason,
      );
      expect(
        actual.height,
        moreOrLessEquals(expected.height, epsilon: 0.01),
        reason: reason,
      );
    }

    // PNG 좌상단은 시안 이미지(LF-086·087·088)에 PNG를 맞대어 찾은 자리다.
    const phasePng = {
      HomeTimePeriod.day: Offset(26.43, 110.65),
      HomeTimePeriod.afternoon: Offset(29, 115),
      HomeTimePeriod.evening: Offset(33, 114),
    };
    for (final entry in phasePng.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: ValueKey(entry.key),
            period: entry.key,
            plant: const HomePlant(
              name: '실제식물',
              startedOn: null,
              personalityType: null,
            ),
          ),
        ),
      );
      await tester.pump();
      final icon = entry.key.phaseIcon;
      final png = assetRect(icon.asset);
      expect(
        png.left,
        moreOrLessEquals(entry.value.dx, epsilon: 0.01),
        reason: icon.name,
      );
      expect(
        png.top,
        moreOrLessEquals(entry.value.dy, epsilon: 0.01),
        reason: icon.name,
      );
    }

    // 해 노드 4534:9603 (28,113) 80×80.
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
    await tester.pump();
    expectRect(
      tester.getRect(
        find.byWidgetPredicate(
          (w) => w is FigmaHomeAssetIcon && w.icon == FigmaHomeIcon.sun,
        ),
      ),
      const Rect.fromLTWH(28, 113, 79.9966, 79.9966),
      'sun node',
    );
    // 시안 4534:9620: 전체보기 29.256×28.775(8, 15), 진단 22×32(11, 67)
    // 노드에 사방 5·4.4 그림자 여백. 알약은 시안대로 높이 117이다(10/31
    // 피드백으로 7c0ab64의 96을 되돌림).
    expectRect(
      assetRect(FigmaHomeIcon.viewAll.asset),
      const Rect.fromLTWH(333 + 8 - 5, 113 + 15 - 5, 39.256, 38.775),
      'view all',
    );
    expectRect(
      assetRect(FigmaHomeIcon.viewDiagnosis.asset),
      const Rect.fromLTWH(333 + 11 - 4.4, 113 + 67 - 4.4, 30.8, 40.8),
      'diagnosis',
    );
    // 우체통 노드 4534:9607 (310,461) 74.1×120, PNG는 사방 5 바깥.
    expectRect(
      assetRect(FigmaHomeIcon.mailbox.asset),
      const Rect.fromLTWH(305, 456, 84.0994, 130.0006),
      'mailbox',
    );
  });

  // 시안 4534:16876(happy)·4534:9272(편지 배지)·4534:7570(게이지) 기준.
  testWidgets('홈 헤더·말풍선·편지 배지·물뿌리개·게이지 판이 시안대로 그려진다', (tester) async {
    useDeviceView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          initialScene: HomeScene.happy,
          // 게이지를 펼치면 말풍선을 숨기므로 접어 둔다.
          initialGaugesExpanded: false,
          letterRepository: _UnreadLetters(),
          plant: const HomePlant(
            id: 'plant',
            name: '실제식물',
            startedOn: null,
            personalityType: null,
          ),
        ),
      ),
    );
    await tester.pump();

    // D+ 글자 x=33(예전 43). 방 이름은 Medium(500).
    expect(tester.getTopLeft(find.text('D+ 1')), const Offset(33, 61));
    expect(
      tester.widget<Text>(find.text('실제식물 방')).style?.fontWeight,
      FontWeight.w500,
    );
    // 벨 노드 (341,55) 28×31. 탭 영역 56×48 가운데라 세로는 0.5 어긋난다.
    final bell = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is FigmaHomeAssetIcon && w.icon == FigmaHomeIcon.notification,
      ),
    );
    expect(bell.left, moreOrLessEquals(341, epsilon: 0.01));
    expect(bell.top, moreOrLessEquals(55.5, epsilon: 0.01));

    // '히히'만 말풍선 전체가 60%, 나머지 둘은 불투명.
    double? bubbleOpacity(String label) => tester
        .widgetList<Opacity>(
          find.ancestor(of: find.text(label), matching: find.byType(Opacity)),
        )
        .map((o) => o.opacity)
        .where((o) => o < 1)
        .firstOrNull;
    expect(bubbleOpacity('히히'), 0.6);
    expect(bubbleOpacity('신난다'), isNull);
    expect(bubbleOpacity('좋은 하루야!'), isNull);

    Rect assetRect(String asset) => tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == asset,
      ),
    );
    void expectRect(Rect actual, Rect expected) {
      expect(actual.left, moreOrLessEquals(expected.left, epsilon: 0.01));
      expect(actual.top, moreOrLessEquals(expected.top, epsilon: 0.01));
      expect(actual.width, moreOrLessEquals(expected.width, epsilon: 0.01));
      expect(actual.height, moreOrLessEquals(expected.height, epsilon: 0.01));
    }

    // 편지 배지 노드 (319,390) 55×62.188, PNG는 사방 4 그림자 여백 바깥.
    expectRect(
      assetRect('assets/images/home_letter_badge.png'),
      const Rect.fromLTWH(315, 386, 63, 70.188),
    );
    // 물뿌리개 노드 (13.479,496) 83.98×67.751, PNG는 그림자 여백(왼 0.65,
    // 오른 1.52, 위아래 1.52)만큼 바깥.
    expectRect(
      assetRect('assets/images/home_watering_can.png'),
      const Rect.fromLTWH(13.479 - 0.6467, 496 - 1.5176, 86.1467, 70.7862),
    );

    // 붓는 자세(LF-078 4534:11397): 1.355배로 키워 34.48° 기울인 물뿌리개
    // 몸통 중심이 (262,193)에 온다. 예전에는 크기 그대로 y≈180이었다.
    await tester.tap(find.byKey(const ValueKey('home-watering-can')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    final pouring = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/images/home_watering_can.png',
    );
    final center = tester.getCenter(pouring);
    expect(center.dx, moreOrLessEquals(262, epsilon: 1));
    expect(center.dy, moreOrLessEquals(193, epsilon: 1));
    final scale = tester
        .widgetList<Transform>(
          find.ancestor(of: pouring, matching: find.byType(Transform)),
        )
        .map((t) => t.transform.getMaxScaleOnAxis())
        .reduce((a, b) => a * b);
    expect(scale, moreOrLessEquals(113.804 / 83.98, epsilon: 0.001));
    await tester.pumpAndSettle();

    // 게이지 판(4534:7922)은 흰 30%뿐이고 배경 흐림이 없다.
    await tester.tap(find.byKey(const ValueKey('home-environment-card')));
    await tester.pump();
    expect(find.byKey(const ValueKey('home-environment-collapse')), findsOne);
    final blurTops = [
      for (final element in find.byType(BackdropFilter).evaluate())
        tester.getRect(find.byWidget(element.widget)).top,
    ];
    expect(blurTops, isNot(contains(575)));
  });

  testWidgets('센서 API 전에는 조도 습도 예시 수치를 표시하지 않는다', (tester) async {
    useDeviceView(tester);

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

    // 판을 조금만 끌어내리면 제자리로 돌아온다.
    final panel = find.byKey(const ValueKey('home-environment-panel'));
    await tester.drag(panel, const Offset(0, 30));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-environment-card')), findsNothing);
    expect(tester.getTopLeft(find.text('기기연결이 필요합니다')).dy, 683);

    // 충분히 끌어내리면 끝까지 내려간 뒤 접힌다.
    await tester.drag(panel, const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(find.text('기기연결이 필요합니다'), findsNothing);
    expect(find.byKey(const ValueKey('home-environment-card')), findsOneWidget);
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
    // 해를 누르면 "햇빛을 줬어요!" 토스트가 뜬다.
    expect(find.text('햇빛을 줬어요!'), findsOneWidget);

    // 광선 애니메이션 + 2초 토스트가 크래시/펜딩 타이머 없이 끝나야 한다.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('햇빛을 줬어요!'), findsNothing);
  });

  testWidgets('아무 씬에서나 해를 누르면 햇빛 광선과 토스트가 뜬다', (tester) async {
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
          // needsLight가 아닌 idle에서도 발동해야 한다.
          initialScene: HomeScene.idle,
          initialGaugesExpanded: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-period-control')));
    await tester.pump();

    // 씬은 그대로(idle)여도 토스트는 떠야 한다.
    expect(find.text('햇빛을 줬어요!'), findsOneWidget);
    expect(find.text('아 따뜻해~고마워!'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle(); // 펜딩 타이머 없이 완료.
    expect(find.text('햇빛을 줬어요!'), findsNothing);
  });

  testWidgets('달을 누르면 햇빛 없이 달만 흔들리다 멈춘다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.evening,
          plant: HomePlant(
            name: '실제식물',
            startedOn: null,
            personalityType: null,
          ),
          initialScene: HomeScene.idle,
          initialGaugesExpanded: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    double moonAngle() {
      final transform = tester
          .widget<Transform>(find.byKey(const ValueKey('home-moon-swing')))
          .transform;
      return math.atan2(transform.entry(1, 0), transform.entry(0, 0));
    }

    expect(moonAngle(), 0);

    await tester.tap(find.byKey(const ValueKey('home-period-control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(moonAngle().abs(), greaterThan(0.02));
    expect(find.text('햇빛을 줬어요!'), findsNothing);

    await tester.pumpAndSettle();
    expect(moonAngle(), 0);
  });

  testWidgets('물뿌리개를 누르면 물주기 모션이 예외 없이 끝난다', (tester) async {
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
          initialGaugesExpanded: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final wateringCan = find.byKey(const ValueKey('home-watering-can'));
    expect(wateringCan, findsOneWidget);
    await tester.tap(wateringCan);
    await tester.pump(); // 애니메이션 시작.
    // 물을 주면 "물을 줬어요!" 토스트가 뜬다.
    expect(find.text('물을 줬어요!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    // 물줄기(1.4s) + 2초 토스트 + 페이드가 크래시/펜딩 타이머 없이 끝나야 한다.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(wateringCan, findsOneWidget);
    expect(find.text('물을 줬어요!'), findsNothing);
  });

  testWidgets('애니메이션이 꺼져 있어도 돌봄 토스트는 뜨고 2초 뒤 사라진다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: HomeScreen(
            period: HomeTimePeriod.day,
            plant: HomePlant(
              name: '실제식물',
              startedOn: null,
              personalityType: null,
            ),
            initialGaugesExpanded: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-watering-can')));
    await tester.pump();
    // 접근성상 모션은 생략해도 정보 전달을 위해 토스트는 떠야 한다.
    expect(find.text('물을 줬어요!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('물을 줬어요!'), findsNothing);
  });

  testWidgets('캐릭터를 누르면 쓰담 모션이 예외 없이 끝난다', (tester) async {
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
          initialGaugesExpanded: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final character = find.byKey(const ValueKey('home-character-pet'));
    expect(character, findsOneWidget);
    await tester.tap(character);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(character, findsOneWidget);
  });

  group('돌보기 중에는 기쁜 표정을 짓는다', () {
    /// 캐릭터(ValueKey('home-character-pet')) 아래에서 실제로 그려지는 얼굴
    /// 애셋 경로들. AnimatedSwitcher 크로스페이드 중에는 두 장이 함께 잡힌다.
    Set<String> faceAssets(WidgetTester tester) {
      return tester
          .widgetList<Image>(
            find.descendant(
              of: find.byKey(const ValueKey('home-character-pet')),
              matching: find.byType(Image),
            ),
          )
          .map((image) => (image.image as AssetImage).assetName)
          .where((asset) => asset.contains('/face_'))
          .toSet();
    }

    Future<void> pumpHome(WidgetTester tester) async {
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
            initialScene: HomeScene.idle,
            initialGaugesExpanded: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('평소에는 기본 표정이다', (tester) async {
      await pumpHome(tester);

      expect(faceAssets(tester), {_defaultFace});
    });

    testWidgets('물뿌리개를 누르면 기쁜 표정이 됐다가 기본으로 돌아온다', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byKey(const ValueKey('home-watering-can')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(faceAssets(tester), contains(_happyFace));

      // 물주기(3초) + 여운(0.5초) + 크로스페이드가 끝나면 기본으로 돌아온다.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(faceAssets(tester), {_defaultFace});
    });

    testWidgets('해를 누르면 기쁜 표정이 됐다가 기본으로 돌아온다', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byKey(const ValueKey('home-period-control')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(faceAssets(tester), contains(_happyFace));

      // 광선 3초 유지 + 페이드아웃이 끝나면 기본으로 돌아온다.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(faceAssets(tester), {_defaultFace});
    });

    testWidgets('캐릭터를 쓰담으면 기쁜 표정이 됐다가 기본으로 돌아온다', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byKey(const ValueKey('home-character-pet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(faceAssets(tester), contains(_happyFace));

      // 쓰담 wiggle(550ms)이 끝나면 기본으로 돌아온다.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(faceAssets(tester), {_defaultFace});
    });

    group('머리(잎)', () {
      Future<void> pumpLeafHome(WidgetTester tester) async {
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
                bodyId: 'body_circle',
                hairId: 'hair_monstera',
              ),
              initialScene: HomeScene.idle,
              initialGaugesExpanded: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      /// 몸통 박스 좌상단(화면 좌표). 터치 영역은 그 위로 머리 자리만큼 넓다.
      Offset bodyBoxTopLeft(WidgetTester tester) =>
          tester.getTopLeft(find.byKey(const ValueKey('home-character-pet'))) +
          Offset(0, PlantCharacterArt.maxHairOverflow(173.02));

      testWidgets('몸통 위로 넘친 잎을 눌러도 쓰담는다', (tester) async {
        await pumpLeafHome(tester);
        final leaf = PlantCharacterArt.hairInkRect(
          width: 173.02,
          body: PlantBody.circle,
          hairId: 'hair_monstera',
        )!;
        // 잎은 몸통 박스 위로 넘쳐 그려진다.
        expect(leaf.top, lessThan(0));

        await tester.tapAt(bodyBoxTopLeft(tester) + leaf.center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(faceAssets(tester), contains(_happyFace));

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      });

      testWidgets('잎 옆 빈 하늘은 쓰담하지 않는다', (tester) async {
        await pumpLeafHome(tester);
        final leaf = PlantCharacterArt.hairInkRect(
          width: 173.02,
          body: PlantBody.circle,
          hairId: 'hair_monstera',
        )!;

        // 잎 오른쪽 바깥, 잎 높이 가운데.
        await tester.tapAt(
          bodyBoxTopLeft(tester) + Offset(leaf.right + 12, leaf.center.dy),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(faceAssets(tester), {_defaultFace});
      });

      testWidgets('기울어진 잎을 감싼 사각형의 빈 모서리는 쓰담하지 않는다', (tester) async {
        await pumpLeafHome(tester);
        final leaf = PlantCharacterArt.hairInkRect(
          width: 173.02,
          body: PlantBody.circle,
          hairId: 'hair_monstera',
        )!;
        // 몬스테라 잎은 왼쪽으로 기울어 오른쪽 위 모서리가 빈 하늘이다.
        final corner = leaf.topRight + const Offset(-6, 6);
        final hit = PlantCharacterArt.hairHitPath(
          width: 173.02,
          body: PlantBody.circle,
          hairId: 'hair_monstera',
        )!;
        expect(hit.contains(corner), isFalse);
        expect(hit.contains(leaf.center), isTrue);

        await tester.tapAt(bodyBoxTopLeft(tester) + corner);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(faceAssets(tester), {_defaultFace});
      });
    });
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
              colorId: 'color_orange',
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

  // HG-ISS-008: 서버에 닿지 못한 재조회는 오류 카드가 아니라 시안
  // 4955:3086의 연결 끊김 모달로 알리고, '다시 시도'로 다시 조회한다.
  group('홈 조회가 서버에 닿지 못하면', () {
    const homeData = HomeDashboardData(
      plant: HomePlantData(
        id: 'plant-id',
        nickname: '서버새싹',
        personalityType: 'OUTGOING',
        colorId: 'color_orange',
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
    );
    const offline = LeafieApiException(
      code: 'NETWORK_ERROR',
      message: '서버에 연결할 수 없습니다.',
      statusCode: 0,
    );

    /// [responses]를 차례로 돌려준다. 예외면 던진다.
    Future<List<String?>> pumpHome(
      WidgetTester tester,
      List<Object> responses, {
      WidgetBuilder? notificationBuilder,
    }) async {
      useDeviceView(tester);
      final calls = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            period: HomeTimePeriod.day,
            plantRepository: _FakePlantManagementRepository(const []),
            letterRepository: _UnreadLetters(),
            plantManagementBuilder: (_, _, _, _) => const Scaffold(),
            notificationBuilder: notificationBuilder,
            loadHomeForPlant: (plantId) async {
              final response = responses[calls.length];
              calls.add(plantId);
              if (response is LeafieApiException) throw response;
              return response as HomeDashboardData;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return calls;
    }

    final retry = find.byKey(const ValueKey('home-disconnected-retry'));

    testWidgets('연결 끊김 모달을 시안 자리에 띄우고 등록 안내는 띄우지 않는다', (tester) async {
      await pumpHome(tester, [offline]);

      expect(find.text('리피와 연결이 끊겼어요'), findsOneWidget);
      expect(find.text('인터넷 연결을 확인하고 다시 시도해주세요.'), findsOneWidget);
      // 예전에는 캐릭터 위 텍스트 카드에 오류 문구를 띄웠다.
      expect(find.textContaining('서버에 연결할 수 없습니다.'), findsNothing);
      expect(find.textContaining('등록된 식물이 없어요.'), findsNothing);
      // 4955:3667 상자 (47, 358) 308x158.829, 4955:3673 버튼 (69, 466) 264x40.
      final box = find.ancestor(
        of: find.text('리피와 연결이 끊겼어요'),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 308,
        ),
      );
      // showConfirmDialog가 화면 정중앙(437)에 두므로 시안보다 0.4 위다.
      void expectRect(Finder finder, Rect expected) {
        final rect = tester.getRect(finder);
        expect(rect.left, closeTo(expected.left, 0.5));
        expect(rect.top, closeTo(expected.top, 0.5));
        expect(rect.width, closeTo(expected.width, 0.01));
        expect(rect.height, closeTo(expected.height, 0.01));
      }

      expectRect(box, const Rect.fromLTWH(47, 358, 308, 158.829));
      expectRect(retry, const Rect.fromLTWH(69, 466, 264, 40));

      // 시안에 닫기 버튼이 없어 딤을 눌러도 닫히지 않는다.
      await tester.tapAt(const Offset(20, 200));
      await tester.pumpAndSettle();
      expect(find.text('리피와 연결이 끊겼어요'), findsOneWidget);
    });

    testWidgets('다시 시도하면 다시 조회하고, 성공하면 모달을 닫는다', (tester) async {
      final calls = await pumpHome(tester, [offline, offline, homeData]);

      await tester.tap(retry);
      await tester.pumpAndSettle();
      // 또 끊기면 모달이 그대로 남는다(겹쳐 뜨지 않는다).
      expect(calls, hasLength(2));
      expect(find.text('리피와 연결이 끊겼어요'), findsOneWidget);

      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(calls, hasLength(3));
      expect(find.text('리피와 연결이 끊겼어요'), findsNothing);
      expect(find.text('서버새싹 방'), findsOneWidget);
    });

    testWidgets('다시 시도를 누르면 연결 중을 보이고, 또 끊기면 잠깐 알린다', (tester) async {
      await pumpHome(tester, [offline, offline]);

      await tester.tap(retry);
      await tester.pump();
      expect(find.text(kRetryBusyLabel), findsOneWidget);

      await tester.pump(AppMotion.retryMinBusy);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.text(kRetryFailedMessage), findsOneWidget);

      await tester.pump(AppMotion.retryFailedHold);
      expect(find.text('인터넷 연결을 확인하고 다시 시도해주세요.'), findsOneWidget);
    });

    testWidgets('이미 띄운 식물을 다시 불러오다 끊기면 게이지를 그대로 둔다', (tester) async {
      final calls = await pumpHome(tester, [homeData, offline, homeData]);
      final gaugeCard = find.byKey(const ValueKey('home-environment-collapse'));
      expect(gaugeCard, findsOneWidget);

      // 내 캐릭터에 다녀오면 홈을 다시 조회한다.
      await tester.tap(find.byKey(const ValueKey('home-manage-plants')));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(calls, hasLength(2));
      expect(find.text('리피와 연결이 끊겼어요'), findsOneWidget);
      // 시안처럼 모달 뒤에 직전 게이지·방 이름이 남는다.
      expect(gaugeCard, findsOneWidget);
      expect(find.text('서버새싹 방'), findsOneWidget);
    });

    testWidgets('알림에서 돌아와 다시 조회하다 끊기면 알림 대상 화면을 열지 않는다', (tester) async {
      final calls = await pumpHome(
        tester,
        [homeData, offline],
        notificationBuilder: (routeContext) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(routeContext).pop(
              NotificationData(
                id: 'n-diagnosis',
                plantId: 'plant-1',
                type: 'DIAGNOSIS_DONE',
                title: '진단이 끝났어요',
                body: '결과를 확인해 보세요.',
                sourceType: 'DIAGNOSIS',
                sourceId: 'diagnosis-1',
                readAt: DateTime(2026, 9, 25),
                createdAt: DateTime(2026, 9, 25),
              ),
            ),
            child: const Text('진단 알림'),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('home-notifications')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('진단 알림'));
      await tester.pumpAndSettle();

      expect(calls, hasLength(2));
      // 진단 화면이 모달을 덮지 않고, 모달이 맨 위에 보인다.
      expect(find.byType(DiagnosisDetailScreen), findsNothing);
      expect(find.text('리피와 연결이 끊겼어요'), findsOneWidget);
    });

    testWidgets('서버가 답한 오류는 모달이 아니라 오류 카드로 남긴다', (tester) async {
      await pumpHome(tester, [
        const LeafieApiException(
          code: 'INTERNAL_ERROR',
          message: '요청을 처리하지 못했습니다.',
          statusCode: 500,
        ),
      ]);

      expect(find.text('리피와 연결이 끊겼어요'), findsNothing);
      expect(find.textContaining('요청을 처리하지 못했습니다.'), findsOneWidget);
    });
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
              colorId: 'color_orange',
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

    // 꺾쇠 그림(24)보다 넓은 44x44 안, 그림 바깥 구석을 눌러도 넘어간다.
    final next = find.byKey(const ValueKey('home-next-plant'));
    expect(tester.getSize(next), const Size(44, 44));
    await tester.tapAt(tester.getRect(next).topRight.translate(-3, 3));
    await tester.pumpAndSettle();

    expect(repository.selectedIds, ['plant-b']);
    expect(find.text('둘째 방'), findsOneWidget);
    expect(find.text('D+ 3'), findsOneWidget);
  });

  testWidgets('캐릭터를 바꾸면 선택 저장과 홈 조회를 함께 보내고 목록은 다시 받지 않는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _FakePlantManagementRepository([
      _managedPlant('plant-a', '첫째', selected: true),
      _managedPlant('plant-b', '둘째'),
    ]);
    final homeRequests = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          initialGaugesExpanded: false,
          plant: const HomePlant(
            id: 'plant-a',
            name: '첫째',
            startedOn: null,
            personalityType: null,
          ),
          plantRepository: repository,
          loadHomeForPlant: (plantId) async {
            homeRequests.add(plantId);
            return HomeDashboardData(
              plant: HomePlantData(
                id: plantId!,
                nickname: plantId == 'plant-b' ? '둘째' : '첫째',
                personalityType: 'OUTGOING',
                colorId: 'color_orange',
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
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final listCallsBefore = repository.listCalls;
    homeRequests.clear();

    // 선택 저장이 끝나기 전에도 홈 조회가 나가고, 그 사이 방이 바뀐다.
    repository.selectGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('home-next-plant')));
    await tester.pump();
    expect(repository.selectedIds, ['plant-b']);
    expect(homeRequests, ['plant-b']);

    repository.selectGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('둘째 방'), findsOneWidget);
    expect(repository.listCalls, listCallsBefore, reason: '전환 뒤 목록을 다시 받지 않는다');

    // 목록 선택 표시는 로컬에서 바뀌어, 다시 > 를 누르면 첫째로 돌아온다.
    await tester.tap(find.byKey(const ValueKey('home-next-plant')));
    await tester.pumpAndSettle();
    expect(repository.selectedIds, ['plant-b', 'plant-a']);
    expect(find.text('첫째 방'), findsOneWidget);
  });

  group('다음 식물을 못 불러오면 화면과 서버 선택을 맞춘다 (HG-ISS-009)', () {
    HomeDashboardData first() => const HomeDashboardData(
      plant: HomePlantData(
        id: 'plant-a',
        nickname: '첫째',
        personalityType: 'OUTGOING',
        colorId: 'color_orange',
        hairId: 'hair_sprout',
        startedOn: '2026-05-01',
        daysTogether: 3,
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
    );

    Future<_FakePlantManagementRepository> pumpSwitch(
      WidgetTester tester,
      LeafieApiException secondPlantError,
    ) async {
      useDeviceView(tester);
      final repository = _FakePlantManagementRepository([
        _managedPlant('plant-a', '첫째', selected: true),
        _managedPlant('plant-b', '둘째'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            period: HomeTimePeriod.day,
            plantRepository: repository,
            letterRepository: _UnreadLetters(),
            loadHomeForPlant: (plantId) async {
              if (plantId == 'plant-b') throw secondPlantError;
              return first();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-next-plant')));
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('서버 오류면 선택을 이전 식물로 되돌리고 이전 방을 그대로 둔다', (tester) async {
      final repository = await pumpSwitch(
        tester,
        const LeafieApiException(
          code: 'INTERNAL_ERROR',
          message: '요청을 처리하지 못했습니다.',
          statusCode: 500,
        ),
      );

      expect(repository.selectedIds, ['plant-b', 'plant-a']);
      expect(
        repository.plants.singleWhere((plant) => plant.isSelected).id,
        'plant-a',
      );
      expect(find.text('첫째 방'), findsOneWidget);
      // 오류 카드(다시 불러오기) 대신 안내만 띄운다.
      expect(find.textContaining('다시 불러오기'), findsNothing);
      expect(find.text('요청을 처리하지 못했습니다.'), findsOneWidget);
    });

    testWidgets('연결이 끊겼으면 선택을 새 식물에 두고 모달의 다시 시도에 맡긴다', (tester) async {
      final repository = await pumpSwitch(
        tester,
        const LeafieApiException(
          code: 'NETWORK_ERROR',
          message: '서버에 연결할 수 없습니다.',
          statusCode: 0,
        ),
      );

      // 끊긴 채로 되돌리기를 보내지 않는다. 다시 시도가 plant-b를 부른다.
      expect(repository.selectedIds, ['plant-b']);
      expect(find.text('리피와 연결이 끊겼어요'), findsOneWidget);
    });
  });

  group('서버 응답으로 씬을 정한다', () {
    HomeDashboardData dashboard(
      String plantId, {
      required bool wateringRequest,
      String dialogueKey = 'NORMAL',
      String dialogue = '오늘도 힘차게 자라 볼게!',
    }) => HomeDashboardData(
      plant: HomePlantData(
        id: plantId,
        nickname: plantId == 'plant-b' ? '둘째' : '첫째',
        personalityType: 'OUTGOING',
        colorId: 'color_orange',
        hairId: 'hair_sprout',
        startedOn: '2026-05-01',
        daysTogether: 3,
        primaryPhotoUrl: null,
      ),
      room: HomeRoomData(
        backgroundPhase: 'DAY',
        dialogueKey: dialogueKey,
        dialogue: dialogue,
      ),
      todayEvents: [
        if (wateringRequest)
          const HomeTodayEvent(careType: 'WATERING', completable: true),
      ],
      unreadLetterCount: 0,
      unreadNotificationCount: 0,
    );

    Future<void> pumpHome(
      WidgetTester tester,
      Future<HomeDashboardData> Function(String?) load,
      _FakePlantManagementRepository repository,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            period: HomeTimePeriod.day,
            initialGaugesExpanded: false,
            plantRepository: repository,
            loadHomeForPlant: load,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // 디자이너 확인(2026-10): 평소 대사도 기존 말풍선 모양으로 띄운다.
    testWidgets('평소 대사는 목마른 말풍선이 아니라 기본 대사 말풍선으로 띄운다', (tester) async {
      await pumpHome(
        tester,
        (id) async => dashboard(id ?? 'plant-a', wateringRequest: false),
        _FakePlantManagementRepository([
          _managedPlant('plant-a', '첫째', selected: true),
        ]),
      );

      expect(find.text('나 지금 목말라.. 물이 필요해'), findsNothing);
      expect(
        find.byKey(const ValueKey('home-dialogue-fallback')),
        findsOneWidget,
      );
      expect(find.text('오늘도 힘차게 자라 볼게!'), findsOneWidget);
    });

    testWidgets('물주기 일정이 있으면 평소 대사가 아닌 목마른 문구를 띄운다', (tester) async {
      await pumpHome(
        tester,
        (id) async => dashboard(id ?? 'plant-a', wateringRequest: true),
        _FakePlantManagementRepository([
          _managedPlant('plant-a', '첫째', selected: true),
        ]),
      );

      expect(find.byType(PlantRequestBubble), findsOneWidget);
      expect(find.text('나 지금 목말라.. 물이 필요해'), findsOneWidget);
    });

    testWidgets('햇빛 부족 상황이면 햇빛 말풍선에 서버 대사를 띄운다', (tester) async {
      await pumpHome(
        tester,
        (id) async => dashboard(
          id ?? 'plant-a',
          wateringRequest: false,
          dialogueKey: 'LIGHT_LOW',
          dialogue: '햇빛 좀 쬐고 싶어!',
        ),
        _FakePlantManagementRepository([
          _managedPlant('plant-a', '첫째', selected: true),
        ]),
      );

      expect(find.byType(PlantRequestBubble), findsOneWidget);
      expect(find.text('햇빛 좀 쬐고 싶어!'), findsOneWidget);
    });

    testWidgets('흙이 마른 상황이면 일정이 없어도 목마른 말풍선에 서버 대사를 띄운다', (tester) async {
      await pumpHome(
        tester,
        (id) async => dashboard(
          id ?? 'plant-a',
          wateringRequest: false,
          dialogueKey: 'SOIL_MOISTURE_LOW',
          dialogue: '목이 바싹 말랐어!',
        ),
        _FakePlantManagementRepository([
          _managedPlant('plant-a', '첫째', selected: true),
        ]),
      );

      expect(find.text('목이 바싹 말랐어!'), findsOneWidget);
    });

    testWidgets('물주기 일정과 햇빛 부족이 겹치면 물을 먼저 띄우고 햇빛 대사는 넣지 않는다', (tester) async {
      await pumpHome(
        tester,
        (id) async => dashboard(
          id ?? 'plant-a',
          wateringRequest: true,
          dialogueKey: 'LIGHT_LOW',
          dialogue: '햇빛 좀 쬐고 싶어!',
        ),
        _FakePlantManagementRepository([
          _managedPlant('plant-a', '첫째', selected: true),
        ]),
      );

      expect(find.text('나 지금 목말라.. 물이 필요해'), findsOneWidget);
      expect(find.text('햇빛 좀 쬐고 싶어!'), findsNothing);
    });

    testWidgets('목마른 식물에서 다른 식물로 넘어가면 목마른 말풍선이 사라진다', (tester) async {
      await pumpHome(
        tester,
        (id) async => dashboard(
          id ?? 'plant-a',
          wateringRequest: (id ?? 'plant-a') == 'plant-a',
        ),
        _FakePlantManagementRepository([
          _managedPlant('plant-a', '첫째', selected: true),
          _managedPlant('plant-b', '둘째'),
        ]),
      );
      expect(find.text('나 지금 목말라.. 물이 필요해'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-next-plant')));
      await tester.pumpAndSettle();

      expect(find.text('둘째 방'), findsOneWidget);
      expect(find.text('나 지금 목말라.. 물이 필요해'), findsNothing);
    });
  });
  testWidgets('우편함이 떠 있는 동안 알림 벨·배지를 닫기 X 뒤에 그리지 않는다', (tester) async {
    // 시안 우체통 프레임(4534:11529~16319)에는 벨이 없고 그 자리에 닫기 X만
    // 있다. 벨을 남겨 두면 빨간 배지가 닫기 원 밖으로 비쳤다(MM-12).
    useDeviceView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          plantRepository: _FakePlantManagementRepository([
            _managedPlant('plant-a', '첫째', selected: true),
          ]),
          letterRepository: _ReadLetters(),
          loadHomeForPlant: (plantId) async => const HomeDashboardData(
            plant: HomePlantData(
              id: 'plant-a',
              nickname: '첫째',
              personalityType: 'OUTGOING',
              colorId: 'color_orange',
              hairId: 'hair_sprout',
              startedOn: '2026-05-01',
              daysTogether: 3,
              primaryPhotoUrl: null,
            ),
            room: HomeRoomData(
              backgroundPhase: 'DAY',
              dialogueKey: 'NORMAL',
              dialogue: '평소 대사',
            ),
            todayEvents: [],
            unreadLetterCount: 0,
            unreadNotificationCount: 4,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bell = find.byKey(const ValueKey('home-notifications'));
    expect(bell, findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-mailbox')));
    await tester.pumpAndSettle();
    expect(bell, findsNothing);
    expect(find.text('4'), findsNothing);

    // 편지 목록은 바깥 닫기와 목록 닫기가 함께 있다. 맨 위 것을 누른다.
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    expect(bell, findsOneWidget);
  });

  testWidgets('관리 일정 알림을 누르면 알림 목록을 닫고 캘린더 탭으로 간다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          plant: const HomePlant(
            id: 'plant-a',
            name: '첫째',
            startedOn: null,
            personalityType: null,
          ),
          period: HomeTimePeriod.day,
          plantRepository: _FakePlantManagementRepository([
            _managedPlant('plant-a', '첫째', selected: true),
          ]),
          loadHomeForPlant: (plantId) async => const HomeDashboardData(
            plant: HomePlantData(
              id: 'plant-a',
              nickname: '첫째',
              personalityType: 'OUTGOING',
              colorId: 'color_orange',
              hairId: 'hair_sprout',
              startedOn: '2026-05-01',
              daysTogether: 3,
              primaryPhotoUrl: null,
            ),
            room: HomeRoomData(
              backgroundPhase: 'DAY',
              dialogueKey: 'NORMAL',
              dialogue: '평소 대사',
            ),
            todayEvents: [],
            unreadLetterCount: 0,
            unreadNotificationCount: 1,
          ),
          notificationBuilder: (routeContext) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(routeContext).pop(
                NotificationData(
                  id: 'n-1',
                  plantId: 'plant-a',
                  type: 'WATERING_REMINDER',
                  title: '물을 줄 시간이에요',
                  body: '첫째에게 물을 주세요.',
                  sourceType: 'CARE_EVENT',
                  sourceId: 'event-1',
                  readAt: DateTime(2026, 9, 25),
                  createdAt: DateTime(2026, 9, 25),
                ),
              ),
              child: const Text('알림 하나'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-notifications')));
    // 알림센터는 슬라이드 없이 한 프레임 만에 다 뜬다.
    await tester.pump();
    final route = ModalRoute.of(tester.element(find.text('알림 하나')))!;
    expect(route, isA<InstantPageRoute<NotificationData>>());
    expect(route.animation!.value, 1);
    await tester.tap(find.text('알림 하나'));
    await tester.pumpAndSettle();

    expect(find.text('알림 하나'), findsNothing);
    expect(
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).activeIcon,
      FigmaNavIcon.calendar,
    );
  });
  group('기본 알림 화면에서 알림을 누르면', () {
    NotificationData notification(String id, {String? sourceType}) =>
        NotificationData(
          id: id,
          plantId: 'plant-a',
          type: 'ANY',
          title: '알림 $id',
          body: '본문',
          sourceType: sourceType,
          sourceId: 'source-$id',
          readAt: null,
          createdAt: DateTime(2026, 9, 25),
        );

    Future<void> openList(
      WidgetTester tester,
      List<NotificationData> items,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            plant: const HomePlant(
              id: 'plant-a',
              name: '첫째',
              startedOn: null,
              personalityType: null,
            ),
            period: HomeTimePeriod.day,
            plantRepository: _FakePlantManagementRepository([
              _managedPlant('plant-a', '첫째', selected: true),
            ]),
            loadHomeForPlant: (_) async => const HomeDashboardData(
              plant: null,
              room: null,
              todayEvents: [],
              unreadLetterCount: 0,
              unreadNotificationCount: 0,
            ),
            notificationRepository: _FakeNotificationRepository(items),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-notifications')));
      await tester.pumpAndSettle();
    }

    testWidgets('갈 곳이 없는 알림은 목록에 머문다', (tester) async {
      await openList(tester, [notification('1')]);

      await tester.tap(find.text('알림 1'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationScreen), findsOneWidget);
    });

    testWidgets('두 알림을 연달아 눌러도 홈까지 닫히지 않는다', (tester) async {
      await openList(tester, [
        notification('1', sourceType: 'CARE_EVENT'),
        notification('2', sourceType: 'CARE_EVENT'),
      ]);

      await tester.tap(find.text('알림 1'));
      await tester.tap(find.text('알림 2'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(NotificationScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).activeIcon,
        FigmaNavIcon.calendar,
      );
    });
  });

  testWidgets('내 캐릭터에서 돌아오면 캘린더 탭을 새로 만들어 일정을 다시 불러온다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          plant: const HomePlant(
            id: 'plant-a',
            name: '첫째',
            startedOn: null,
            personalityType: null,
          ),
          period: HomeTimePeriod.day,
          plantRepository: _FakePlantManagementRepository([
            _managedPlant('plant-a', '첫째', selected: true),
          ]),
          loadHomeForPlant: (_) async => const HomeDashboardData(
            plant: null,
            room: null,
            todayEvents: [],
            unreadLetterCount: 0,
            unreadNotificationCount: 0,
          ),
          plantManagementBuilder: (routeContext, _, _, _) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(routeContext).pop(),
              child: const Text('관리 닫기'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder navIcon(FigmaNavIcon icon) => find.byWidgetPredicate(
      (w) => w is FigmaBottomNavIcon && w.icon == icon,
    );

    await tester.tap(navIcon(FigmaNavIcon.calendar));
    await tester.pumpAndSettle();
    final before = tester
        .widget<CalendarScreen>(find.byType(CalendarScreen))
        .key;

    await tester.tap(navIcon(FigmaNavIcon.home));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-manage-plants')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('관리 닫기'));
    await tester.pumpAndSettle();

    // 홈 탭이 앞이라 캘린더는 가려진(offstage) 상태다.
    final after = tester
        .widget<CalendarScreen>(
          find.byType(CalendarScreen, skipOffstage: false),
        )
        .key;
    expect(after, isNot(before));
  });

  testWidgets('오른쪽 집 아이콘을 누르면 캐릭터 전체보기를 연다', (tester) async {
    useDeviceView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          plantRepository: _FakePlantManagementRepository(const []),
          loadHomeForPlant: (_) async => const HomeDashboardData(
            plant: null,
            room: null,
            todayEvents: [],
            unreadLetterCount: 0,
            unreadNotificationCount: 0,
          ),
          plantManagementBuilder: (_, _, _, _) =>
              const Scaffold(body: Text('전체보기 화면')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 시안 4534:9620: 알약 333,113 45x117.
    final viewSwitch = find.byType(FigmaHomeViewSwitch);
    expect(tester.getTopLeft(viewSwitch), const Offset(333, 113));
    expect(tester.getSize(viewSwitch), const Size(45, 117));

    await tester.tap(find.byKey(const ValueKey('home-overview-switch')));
    // 전체보기도 슬라이드 없이 한 번에 뜬다.
    await tester.pump();
    expect(
      ModalRoute.of(tester.element(find.text('전체보기 화면'))),
      isA<InstantPageRoute<Object?>>(),
    );
    await tester.pumpAndSettle();
    expect(find.text('전체보기 화면'), findsOneWidget);
  });

  testWidgets('센서가 정상이면 게이지 두 줄을, 기기가 없으면 연결 안내를 보여 준다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> pumpWith(SensorAssessment? sensor) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: UniqueKey(),
            period: HomeTimePeriod.day,
            sensorRepository: sensor == null
                ? null
                : _FakeSensorRepository(sensor, lux: 523.4),
            plantRepository: _FakePlantManagementRepository([
              _managedPlant('plant-a', '새싹이', selected: true),
            ]),
            loadHomeForPlant: (_) async => HomeDashboardData(
              plant: const HomePlantData(
                id: 'plant-a',
                nickname: '새싹이',
                personalityType: 'OUTGOING',
                colorId: 'color_orange',
                hairId: 'hair_sprout',
                startedOn: '2026-05-01',
                daysTogether: 3,
                primaryPhotoUrl: null,
              ),
              room: HomeRoomData(
                backgroundPhase: 'DAY',
                dialogueKey: 'NORMAL',
                dialogue: '평소 대사',
                sensor: sensor,
              ),
              todayEvents: const [],
              unreadLetterCount: 0,
              unreadNotificationCount: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpWith(
      const SensorAssessment(
        connection: SensorConnection.active,
        soil: SensorMetricAssessment(
          state: SensorLevel.low,
          unit: 'relative_percent',
          value: 20,
          lower: 40,
          upper: 90,
        ),
        light: SensorMetricAssessment(
          state: SensorLevel.ok,
          unit: 'lux_hours',
          value: 72000,
          lower: 60000,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('home-gauge-humidity')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-gauge-light')), findsOneWidget);
    expect(find.text('새싹이는 40 - 90% 습도를 좋아해요'), findsOneWidget);
    expect(find.text('현재습도 20%'), findsOneWidget);
    // 조도 게이지는 /home이 아니라 센서 상태 API의 순간 조도를 보여 준다.
    expect(find.text('현재조도 523lx'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-environment-message')),
      findsNothing,
    );
    // 시안 4534:7952: 부족(LOW)한 값의 마커만 글자 앞에 빨간 점을 찍는다.
    Finder alertIn(String gauge) => find.descendant(
      of: find.byKey(ValueKey('home-gauge-$gauge')),
      matching: find.byKey(const ValueKey('gauge-marker-alert')),
    );
    expect(alertIn('humidity'), findsOneWidget);
    expect(alertIn('light'), findsNothing);

    await pumpWith(null);
    expect(find.text('기기연결이 필요합니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-gauge-humidity')), findsNothing);
  });

  testWidgets('연결된 센서는 접어도 10초마다 새로 받는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SensorAssessment soilAt(double value) => SensorAssessment(
      connection: SensorConnection.active,
      soil: SensorMetricAssessment(
        state: SensorLevel.low,
        unit: 'relative_percent',
        value: value,
        lower: 40,
        upper: 90,
      ),
      light: const SensorMetricAssessment(
        state: SensorLevel.unknown,
        unit: 'lux_hours',
      ),
    );
    final sensors = _FakeSensorRepository(soilAt(25), lux: 900);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          sensorRepository: sensors,
          plantRepository: _FakePlantManagementRepository([
            _managedPlant('plant-a', '새싹이', selected: true),
          ]),
          loadHomeForPlant: (_) async => HomeDashboardData(
            plant: const HomePlantData(
              id: 'plant-a',
              nickname: '새싹이',
              personalityType: 'OUTGOING',
              colorId: 'color_orange',
              hairId: 'hair_sprout',
              startedOn: '2026-05-01',
              daysTogether: 3,
              primaryPhotoUrl: null,
            ),
            room: HomeRoomData(
              backgroundPhase: 'DAY',
              dialogueKey: 'NORMAL',
              dialogue: '평소 대사',
              sensor: soilAt(20),
            ),
            todayEvents: const [],
            unreadLetterCount: 0,
            unreadNotificationCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // /home에는 순간 조도가 없어 펼쳐진 채 열리면 바로 한 번 받는다.
    expect(sensors.requests, ['plant-a']);
    expect(find.text('현재습도 25%'), findsOneWidget);
    expect(find.text('현재조도 900lx'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(sensors.requests, ['plant-a', 'plant-a']);

    // 접어도 센서가 연결돼 있으면 배경을 정하려고 계속 받는다.
    await tester.tap(find.byKey(const ValueKey('home-environment-collapse')));
    await tester.pumpAndSettle();
    expect(sensors.requests.length, 2, reason: '접을 때는 이미 받은 값이 있어 다시 받지 않는다');
    await tester.pump(const Duration(seconds: 50));
    expect(sensors.requests.length, 2, reason: '접어 둔 동안은 10초마다 받지 않는다');
    await tester.pump(const Duration(seconds: 10));
    expect(sensors.requests.length, 3, reason: '접어 둔 동안은 60초마다 받는다');

    // 다시 펼치면 바로 한 번 받는다.
    await tester.tap(find.byKey(const ValueKey('home-environment-card')));
    await tester.pumpAndSettle();
    expect(sensors.requests.length, 4);
  });

  group('방을 넘기면 센서 판 내용도 캐릭터와 같이 밀려 바뀐다', () {
    const activeSensor = SensorAssessment(
      connection: SensorConnection.active,
      soil: SensorMetricAssessment(
        state: SensorLevel.ok,
        unit: 'relative_percent',
        value: 50,
      ),
      light: SensorMetricAssessment(state: SensorLevel.ok, unit: 'lux_hours'),
    );

    HomeDashboardData dashboard(String id, SensorAssessment? sensor) =>
        HomeDashboardData(
          plant: HomePlantData(
            id: id,
            nickname: id == 'plant-a' ? '첫째' : '둘째',
            personalityType: 'OUTGOING',
            colorId: 'color_orange',
            hairId: 'hair_sprout',
            startedOn: '2026-05-01',
            daysTogether: 3,
            primaryPhotoUrl: null,
          ),
          room: HomeRoomData(
            backgroundPhase: 'DAY',
            dialogueKey: 'NORMAL',
            dialogue: null,
            sensor: sensor,
          ),
          todayEvents: const [],
          unreadLetterCount: 0,
          unreadNotificationCount: 0,
        );

    testWidgets('응답 전에는 이전 방 판을 두고, 응답이 오면 함께 밀린다', (tester) async {
      useDeviceView(tester);
      final gate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            period: HomeTimePeriod.day,
            sensorRepository: _PerPlantSensors({'plant-a': activeSensor}),
            plantRepository: _FakePlantManagementRepository([
              _managedPlant('plant-a', '첫째', selected: true),
              _managedPlant('plant-b', '둘째'),
            ]),
            letterRepository: _UnreadLetters(),
            loadHomeForPlant: (plantId) async {
              if (plantId == 'plant-b') {
                await gate.future;
                return dashboard('plant-b', null);
              }
              return dashboard('plant-a', activeSensor);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final humidity = find.byKey(const ValueKey('home-gauge-humidity'));
      final message = find.text('기기연결이 필요합니다');
      expect(humidity, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-next-plant')));
      await tester.pumpAndSettle();
      // 둘째 방 응답 전: 판을 미리 비워 '기기연결이 필요합니다'를 띄우지 않는다.
      expect(humidity, findsOneWidget);
      expect(message, findsNothing);

      gate.complete();
      await tester.pump();
      await tester.pump(RoomSlideSwitcher.duration ~/ 2);
      // 밀리는 중: 첫째 방 게이지가 나가고 둘째 방 안내가 들어온다.
      expect(humidity, findsOneWidget);
      expect(message, findsOneWidget);
      expect(
        tester.getTopLeft(message).dx,
        greaterThan(tester.getTopLeft(humidity).dx),
      );

      await tester.pumpAndSettle();
      expect(humidity, findsNothing);
      expect(message, findsOneWidget);
    });
  });

  group('센서가 연결되면 순간 조도로 배경을 정한다', () {
    Future<_FakeSensorRepository> pumpHome(
      WidgetTester tester, {
      required SensorConnection connection,
      double? lux,
      double? roomLux,
    }) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sensor = SensorAssessment(
        connection: connection,
        currentLux: roomLux,
        soil: const SensorMetricAssessment(
          state: SensorLevel.ok,
          unit: 'relative_percent',
          value: 50,
        ),
        light: const SensorMetricAssessment(
          state: SensorLevel.ok,
          unit: 'lux_hours',
        ),
      );
      final sensors = _FakeSensorRepository(sensor, lux: lux);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            initialGaugesExpanded: false,
            sensorRepository: sensors,
            plantRepository: _FakePlantManagementRepository([
              _managedPlant('plant-a', '새싹이', selected: true),
            ]),
            loadHomeForPlant: (_) async => HomeDashboardData(
              plant: const HomePlantData(
                id: 'plant-a',
                nickname: '새싹이',
                personalityType: 'OUTGOING',
                colorId: 'color_orange',
                hairId: 'hair_sprout',
                startedOn: '2026-05-01',
                daysTogether: 3,
                primaryPhotoUrl: null,
              ),
              room: HomeRoomData(
                backgroundPhase: 'DAY',
                dialogueKey: 'NORMAL',
                dialogue: '평소 대사',
                sensor: sensor,
              ),
              todayEvents: const [],
              unreadLetterCount: 0,
              unreadNotificationCount: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return sensors;
    }

    Finder background(HomeTimePeriod period) =>
        find.byKey(ValueKey(period.asset));

    test('lux 경계는 낮 1000, 오후 300, 저녁 50이다', () {
      expect(HomeTimePeriod.fromLux(1000), HomeTimePeriod.day);
      expect(HomeTimePeriod.fromLux(999.9), HomeTimePeriod.afternoon);
      expect(HomeTimePeriod.fromLux(300), HomeTimePeriod.afternoon);
      expect(HomeTimePeriod.fromLux(299.9), HomeTimePeriod.evening);
      expect(HomeTimePeriod.fromLux(50), HomeTimePeriod.evening);
      expect(HomeTimePeriod.fromLux(49.9), HomeTimePeriod.lateEvening);
      expect(HomeTimePeriod.fromLux(0), HomeTimePeriod.lateEvening);
    });

    testWidgets('연결된 센서의 조도가 어두우면 접어 둬도 밤 배경이다', (tester) async {
      final sensors = await pumpHome(
        tester,
        connection: SensorConnection.active,
        lux: 20,
      );
      expect(sensors.requests, ['plant-a']);
      expect(background(HomeTimePeriod.lateEvening), findsOneWidget);
    });

    testWidgets('/home이 순간 조도를 주면 센서 상태를 바로 다시 받지 않는다', (tester) async {
      final sensors = await pumpHome(
        tester,
        connection: SensorConnection.active,
        roomLux: 20,
      );
      expect(sensors.requests, isEmpty);
      expect(background(HomeTimePeriod.lateEvening), findsOneWidget);
    });

    testWidgets('연결된 센서의 조도가 밝으면 낮 배경이다', (tester) async {
      await pumpHome(tester, connection: SensorConnection.active, lux: 1500);
      expect(background(HomeTimePeriod.day), findsOneWidget);
    });

    testWidgets('조도가 바뀌면 새 배경이 이전 배경 위로 서서히 드러난다', (tester) async {
      final sensors = await pumpHome(
        tester,
        connection: SensorConnection.active,
        lux: 1500,
      );
      sensors.lux = 20;
      // 접어 둔 홈은 60초마다 조도를 받는다.
      await tester.pump(const Duration(seconds: 60));
      await tester.pump(const Duration(milliseconds: 600));

      // 전환 중에는 두 배경이 겹쳐 있고, 나가는 낮 배경은 흐려지지 않는다.
      expect(background(HomeTimePeriod.day), findsOneWidget);
      expect(background(HomeTimePeriod.lateEvening), findsOneWidget);
      final incoming = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: background(HomeTimePeriod.lateEvening),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(incoming.opacity.value, inExclusiveRange(0, 1));
      final outgoing = find.ancestor(
        of: background(HomeTimePeriod.day),
        matching: find.byType(FadeTransition),
      );
      expect(
        tester
            .widgetList<FadeTransition>(outgoing)
            .map((fade) => fade.opacity.value),
        everyElement(1.0),
      );

      await tester.pump(AppMotion.periodCrossfade);
      expect(background(HomeTimePeriod.day), findsNothing);
      expect(background(HomeTimePeriod.lateEvening), findsOneWidget);
    });

    testWidgets('동작 줄이기를 켜면 배경을 바로 바꾼다', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final sensors = await pumpHome(
        tester,
        connection: SensorConnection.active,
        lux: 1500,
      );
      sensors.lux = 20;
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();

      expect(background(HomeTimePeriod.day), findsNothing);
      expect(background(HomeTimePeriod.lateEvening), findsOneWidget);
    });

    testWidgets('연결이 끊겼으면 조도를 받지 않고 시각으로 정한다', (tester) async {
      final sensors = await pumpHome(
        tester,
        connection: SensorConnection.stale,
        lux: 20,
      );
      expect(sensors.requests, isEmpty);
      expect(
        background(HomeTimePeriod.fromDateTime(DateTime.now())),
        findsOneWidget,
      );
    });

    testWidgets('연결돼도 조도 값이 없으면 시각으로 정한다', (tester) async {
      await pumpHome(tester, connection: SensorConnection.active);
      expect(
        background(HomeTimePeriod.fromDateTime(DateTime.now())),
        findsOneWidget,
      );
    });
  });

  testWidgets('평소 표정은 서버가 정한 표정을 따른다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          plantRepository: _FakePlantManagementRepository([
            _managedPlant('plant-a', '새싹이', selected: true),
          ]),
          loadHomeForPlant: (_) async => const HomeDashboardData(
            plant: HomePlantData(
              id: 'plant-a',
              nickname: '새싹이',
              personalityType: 'OUTGOING',
              colorId: 'color_orange',
              hairId: 'hair_sprout',
              expressionId: 'expression_sad',
              startedOn: '2026-05-01',
              daysTogether: 3,
              primaryPhotoUrl: null,
            ),
            room: HomeRoomData(
              backgroundPhase: 'DAY',
              dialogueKey: 'NORMAL',
              dialogue: '평소 대사',
            ),
            todayEvents: [],
            unreadLetterCount: 0,
            unreadNotificationCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final faces = tester
        .widgetList<PlantCharacterArt>(find.byType(PlantCharacterArt))
        .map((art) => art.expression);
    expect(faces, contains(PlantExpression.sad));
  });

  testWidgets('캐릭터를 탭하면 얼굴만 바뀌고 몸통·머리는 흐려지지 않는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          plantRepository: _FakePlantManagementRepository([
            _managedPlant('plant-a', '새싹이', selected: true),
          ]),
          loadHomeForPlant: (_) async => const HomeDashboardData(
            plant: HomePlantData(
              id: 'plant-a',
              nickname: '새싹이',
              personalityType: 'OUTGOING',
              colorId: 'color_orange',
              hairId: 'hair_sprout',
              expressionId: 'expression_sad',
              startedOn: '2026-05-01',
              daysTogether: 3,
              primaryPhotoUrl: null,
            ),
            room: HomeRoomData(
              backgroundPhase: 'DAY',
              dialogueKey: 'NORMAL',
              dialogue: '평소 대사',
            ),
            todayEvents: [],
            unreadLetterCount: 0,
            unreadNotificationCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 위젯 트리에서 위로 올라가며 투명도를 곱한다.
    double opacityOf(Element element) {
      var opacity = 1.0;
      for (final e in element.debugGetDiagnosticChain()) {
        final w = e.widget;
        if (w is FadeTransition) opacity *= w.opacity.value;
        if (w is Opacity) opacity *= w.opacity;
      }
      return opacity;
    }

    final character = find.byKey(const ValueKey('home-character-pet'));
    List<double> opacities(String label) => find
        .descendant(
          of: character,
          matching: find.byWidgetPredicate(
            (w) => w is Image && w.semanticLabel == label,
          ),
        )
        .evaluate()
        .map(opacityOf)
        .toList();

    await tester.tap(character);
    await tester.pump(); // 전환 시작 프레임
    // 표정 전환(200ms) 한가운데.
    await tester.pump(const Duration(milliseconds: 100));

    // 몸통·머리는 한 벌만 불투명하게 그대로 있다. 몸통째 크로스페이드하면
    // 반투명한 두 벌이 겹쳐 캐릭터가 유령처럼 비친다.
    expect(opacities('식물 친구 캐릭터'), [1.0]);
    expect(opacities('식물 머리'), [1.0]);
    // 얼굴은 슬픈 얼굴에서 기쁜 얼굴로 크로스페이드하는 중이다.
    final faces = find
        .descendant(
          of: character,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName.contains('/face_'),
          ),
        )
        .evaluate()
        .map((e) => ((e.widget as Image).image as AssetImage).assetName)
        .toList();
    expect(faces, hasLength(2));
    expect(faces.last, contains('happy'));

    await tester.pumpAndSettle();
  });

  testWidgets('센서 알림을 누르면 그 식물의 방으로 옮겨 게이지를 펼친다', (tester) async {
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
          period: HomeTimePeriod.day,
          initialGaugesExpanded: false,
          plantRepository: repository,
          loadHomeForPlant: (plantId) async => HomeDashboardData(
            plant: HomePlantData(
              id: plantId ?? 'plant-a',
              nickname: plantId == 'plant-b' ? '둘째' : '첫째',
              personalityType: 'OUTGOING',
              colorId: 'color_orange',
              hairId: 'hair_sprout',
              startedOn: '2026-05-01',
              daysTogether: 3,
              primaryPhotoUrl: null,
            ),
            room: null,
            todayEvents: const [],
            unreadLetterCount: 0,
            unreadNotificationCount: 1,
          ),
          notificationBuilder: (routeContext) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(routeContext).pop(
                NotificationData(
                  id: 'n-1',
                  plantId: 'plant-b',
                  type: 'SENSOR_SOIL_LOW',
                  title: '둘째의 흙이 말랐어요',
                  body: '물을 주세요.',
                  sourceType: 'SENSOR_EVENT',
                  sourceId: 'event-1',
                  readAt: DateTime(2026, 10, 2),
                  createdAt: DateTime(2026, 10, 2),
                ),
              ),
              child: const Text('센서 알림'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('기기연결이 필요합니다'), findsNothing, reason: '게이지는 접혀 있다');

    await tester.tap(find.byKey(const ValueKey('home-notifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('센서 알림'));
    await tester.pumpAndSettle();

    expect(repository.selectedIds, ['plant-b']);
    expect(find.text('둘째 방'), findsOneWidget);
    expect(find.text('기기연결이 필요합니다'), findsOneWidget, reason: '게이지가 펼쳐진다');
    expect(
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).activeIcon,
      FigmaNavIcon.home,
    );
  });

  group('홈 대사 큐', () {
    const queue = [
      HomeDialogueEvent(
        eventId: 'e-water',
        dialogueKey: 'WATERING_COMPLETED',
        dialogue: '물 고마워!',
        duration: Duration(seconds: 15),
      ),
      HomeDialogueEvent(
        eventId: 'e-letter',
        dialogueKey: 'LETTER_SENT',
        dialogue: '편지 보냈어!',
        duration: Duration(seconds: 10),
      ),
    ];

    Future<void> pumpQueueHome(
      WidgetTester tester, {
      bool gaugesExpanded = false,
      String dialogueKey = 'NORMAL',
      String dialogue = '오늘도 좋은 하루!',
      List<HomeDialogueEvent> events = queue,
    }) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: UniqueKey(),
            period: HomeTimePeriod.day,
            initialGaugesExpanded: gaugesExpanded,
            plantRepository: _FakePlantManagementRepository([
              _managedPlant('plant-a', '새싹이', selected: true),
            ]),
            loadHomeForPlant: (_) async => HomeDashboardData(
              plant: const HomePlantData(
                id: 'plant-a',
                nickname: '새싹이',
                personalityType: 'OUTGOING',
                colorId: 'color_orange',
                hairId: 'hair_sprout',
                startedOn: '2026-05-01',
                daysTogether: 3,
                primaryPhotoUrl: null,
              ),
              room: HomeRoomData(
                backgroundPhase: 'DAY',
                dialogueKey: dialogueKey,
                dialogue: dialogue,
                dialogueQueue: events,
              ),
              todayEvents: const [],
              unreadLetterCount: 0,
              unreadNotificationCount: 0,
            ),
          ),
        ),
      );
      // 기기에 남긴 "본 대사" 목록을 읽는 비동기 작업을 끝낸다.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    testWidgets('큐 대사를 순서대로 정해진 시간만큼 보여 주고, 끝나면 기본 대사로 돌아간다', (tester) async {
      await pumpQueueHome(tester);
      expect(find.text('물 고마워!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 15));
      expect(find.text('물 고마워!'), findsNothing);
      expect(find.text('편지 보냈어!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('편지 보냈어!'), findsNothing);
      expect(find.text('오늘도 좋은 하루!'), findsOneWidget);
    });

    testWidgets('한 번 보여 준 대사는 홈을 다시 열어도 다시 띄우지 않는다', (tester) async {
      await pumpQueueHome(tester);
      await tester.pump(const Duration(seconds: 25));

      await pumpQueueHome(tester);
      expect(find.text('물 고마워!'), findsNothing);
      expect(find.text('편지 보냈어!'), findsNothing);
      expect(find.text('오늘도 좋은 하루!'), findsOneWidget);
    });

    testWidgets('재생 중에 게이지를 펼치면 멈추고, 끝까지 못 본 대사는 다시 나온다', (tester) async {
      await pumpQueueHome(tester);
      expect(find.text('물 고마워!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      await tester.tap(find.byKey(const ValueKey('home-environment-card')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));

      await tester.tap(find.byKey(const ValueKey('home-environment-collapse')));
      await tester.pump();
      expect(find.text('물 고마워!'), findsOneWidget, reason: '봤음으로 저장되지 않았다');
    });

    testWidgets('돌봄 반응 말풍선이 뜨면 큐 대사는 비켜 준다', (tester) async {
      await pumpQueueHome(tester, dialogueKey: 'LIGHT_LOW', dialogue: '빛이 모자라');
      expect(find.text('물 고마워!'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-period-control')));
      await tester.pump();
      expect(find.text('아 따뜻해~고마워!'), findsOneWidget);
      expect(find.text('물 고마워!'), findsNothing);

      // 광선이 사라지면(3초 + 페이드) 멈춰 둔 큐 대사가 다시 나온다.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('물 고마워!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('큐 대사를 보여 준 뒤에는 진단 유도 대사를 띄우지 않는다', (tester) async {
      await pumpQueueHome(
        tester,
        dialogueKey: 'DIAGNOSIS_PROMPT',
        dialogue: '내 상태 좀 봐 줄래?',
        events: [queue.first],
      );
      await tester.pump(const Duration(seconds: 15));

      expect(find.text('물 고마워!'), findsNothing);
      expect(find.text('내 상태 좀 봐 줄래?'), findsNothing);
    });

    testWidgets('일기 권유 대사를 누르면 다이어리 탭으로 간다', (tester) async {
      await pumpQueueHome(
        tester,
        dialogueKey: 'DIARY_PROMPT',
        dialogue: '오늘 일기 써 줄래?',
        events: const [],
      );

      await tester.tap(
        find.byKey(const ValueKey('home-dialogue-prompt-DIARY_PROMPT')),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).activeIcon,
        FigmaNavIcon.diary,
      );
    });

    testWidgets('진단 권유 대사를 누르면 진단 화면으로 간다', (tester) async {
      await pumpQueueHome(
        tester,
        dialogueKey: 'DIAGNOSIS_PROMPT',
        dialogue: '내 상태 좀 봐 줄래?',
        events: const [],
      );

      await tester.tap(
        find.byKey(const ValueKey('home-dialogue-prompt-DIAGNOSIS_PROMPT')),
      );
      // 진단은 슬라이드 없이 한 번에 뜬다.
      await tester.pump();
      expect(
        ModalRoute.of(tester.element(find.byType(DiagnosisScreen))),
        isA<InstantPageRoute<void>>(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiagnosisScreen), findsOneWidget);
    });

    testWidgets('평소 대사는 눌러도 화면을 옮기지 않는다', (tester) async {
      await pumpQueueHome(tester, events: const []);

      expect(
        find.byKey(const ValueKey('home-dialogue-fallback')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'home-dialogue-prompt-',
              ),
        ),
        findsNothing,
      );
    });

    testWidgets('게이지가 펼쳐져 말풍선이 가려진 동안에는 재생하지 않는다', (tester) async {
      await pumpQueueHome(tester, gaugesExpanded: true);
      await tester.pump(const Duration(seconds: 30));

      await tester.tap(find.byKey(const ValueKey('home-environment-collapse')));
      await tester.pump();
      // 가려진 동안 시간이 지나도 소비되지 않고, 접은 뒤에야 첫 대사부터 나온다.
      expect(find.text('물 고마워!'), findsOneWidget);
    });
  });

  testWidgets('편지가 하나도 없어도 우편함을 누르면 빈 우편함이 열린다', (tester) async {
    useDeviceView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          period: HomeTimePeriod.day,
          plant: const HomePlant(
            id: 'plant-a',
            name: '첫째',
            startedOn: null,
            personalityType: null,
          ),
          plantRepository: _FakePlantManagementRepository([
            _managedPlant('plant-a', '첫째', selected: true),
          ]),
          letterRepository: _EmptyMailbox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-mailbox')));
    await tester.pumpAndSettle();

    expect(find.byType(MailboxScreen), findsOneWidget);
  });

  group('홈 모션 2차 (디자이너 답 5-A·7-B·9-B)', () {
    HomeDashboardData dashboard(String plantId, {SensorAssessment? sensor}) =>
        HomeDashboardData(
          plant: HomePlantData(
            id: plantId,
            nickname: plantId == 'plant-b' ? '둘째' : '첫째',
            personalityType: 'OUTGOING',
            colorId: 'color_orange',
            hairId: 'hair_sprout',
            startedOn: '2026-05-01',
            daysTogether: 3,
            primaryPhotoUrl: null,
          ),
          room: HomeRoomData(
            backgroundPhase: 'DAY',
            dialogueKey: 'NORMAL',
            dialogue: null,
            sensor: sensor,
          ),
          todayEvents: const [],
          unreadLetterCount: 0,
          unreadNotificationCount: 0,
        );

    Finder characters() => find.byKey(const ValueKey('home-character-pet'));

    testWidgets('> 를 누르면 지금 캐릭터는 왼쪽으로, 다음 캐릭터는 오른쪽에서 밀려 들어온다', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            period: HomeTimePeriod.day,
            plant: const HomePlant(
              id: 'plant-a',
              name: '첫째',
              startedOn: null,
              personalityType: null,
            ),
            initialGaugesExpanded: false,
            plantRepository: _FakePlantManagementRepository([
              _managedPlant('plant-a', '첫째', selected: true),
              _managedPlant('plant-b', '둘째'),
            ]),
            loadHomeForPlant: (plantId) async => dashboard(plantId!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final restingX = tester.getCenter(characters()).dx;

      await tester.tap(find.byKey(const ValueKey('home-next-plant')));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 150));

      // 전환 중에는 두 캐릭터가 함께 있고, 하나는 왼쪽·하나는 오른쪽에 있다.
      final xs = characters().evaluate().map((e) {
        final box = e.renderObject! as RenderBox;
        return box.localToGlobal(box.size.center(Offset.zero)).dx;
      }).toList()..sort();
      expect(xs, hasLength(2));
      expect(xs.first, lessThan(restingX - 20));
      expect(xs.last, greaterThan(restingX + 20));
      expect(find.text('첫째 방'), findsOneWidget);
      expect(find.text('둘째 방'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(characters(), findsOneWidget);
      expect(tester.getCenter(characters()).dx, moreOrLessEquals(restingX));
      expect(find.text('첫째 방'), findsNothing);
      expect(find.text('둘째 방'), findsOneWidget);
    });

    testWidgets('캐릭터를 좌우로 문지르는 동안 계속 흔들리고 웃는다', (tester) async {
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
            initialScene: HomeScene.idle,
            initialGaugesExpanded: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      Set<String> faces() => tester
          .widgetList<Image>(
            find.descendant(of: characters(), matching: find.byType(Image)),
          )
          .map((image) => (image.image as AssetImage).assetName)
          .where((asset) => asset.contains('/face_'))
          .toSet();
      bool tilted() => tester
          .widgetList<Transform>(
            find.descendant(of: characters(), matching: find.byType(Transform)),
          )
          .any((t) => t.transform.storage[1].abs() > 1e-4);

      final gesture = await tester.startGesture(tester.getCenter(characters()));
      var tiltedLate = false;
      // 1.6초 동안 좌우로 문지른다. 탭 한 번의 흔들림(550ms)보다 훨씬 길다.
      for (var i = 0; i < 16; i++) {
        await gesture.moveBy(Offset(i.isEven ? 30 : -30, 0));
        await tester.pump(const Duration(milliseconds: 100));
        if (i >= 8 && tilted()) tiltedLate = true;
      }
      expect(tiltedLate, isTrue);
      expect(faces(), contains(_happyFace));

      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(faces(), {_defaultFace});
    });

    testWidgets('조도·습도 게이지는 0에서 현재값까지 차오른다', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const sensor = SensorAssessment(
        connection: SensorConnection.active,
        soil: SensorMetricAssessment(
          state: SensorLevel.ok,
          unit: 'relative_percent',
          value: 60,
          lower: 40,
          upper: 90,
        ),
        light: SensorMetricAssessment(
          state: SensorLevel.ok,
          unit: 'lux_hours',
          value: 30000,
          lower: 60000,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            period: HomeTimePeriod.day,
            plantRepository: _FakePlantManagementRepository([
              _managedPlant('plant-a', '첫째', selected: true),
            ]),
            loadHomeForPlant: (_) async => dashboard('plant-a', sensor: sensor),
          ),
        ),
      );
      // 응답이 들어와 게이지가 처음 그려진 직후.
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      double fill() {
        final boxes = tester
            .widgetList<FractionallySizedBox>(
              find.descendant(
                of: find.byKey(const ValueKey('home-gauge-humidity')),
                matching: find.byType(FractionallySizedBox),
              ),
            )
            .toList();
        return boxes.last.widthFactor!;
      }

      expect(fill(), lessThan(0.1));
      await tester.pump(const Duration(milliseconds: 300));
      final mid = fill();
      expect(mid, greaterThan(0.05));
      expect(mid, lessThan(0.6));
      await tester.pumpAndSettle();
      expect(fill(), moreOrLessEquals(0.6));
    });
  });
}

/// 식물마다 다른 판정을 준다. 목록에 없는 식물은 기기가 없다.
class _PerPlantSensors implements SensorRepository {
  _PerPlantSensors(this.assessments);

  final Map<String, SensorAssessment> assessments;

  @override
  Future<PlantSensorStatus> getPlantSensorStatus(String plantId) async {
    final assessment =
        assessments[plantId] ??
        const SensorAssessment(
          connection: SensorConnection.noDevice,
          soil: SensorMetricAssessment(
            state: SensorLevel.unknown,
            unit: 'relative_percent',
          ),
          light: SensorMetricAssessment(
            state: SensorLevel.unknown,
            unit: 'lux_hours',
          ),
        );
    return PlantSensorStatus(
      plantId: plantId,
      connection: assessment.connection,
      latest: null,
      assessment: assessment,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSensorRepository implements SensorRepository {
  _FakeSensorRepository(this.assessment, {this.lux});

  final SensorAssessment assessment;
  double? lux;
  final requests = <String>[];

  @override
  Future<PlantSensorStatus> getPlantSensorStatus(String plantId) async {
    requests.add(plantId);
    return PlantSensorStatus(
      plantId: plantId,
      connection: assessment.connection,
      latest: lux == null
          ? null
          : SensorLatestReading(receivedAt: DateTime(2026, 10, 31), lux: lux),
      assessment: assessment,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this.items);

  final List<NotificationData> items;

  @override
  Future<NotificationPage> getNotifications({
    String? cursor,
    bool unreadOnly = false,
    int limit = 20,
  }) async => NotificationPage(items: items, nextCursor: null, hasNext: false);

  @override
  Future<NotificationData> markRead(String notificationId) async => items
      .firstWhere((item) => item.id == notificationId)
      .copyWith(readAt: DateTime(2026, 9, 25));

  @override
  Future<void> markAllRead() async {}

  @override
  Future<NotificationDevice> registerDevice({
    required NotificationDevicePlatform platform,
    required String installationId,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeDevice(String deviceId) => throw UnimplementedError();
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
  colorId: 'color_orange',
  hairId: 'hair_sprout',
  startedOn: DateTime.now()
      .toUtc()
      .add(const Duration(hours: 9))
      .subtract(const Duration(days: 3)),
  placeName: '거실',
  isSelected: selected,
);

class _ReadLetters implements PlantLetterRepository {
  @override
  Future<List<PlantLetter>> listLetters(String plantId) async => [
    PlantLetter(
      id: 'read-1',
      recipient: '나',
      sender: '첫째',
      body: '지난 편지',
      createdAt: DateTime(2026, 10, 1),
      isRead: true,
    ),
  ];

  @override
  Future<int> unreadCount(String plantId) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyMailbox implements PlantLetterRepository {
  @override
  Future<List<PlantLetter>> listLetters(String plantId) async => const [];

  @override
  Future<int> unreadCount(String plantId) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnreadLetters implements PlantLetterRepository {
  @override
  Future<int> unreadCount(String plantId) async => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlantManagementRepository implements PlantManagementRepository {
  _FakePlantManagementRepository(this.plants);

  List<ManagedPlant> plants;
  final List<String?> selectedIds = [];
  int listCalls = 0;

  /// 있으면 선택 저장이 이 신호를 받을 때까지 끝나지 않는다.
  Completer<void>? selectGate;

  @override
  Future<List<ManagedPlant>> listPlants() async {
    listCalls++;
    return plants;
  }

  @override
  Future<ManagedPlant> getPlant(String plantId) async =>
      plants.firstWhere((plant) => plant.id == plantId);

  @override
  Future<String?> selectPlant(String? plantId) async {
    selectedIds.add(plantId);
    await selectGate?.future;
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
    String? bodyId,
    String? colorId,
    String? hairId,
    String? expressionId,
  }) => throw UnimplementedError();

  @override
  Future<ManagedPlant> updatePlant(
    String plantId, {
    String? nickname,
    String? placeName,
    String? personalityType,
    DateTime? lastWateredOn,
    DateTime? lastRepottedOn,
  }) => throw UnimplementedError();
}
