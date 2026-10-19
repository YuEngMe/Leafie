import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/plant_detail_screen.dart';
import 'package:yeso_plant/screens/plant_edit_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_edit_info_screen.dart';
import 'package:yeso_plant/screens/plant_management_screen.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/color_wheel_picker.dart';
import 'package:yeso_plant/widgets/date_wheel_column.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/plant_detail_components.dart';
import 'package:yeso_plant/widgets/plant_search_components.dart';
import 'package:yeso_plant/widgets/svg_drop_shadow.dart';

/// 내 캐릭터(식물 관리) 흐름 8프레임의 좌표·색·문구를 시안과 맞춘다.
///
/// 프레임 402x874, 상태바 46, 하단 SafeArea 34. 시안 절대 y를 그대로 잰다.
/// - 4534:6665 전체보기_(옛 기준 2316:5103 전체보기_내 캐릭터)
/// - 4534:7390 캐릭터 상세 3(옛 기준 2564:947 캐릭터 상세 1)
/// - 2568:1926 삭제 모달
/// - 4889:2219 캐릭터 성격(편집, 옛 기준 2568:1714)
/// - 2555:661 / 2568:1639 정보수정 1·2
/// - 2568:1764 / 2568:1814 꾸미기 컬러·헤어

ManagedPlant _plant({
  String id = '1',
  String nickname = '새싹이',
  bool selected = true,
  String colorId = 'color_green',
  String personalityType = 'OUTGOING',
  int daysTogether = 128,
}) => ManagedPlant(
  id: id,
  nickname: nickname,
  speciesReferenceId: 'species-$id',
  speciesDisplayName: '몬스테라',
  primaryPhotoUrl: null,
  personalityType: personalityType,
  colorId: colorId,
  hairId: 'hair_sprout',
  startedOn: DateTime.now()
      .toUtc()
      .add(const Duration(hours: 9))
      // 등록한 날이 1일차라 N일째가 되려면 N-1일 전에 시작한다.
      .subtract(Duration(days: daysTogether - 1)),
  placeName: '거실',
  isSelected: selected,
);

class _FakeRepository implements PlantManagementRepository {
  DateTime? sentWateredOn;
  DateTime? sentRepottedOn;

  _FakeRepository(this.plants);

  List<ManagedPlant> plants;
  String? appearanceHairId;
  String? appearanceColor;
  String? appearanceBodyId;

  @override
  Future<List<ManagedPlant>> listPlants() async => List.of(plants);

  @override
  Future<ManagedPlant> getPlant(String plantId) async =>
      plants.firstWhere((plant) => plant.id == plantId);

  @override
  Future<String?> selectPlant(String? plantId) async {
    plants = [
      for (final plant in plants)
        plant.copyWith(isSelected: plant.id == plantId),
    ];
    return plantId;
  }

  @override
  Future<ManagedPlant> updatePlant(
    String plantId, {
    String? nickname,
    String? placeName,
    String? personalityType,
    DateTime? lastWateredOn,
    DateTime? lastRepottedOn,
  }) async {
    final plant = plants.firstWhere((item) => item.id == plantId);
    sentWateredOn = lastWateredOn;
    sentRepottedOn = lastRepottedOn;
    final updated = plant.copyWith(
      nickname: nickname,
      placeName: placeName,
      lastWateredOn: lastWateredOn,
      lastRepottedOn: lastRepottedOn,
    );
    if (personalityType == null) return updated;
    return ManagedPlant(
      id: updated.id,
      nickname: updated.nickname,
      speciesReferenceId: updated.speciesReferenceId,
      speciesDisplayName: updated.speciesDisplayName,
      primaryPhotoUrl: updated.primaryPhotoUrl,
      personalityType: personalityType,
      colorId: updated.colorId,
      hairId: updated.hairId,
      startedOn: updated.startedOn,
      category: updated.category,
      scientificName: updated.scientificName,
      familyName: updated.familyName,
      floweringPeriod: updated.floweringPeriod,
      placeName: updated.placeName,
      createdAt: updated.createdAt,
      updatedAt: updated.updatedAt,
      isSelected: updated.isSelected,
    );
  }

  @override
  Future<ManagedPlant> updateAppearance(
    String plantId, {
    String? bodyId,
    String? colorId,
    String? hairId,
    String? expressionId,
  }) async {
    appearanceHairId = hairId;
    appearanceColor = colorId;
    appearanceBodyId = bodyId;
    return plants
        .firstWhere((item) => item.id == plantId)
        .copyWith(bodyId: bodyId, colorId: colorId, hairId: hairId);
  }

  @override
  Future<void> deletePlant(String plantId) async =>
      plants = plants.where((item) => item.id != plantId).toList();
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  _setViewport(tester);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

Matcher _closeTo1px(double value) => closeTo(value, 1);

void main() {
  group('2316:5103 전체보기_내 캐릭터', () {
    testWidgets('앱바 제목과 노란 배경', (tester) async {
      await _pumpScreen(
        tester,
        PlantManagementScreen(repository: _FakeRepository([_plant()])),
      );

      // 2346:1873 "내 캐릭터". 시안 x=170 y=60 w=60.
      expect(find.text('내 캐릭터'), findsOneWidget);
      final title = tester.getRect(find.text('내 캐릭터'));
      expect(title.center.dx, _closeTo1px(201));
      expect(title.top, _closeTo1px(60));

      // 4534:6810 제목은 검정이다(공용 앱바 기본 #444).
      expect(
        tester.widget<Text>(find.text('내 캐릭터')).style!.color,
        Colors.black,
      );

      // 4534:6665 배경 #FFF6D4. 선반(4534:6699~6701)만 #FFECA6으로 남는다.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFFFF6D4));
      expect(kPlantsHouseYellow, const Color(0xFFFFECA6));
      final shelves = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == kPlantsHouseYellow,
      );
      expect(shelves, findsNWidgets(3));

      // 구름 오른쪽 작은 조각 4534:6809 x=290 y=131 23x14.
      final puff = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/images/plants_cloud_puff.svg',
        ),
      );
      expect(puff, const Rect.fromLTWH(290, 131, 23, 14));

      // 시안에 없는 요소는 사라졌다.
      expect(find.text('식물 관리'), findsNothing);
      expect(find.text('선택됨'), findsNothing);
      expect(find.text('이름 변경'), findsNothing);
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    });

    testWidgets('선반 3단 격자에 캐릭터가 앉고 다음 칸에 +가 온다', (tester) async {
      final repository = _FakeRepository([
        for (var i = 1; i <= 4; i++)
          _plant(id: '$i', nickname: '식물$i', selected: i == 1),
      ]);
      await _pumpScreen(tester, PlantManagementScreen(repository: repository));

      // 캐릭터 PNG는 캔버스에 투명 여백이 있어 그려지는 상자가 시안
      // 프레임(61.22)보다 크다. 그림 밑선이 선반에 닿는지를 잰다.
      // PlantCharacterArt 박스(width × 649/698)에서 circle 몸통은
      // 가로 89.7%, 아래 여백은 박스 높이의 37/649 = 5.70%.
      final drawn = plantArtWidthFor(61.219);
      final drawnHeight = drawn * 649 / 698;
      final inkBottomGap = drawnHeight * (649 - 612) / 649;

      // 4534:6665 몸통 중심. 옛 시안 98.5 / 305.5에서 안쪽으로 옮겼다.
      for (final entry in {'1': 105.0, '2': 200.5, '3': 297.0}.entries) {
        final rect = tester.getRect(
          find.byKey(ValueKey('plant_slot_${entry.key}')),
        );
        expect(rect.center.dx, _closeTo1px(entry.value));
        expect(rect.bottom - inkBottomGap, _closeTo1px(319));
        // 시안 캐릭터 61.22 폭이 실제로 그만큼 보이도록 그려진다.
        expect(rect.width * 0.897, _closeTo1px(61.219));
      }

      // 4번째는 2행 첫 칸. 선반 2는 y=441.
      final second = tester.getRect(find.byKey(const ValueKey('plant_slot_4')));
      expect(second.center.dx, _closeTo1px(105));
      expect(second.bottom - inkBottomGap, _closeTo1px(441));

      // + 는 다음 빈 칸(2행 2열)에 온다. 시안 4534:6811은 29x29 프레임이
      // 그림자 때문에 34.05로 그려진다. 원 중심은 선반보다 23.5 위
      // (3행 시안 539.5 = 563 − 23.5)라 2행에서는 441 − 23.5다.
      final plus = tester.getRect(find.byKey(const ValueKey('add_plant')));
      expect(plus.center.dx, _closeTo1px(200.5));
      expect(plus.center.dy, _closeTo1px(441 - 23.5));
      expect(plus.width, _closeTo1px(34.048));
      // flutter_svg는 SVG filter를 그리지 않아 흰 원이 배경에 묻힌다.
      // 시안 filter0_d_0_4 값으로 그림자를 따로 깐다.
      final shadow = tester.widget<SvgDropShadow>(
        find.descendant(
          of: find.byKey(const ValueKey('add_plant')),
          matching: find.byType(SvgDropShadow),
        ),
      );
      expect(shadow.stdDeviation, 1.26204);
      expect(shadow.opacity, 0.2);
    });

    testWidgets('하단 잔디가 화면 바닥에 붙는다 (4694:1454)', (tester) async {
      await _pumpScreen(
        tester,
        PlantManagementScreen(repository: _FakeRepository([_plant()])),
      );
      final grass = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/plants_house_grass.png',
      );
      expect(grass, findsOneWidget);
      final rect = tester.getRect(grass);
      // 새싹 top 774 ~ 프레임 바닥 874.
      expect(rect.top, _closeTo1px(774));
      expect(rect.bottom, _closeTo1px(874));
      expect(rect.width, _closeTo1px(402));
    });

    testWidgets('9칸이 다 차면 + 가 사라진다', (tester) async {
      final repository = _FakeRepository([
        for (var i = 1; i <= 9; i++)
          _plant(id: '$i', nickname: '식물$i', selected: i == 1),
      ]);
      await _pumpScreen(tester, PlantManagementScreen(repository: repository));

      expect(find.byKey(const ValueKey('add_plant')), findsNothing);
      expect(find.byKey(const ValueKey('plant_slot_9')), findsOneWidget);
    });
  });

  group('2564:947 캐릭터 상세 1', () {
    Future<void> pump(WidgetTester tester) => _pumpScreen(
      tester,
      PlantDetailScreen(
        plant: _plant(),
        repository: _FakeRepository([_plant()]),
      ),
    );

    testWidgets('잔디 밴드가 화면 바닥까지 이어진다(4534:7394 y=806)', (tester) async {
      await pump(tester);

      final band = tester.getRect(
        find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == kAppleGreen,
        ),
      );
      expect(band.top, _closeTo1px(806));
      expect(band.bottom, 874);
      expect(band.width, 402);
    });

    testWidgets('제목·닉네임·함께한 지·캐릭터 좌표', (tester) async {
      await pump(tester);

      // 2564:969 "캐릭터 편집" x=164 y=60 w=74.
      final appBarTitle = tester.getRect(find.text('캐릭터 편집'));
      expect(appBarTitle.center.dx, _closeTo1px(201));
      expect(appBarTitle.top, _closeTo1px(60));

      // 4534:7414 제목은 검정이다(공용 앱바 기본 #444).
      expect(
        tester.widget<Text>(find.text('캐릭터 편집')).style!.color,
        Colors.black,
      );

      // 4534:7430 닉네임 20 w600 #2E2E2E(옛 2564:1043은 21), 가운데 x 199.5.
      // Flutter 글자 상자는
      // 위 여백이 커서 상자를 시안 top 115보다 2px 위(113)에 둬야 보이는
      // 글자 꼭대기가 시안과 맞는다.
      final nickname = tester.getRect(find.text('새싹이'));
      expect(nickname.top, _closeTo1px(113));
      expect(nickname.center.dx, _closeTo1px(199.5));
      final nicknameStyle = tester.widget<Text>(find.text('새싹이')).style!;
      expect(nicknameStyle.fontSize, 20);
      expect(nicknameStyle.fontWeight, FontWeight.w600);
      expect(nicknameStyle.color, kPersonalityTitle);

      // 2564:1044 "함께한 지 128일째" top 146, 12/w400.
      final tenure = tester.getRect(find.text('함께한 지 128일째'));
      expect(tenure.top, _closeTo1px(146));
      final tenureStyle = tester.widget<Text>(find.text('함께한 지 128일째')).style!;
      expect(tenureStyle.fontSize, 12);
      expect(tenureStyle.color, kTextLight);
    });

    testWidgets('카드와 3행 메뉴 좌표·문구', (tester) async {
      await pump(tester);

      // 2564:1022 카드 라벨 x=52 y=481, 12/w400 #444.
      final cardLabel = tester.getRect(find.text('캐릭터 상세 정보'));
      expect(cardLabel.left, _closeTo1px(52));
      expect(cardLabel.top, _closeTo1px(481));
      expect(
        tester.widget<Text>(find.text('캐릭터 상세 정보')).style!.color,
        kTextDark,
      );

      // 4534:7420/7422/7425 글자 x=52, 시안 top 518.76 / 567.76 / 616.76.
      // Flutter 글자 상자는 위 여백이 2px 커서 상자를 2px 위에 둬야 보이는
      // 글자가 시안 자리에 온다.
      for (final entry in {
        '캐릭터 정보 수정': 518.762,
        '꾸미기': 567.762,
        '성격': 616.762,
      }.entries) {
        final rect = tester.getRect(find.text(entry.key));
        expect(rect.left, _closeTo1px(52), reason: entry.key);
        expect(rect.top, _closeTo1px(entry.value - 2), reason: entry.key);
        final style = tester.widget<Text>(find.text(entry.key)).style!;
        expect(style.fontSize, 16);
        expect(style.color, kTextDark);
      }

      // 2564:1027 휴지통 x=332 y=426 25.06x26.58.
      final trash = tester.getRect(find.byKey(const ValueKey('delete_plant')));
      expect(trash.left, _closeTo1px(332));
      expect(trash.top, _closeTo1px(426));
      expect(trash.width, _closeTo1px(25.057));
      expect(trash.height, _closeTo1px(26.576));
    });
  });

  group('2568:1926 삭제 모달', () {
    testWidgets('문구는 삭제하시겠습니까? / 네 / 아니오', (tester) async {
      await _pumpScreen(
        tester,
        PlantDetailScreen(
          plant: _plant(),
          repository: _FakeRepository([_plant()]),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('delete_plant')));
      await tester.pumpAndSettle();

      // 좌표가 같은 ConfirmDialog(2353:1045 계열)를 재사용한다.
      expect(find.byType(ConfirmDialog), findsOneWidget);
      expect(find.text('삭제하시겠습니까?'), findsOneWidget);
      expect(find.text('함께한지 128일이에요'), findsOneWidget);
      expect(find.text('네'), findsOneWidget);
      expect(find.text('아니오'), findsOneWidget);
      // 앱이 쓰던 Material 문구는 사라졌다.
      expect(find.text('식물 삭제'), findsNothing);
      expect(find.text('취소'), findsNothing);

      // 2568:1975 제목 16/w400 검정.
      final title = tester.widget<Text>(find.text('삭제하시겠습니까?')).style!;
      expect(title.fontSize, 16);
      expect(title.fontWeight, FontWeight.w400);
      expect(title.color, Colors.black);

      // 모달 박스 308x158.83. ConfirmDialog는 화면을 채우는 Dialog라
      // 안쪽 SizedBox를 잰다.
      final box = tester.getRect(
        find
            .descendant(
              of: find.byType(ConfirmDialog),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(box.width, _closeTo1px(308));
      expect(box.height, _closeTo1px(158.829));
    });
  });

  group('4889:2219 캐릭터 성격(편집)', () {
    testWidgets('이름·태그·캐릭터·말풍선·도트 좌표', (tester) async {
      await _pumpScreen(
        tester,
        PlantPersonalityScreen(plant: _plant(personalityType: 'OUTGOING')),
      );

      // 4889:2239 앱바 "캐릭터 성격".
      expect(find.text('캐릭터 성격'), findsOneWidget);

      // 옛 시안(2568:1714)으로 그려 요소가 20~33px 위에 있었다.
      // 4889:2258 성격 이름: 보이는 글자 꼭대기 156 → Flutter 상자 151.
      final label = tester.getRect(find.text('활발한 성격'));
      expect(label.top, _closeTo1px(151));
      expect(label.center.dx, _closeTo1px(201));

      // 4889:2254/2256 칩 y=190, 58.69x20.67.
      final firstTag = tester.getRect(find.text('#긍정적'));
      expect(firstTag.center.dy, _closeTo1px(190 + 20.667 / 2));
      expect(find.text('#에너지'), findsOneWidget);

      // 4889:2267 캐릭터: 몸통(4889:2271) 폭 139, 바닥 488.85.
      final art = tester.getRect(find.byType(PlantCharacterArt).first);
      expect(art.width * 0.897, closeTo(139, 0.5));
      expect(art.center.dx, _closeTo1px(201));
      expect(art.bottom - art.width * 37 / 698, _closeTo1px(488.85));

      // 4889:2260 꼬리 달린 말풍선: 그림자 여백 포함 SVG 261.25x55.31,
      // top 500.55. 글자 가운데 y=532.23.
      final bubble = tester.getRect(
        find
            .byWidgetPredicate(
              (w) =>
                  w is SvgPicture &&
                  w.bytesLoader is SvgAssetLoader &&
                  (w.bytesLoader as SvgAssetLoader).assetName ==
                      'assets/images/personality_bubble.svg',
            )
            .first,
      );
      expect(bubble.top, _closeTo1px(500.55));
      expect(bubble.width, _closeTo1px(261.25));
      expect(bubble.center.dx, _closeTo1px(201));
      final dialogue = tester.getRect(find.text('오늘도 같이 놀자!'));
      expect(dialogue.center.dy, _closeTo1px(532.23));

      // 4889:2246 도트 y=590.73.
      final dotsFinder = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_PersonalityDots',
      );
      expect(tester.getRect(dotsFinder).top, _closeTo1px(590.73));

      // 4889:2265 하단 버튼 문구 "선택". 선택한 성격을 반환하는 활성 버튼이다.
      expect(find.text('선택'), findsOneWidget);
      expect(find.text('수정하기'), findsNothing);
      final button = tester.widget<PlantDetailBottomAction>(
        find.byType(PlantDetailBottomAction),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('도트를 탭하면 다음 성격으로 넘어가고 선택이 그 값을 반환한다', (tester) async {
      await _pumpScreen(
        tester,
        PlantPersonalityScreen(plant: _plant(personalityType: 'OUTGOING')),
      );

      // OUTGOING(0) 다음 도트를 눌러 CHIC(1)으로 옮긴다.
      final dotsFinder = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_PersonalityDots',
      );
      final gestureDetectors = find.descendant(
        of: dotsFinder,
        matching: find.byType(GestureDetector),
      );
      await tester.tap(gestureDetectors.at(1));
      await tester.pumpAndSettle();

      expect(find.text('시크한 성격'), findsOneWidget);
      expect(find.text('됐어. 그냥 있어.'), findsOneWidget);

      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
    });
  });

  group('2555:661 / 2568:1639 정보수정', () {
    Future<void> pump(WidgetTester tester) => _pumpScreen(
      tester,
      PlantEditInfoScreen(
        plant: _plant(),
        repository: _FakeRepository([_plant()]),
      ),
    );

    testWidgets('4필드 라벨 좌표와 입력칸 크기', (tester) async {
      await pump(tester);

      // 2555:694 앱바. 4534:20090 제목은 검정이다(공용 앱바 기본 #444).
      expect(find.text('캐릭터 정보 수정'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('캐릭터 정보 수정')).style!.color,
        Colors.black,
      );

      // 라벨 x=45, top 145 / 255 / 365 / 475 (2555:688/698/703/708).
      for (final entry in {
        '닉네임': 145.0,
        '장소(별명)': 255.0,
        '마지막 물 준 날': 365.0,
        '분갈이 한 날': 475.0,
      }.entries) {
        final rect = tester.getRect(find.text(entry.key));
        expect(rect.left, _closeTo1px(45), reason: entry.key);
        expect(rect.top, _closeTo1px(entry.value), reason: entry.key);
        expect(
          tester.widget<Text>(find.text(entry.key)).style!.color,
          kOrangeMain,
          reason: entry.key,
        );
      }

      // 입력칸 x=34 w=334 h=51 (2555:689 등).
      for (final key in [
        'plant_nickname_field',
        'plant_place_field',
        'plant_watered_field',
        'plant_repotted_field',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.left, _closeTo1px(34), reason: key);
        expect(rect.width, _closeTo1px(334), reason: key);
        expect(rect.height, _closeTo1px(51), reason: key);
      }

      expect(find.text('예: 베란다'), findsOneWidget);
      // 관리 기록이 없는 식물은 날짜 칸이 비어 있고 고르도록 안내한다.
      expect(find.text('선택하기'), findsNWidgets(2));

      // 2555:691 하단 버튼 x=34 w=334 h=51.
      final button = tester.getRect(find.text('수정하기'));
      expect(button.center.dx, _closeTo1px(201));
    });

    testWidgets('저장된 날짜를 보여 주고, 바꾼 날짜만 PATCH로 보낸다', (tester) async {
      final plant = _plant().copyWith(
        lastWateredOn: DateTime(2026, 9, 20),
        lastRepottedOn: DateTime(2026, 3, 2),
      );
      final repository = _FakeRepository([plant]);
      await _pumpScreen(
        tester,
        PlantEditInfoScreen(plant: plant, repository: repository),
      );
      expect(find.text('2026년 9월 20일'), findsOneWidget);
      expect(find.text('2026년 3월 2일'), findsOneWidget);

      // 분갈이 날 칸을 눌러 시트를 열고, 휠을 하루 위로 올려 3월 1일을 고른다.
      await tester.tap(find.byKey(const ValueKey('plant_repotted_field')));
      await tester.pumpAndSettle();
      expect(find.byType(PlantDatePickerSheet), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('date_day_wheel')),
        // 드래그 인식 여유(kDragSlopDefault 20)만큼 더 끈다.
        const Offset(0, PlantDatePickerSheet.rowExtent + kDragSlopDefault),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(PlantDatePickerSheet),
          matching: find.text('수정하기'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2026년 3월 1일'), findsOneWidget);

      await tester.tap(find.text('수정하기'));
      await tester.pumpAndSettle();

      // 바꾸지 않은 물 준 날은 보내지 않는다.
      expect(repository.sentWateredOn, isNull);
      expect(repository.sentRepottedOn, DateTime(2026, 3, 1));
    });

    testWidgets('기록이 없는 날짜도 시트에서 골라 저장한다', (tester) async {
      final repository = _FakeRepository([_plant()]);
      await _pumpScreen(
        tester,
        PlantEditInfoScreen(plant: _plant(), repository: repository),
      );

      await tester.tap(find.byKey(const ValueKey('plant_watered_field')));
      await tester.pumpAndSettle();
      // 기록이 없으면 오늘에서 시작한다. 그대로 확정한다.
      await tester.tap(
        find.descendant(
          of: find.byType(PlantDatePickerSheet),
          matching: find.text('수정하기'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정하기'));
      await tester.pumpAndSettle();

      final today = DateTime.now();
      final sent = repository.sentWateredOn!;
      expect(
        DateTime(sent.year, sent.month, sent.day),
        DateTime(today.year, today.month, today.day),
      );
      expect(repository.sentRepottedOn, isNull);
    });

    testWidgets('4534:20068 뒤로 꺾쇠는 주황', (tester) async {
      await pump(tester);

      // 4534:20185 Polygon 4 (Stroke) fill #FFB52A.
      expect(
        tester.widget<FigmaBackChevron>(find.byType(FigmaBackChevron)).color,
        kOrangeMain,
      );
    });

    testWidgets('4534:20112 날짜 시트: 딤 없음·핸들바 없음·띠 색', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('plant_watered_field')));
      await tester.pumpAndSettle();

      // 시안은 시트 뒤 화면을 어둡게 덮지 않는다. 투명 딤이면 라우트가
      // 색 없는 ModalBarrier를 깐다.
      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.color?.a ?? 0, 0);

      // 회색 핸들바(4534:20157)는 시안에서 시트 아래에 깔려 보이지 않는다.
      final handles = find.descendant(
        of: find.byType(PlantDatePickerSheet),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  const Color(0xFF8E8E8E),
        ),
      );
      expect(handles, findsNothing);

      // 4534:20178 띠 rgba(255,197,136,0.42), (1, 647.66) 399.954x39.686.
      // 그림자는 띠 바깥에만 그려 반투명 바탕 밑으로 비치지 않는다.
      final band = find.descendant(
        of: find.byType(PlantDatePickerSheet),
        matching: find.byType(DateWheelHighlight),
      );
      final bandRect = tester.getRect(band);
      expect(bandRect.left, closeTo(1, .01));
      expect(bandRect.top, closeTo(647.664, .01));
      expect(bandRect.width, closeTo(399.954, .01));
      expect(bandRect.height, closeTo(39.686, .01));
      expect(
        tester.widget<DateWheelHighlight>(band).color,
        const Color(0x6BFFC588),
      );
    });

    testWidgets('4534:20112 날짜 휠: 열 x와 고른 줄 위아래 간격', (tester) async {
      // 위아래 두 줄씩 다 보이도록 열마다 가운데 값을 고른다.
      final year = DateTime.now().year - 2;
      final plant = _plant().copyWith(lastRepottedOn: DateTime(year, 6, 15));
      await _pumpScreen(
        tester,
        PlantEditInfoScreen(plant: plant, repository: _FakeRepository([plant])),
      );
      await tester.tap(find.byKey(const ValueKey('plant_repotted_field')));
      await tester.pumpAndSettle();

      // 시트 안에서 화면에 보이는 줄(시트 549~790)만 고른다.
      List<Rect> rows(String wheelKey) {
        final rects = find
            .descendant(
              of: find.byKey(ValueKey(wheelKey)),
              matching: find.byType(Text),
            )
            .evaluate()
            .map((element) => tester.getRect(find.byWidget(element.widget)))
            .where((rect) => rect.center.dy > 560 && rect.center.dy < 780)
            .toList();
        return rects..sort((a, b) => a.top.compareTo(b.top));
      }

      // 4534:20161~20182 글자 중심 y. 고른 줄 위 45.03, 아래 47.18,
      // 나머지 38.61 간격이다.
      const centers = [582.79, 621.40, 666.43, 713.61, 752.23];
      for (final key in [
        'date_year_wheel',
        'date_month_wheel',
        'date_day_wheel',
      ]) {
        final visible = rows(key);
        expect(visible.length, 5, reason: key);
        for (var i = 0; i < 5; i++) {
          expect(visible[i].center.dy, _closeTo1px(centers[i]), reason: key);
        }
      }

      // 연도는 왼쪽 정렬 x=60(고른 줄 60.33), 월·일은 중심 201.16 / 320.84.
      for (final rect in rows('date_year_wheel')) {
        expect(rect.left, _closeTo1px(60));
      }
      for (final rect in rows('date_month_wheel')) {
        expect(rect.center.dx, _closeTo1px(201.16));
      }
      for (final rect in rows('date_day_wheel')) {
        expect(rect.center.dx, _closeTo1px(320.84));
      }
    });
  });

  group('5038:6460 꾸미기', () {
    Future<void> pump(WidgetTester tester) => _pumpScreen(
      tester,
      PlantEditAppearanceScreen(
        plant: _plant(),
        repository: _FakeRepository([_plant()]),
      ),
    );

    testWidgets('앱바·바디 스위처·컬러 휠·체크 배지 좌표', (tester) async {
      await pump(tester);

      // 5038:6523 앱바.
      expect(find.text('캐릭터 꾸미기'), findsOneWidget);
      // 5038:6460 시안: 헤드라인 자리에 바디 스위처가 온다(헤드라인 없음).
      expect(find.text('식물을 꾸며주세요!'), findsNothing);
      // 바디 스위처는 앱바 아래 top 143, 화면 중앙 정렬(dx≈201).
      final bodyRow = tester.getRect(
        find.byKey(const ValueKey('appearance_body_circle')),
      );
      expect(bodyRow.top, _closeTo1px(143));
      final square = tester.getRect(
        find.byKey(const ValueKey('appearance_body_square')),
      );
      // 3개 실루엣이 중앙 대칭: circle(왼)·square(오) 중심이 201 기준 대칭.
      expect((bodyRow.center.dx + square.center.dx) / 2, _closeTo1px(201));
      // 6049:2649(디자이너 수정 "아이콘 크기"): 묶음 6049:2698이
      // x 148..253.96으로 1.22배 커졌다. 아이콘 약 27, 간격 12.22.
      expect(bodyRow.left, _closeTo1px(148));
      expect(bodyRow.width, _closeTo1px(27));
      expect(square.right, _closeTo1px(253.96));

      // 컬러 휠 5038:6533은 등록 꾸미기(4534:507)와 같은 위젯이다. 휠
      // 위에 '컬러' 라벨(5038:6551)이 있고, 헤어 탭은 없다.
      expect(find.byType(ColorWheelPicker), findsOneWidget);
      expect(find.text('헤어'), findsNothing);
      // 라벨 글자 상자는 x 189..211, 가운데 y 601.
      final label = tester.getRect(find.text('컬러'));
      expect(label.center.dx, _closeTo1px(200));
      expect(label.center.dy, _closeTo1px(601));

      // 초기 색(green)이 꼭대기 칸(원 중심 200, 655, 지름 60)에 있다.
      final top = tester.getRect(
        find.byKey(const ValueKey('appearance_color_green')),
      );
      expect(top.center.dx, _closeTo1px(200));
      expect(top.center.dy, _closeTo1px(655));
      expect(top.width, _closeTo1px(60));
      // 시계 방향 옆 칸(5038:6395 Ellipse 453): 중심 (288, 679).
      final next = tester.getRect(
        find.byKey(const ValueKey('appearance_color_sky')),
      );
      expect(next.center.dx, _closeTo1px(288));
      expect(next.center.dy, _closeTo1px(679));

      // 5038:6557 체크 배지. 원 38x38이 x=181 y=777(중심 200, 796)이고,
      // SVG는 그림자까지 46x46으로 그려진다. 옛 시안(2568:1811)은 y=760이었다.
      final check = tester.getRect(
        find.byKey(const ValueKey('appearance_confirm')),
      );
      expect(check.center.dx, _closeTo1px(181 + 19));
      expect(check.center.dy, _closeTo1px(777 + 19));
      expect(check.width, _closeTo1px(46));

      // 앱에만 있던 요소는 사라졌다.
      expect(find.text('적용하기'), findsNothing);
      expect(find.text('헤어와 액세서리는 디자인 확정 후 추가돼요.'), findsNothing);
    });

    testWidgets('휠은 공용 10색 목록을 그리고 초기 선택이 꼭대기에 있다', (tester) async {
      await pump(tester);

      // 휠은 10색을 모두 둘레에 그린다 — 디자이너 확정 10색(2026-09-20).
      final picker = tester.widget<ColorWheelPicker>(
        find.byType(ColorWheelPicker),
      );
      final labels = [for (final c in picker.colors) c.label];
      expect(labels.length, 10);
      expect(labels, containsAll(const ['레드', '오렌지', '옐로', '라이트 그린', '그린']));
      expect(labels, containsAll(const ['스카이', '블루', '퍼플', '핑크', '화이트']));

      // 초기 선택(green)이 선택 링(5038:6548, 74x74 y=618) 안에 있다.
      expect(
        tester
            .getRect(find.byKey(const ValueKey('appearance_color_green')))
            .center
            .dy,
        _closeTo1px(618 + 37),
      );
    });

    testWidgets('뒤쪽 색(화이트 방향)을 밀어서 고를 수 있다', (tester) async {
      final repository = _FakeRepository([_plant()]);
      await _pumpScreen(
        tester,
        PlantEditAppearanceScreen(plant: _plant(), repository: repository),
      );

      // 초기 선택은 green(index 4). 휠은 끝없이 돌아서 왼쪽으로(음의 드래그)
      // 한 칸(88px)씩 밀면 목록 끝을 지나 다시 orange(index 1)까지 감긴다.
      final wheel = find.byType(ColorWheelPicker);
      for (var i = 0; i < 7; i++) {
        await tester.drag(wheel, const Offset(-88, 0));
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const ValueKey('appearance_color_orange')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('appearance_color_orange')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('appearance_confirm')));
      await tester.pumpAndSettle();

      expect(repository.appearanceColor, 'color_orange');
    });

    testWidgets('휠은 양방향으로 돈다 — 초기 색에서 오른쪽으로 밀면 앞쪽 색(오렌지)이 온다', (tester) async {
      final repository = _FakeRepository([_plant()]);
      await _pumpScreen(
        tester,
        PlantEditAppearanceScreen(plant: _plant(), repository: repository),
      );

      // 초기 선택은 green(index 4). 오른쪽으로 한 칸씩 밀면 앞쪽 색이
      // 꼭대기로 와 orange(index 1)에 닿는다(4→3→2→1).
      final wheel = find.byType(ColorWheelPicker);
      for (var i = 0; i < 3; i++) {
        await tester.drag(wheel, const Offset(88, 0));
        await tester.pumpAndSettle();
      }
      // orange가 꼭대기 칸(중심 y 655)에 와 있다.
      expect(
        tester
            .getRect(find.byKey(const ValueKey('appearance_color_orange')))
            .center
            .dy,
        _closeTo1px(655),
      );
      await tester.tap(
        find.byKey(const ValueKey('appearance_color_orange')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('appearance_confirm')));
      await tester.pumpAndSettle();

      // onSelected가 무한 페이지 인덱스가 아니라 0..9로 정규화된 실제 색
      // id를 넘긴다(색 저장이 깨지지 않는다).
      expect(repository.appearanceColor, 'color_orange');
    });

    testWidgets('헤어는 고를 수 없지만 현재 값이 미리보기에 얹힌다', (tester) async {
      await pump(tester);

      // 헤어 스와치/피커가 전혀 없다(헤어는 종으로 자동 결정).
      for (final id in const [
        'hair_sunflower',
        'hair_cherry_tomato',
        'hair_hydrangea',
        'hair_pointed_succulent',
        'hair_monstera',
        'hair_flower_cactus',
        'hair_rosette_succulent',
        'hair_sprout',
        'hair_daisy',
      ]) {
        expect(find.byKey(ValueKey('appearance_$id')), findsNothing);
      }

      // 캐릭터 미리보기는 하나이고, 그 안에 종으로 결정된 헤어가 얹혀 그려진다.
      final art = tester.widget<PlantCharacterArt>(
        find.byType(PlantCharacterArt),
      );
      expect(art.hairId, 'hair_sprout');
    });

    testWidgets('컬러만 바꿔도 헤어는 현재 값을 함께 실어 보내 누락을 막는다', (
      tester,
    ) async {
      final repository = _FakeRepository([_plant()]);
      await _pumpScreen(
        tester,
        PlantEditAppearanceScreen(plant: _plant(), repository: repository),
      );

      // 초기 green(index 4)에서 바로 보이는 인접 색 sky(index 5)로 바꾼다.
      await tester.tap(find.byKey(const ValueKey('appearance_color_sky')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('appearance_confirm')));
      await tester.pumpAndSettle();

      // 헤어는 이 화면에서 못 고르지만 종으로 결정된 현재 값을 그대로 싣는다.
      expect(repository.appearanceHairId, 'hair_sprout');
      // 바디를 안 바꿨으면 body_id는 싣지 않는다(부분 PATCH).
      expect(repository.appearanceBodyId, isNull);
    });

    testWidgets('바디만 바꾸고 적용하면 updateAppearance에 body_id만 전달된다', (
      tester,
    ) async {
      final repository = _FakeRepository([_plant()]);
      await _pumpScreen(
        tester,
        PlantEditAppearanceScreen(plant: _plant(), repository: repository),
      );

      // 초기 body_circle에서 body_thumb(통통이)로 바꾼다.
      await tester.tap(find.byKey(const ValueKey('appearance_body_thumb')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('appearance_confirm')));
      await tester.pumpAndSettle();

      expect(repository.appearanceBodyId, 'body_thumb');
      // 색은 안 바꿨으니 color_id는 싣지 않는다(부분 PATCH).
      expect(repository.appearanceColor, isNull);
    });
  });
}
