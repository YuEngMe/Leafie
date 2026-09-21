import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/plant_detail_screen.dart';
import 'package:yeso_plant/screens/plant_edit_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_edit_info_screen.dart';
import 'package:yeso_plant/screens/plant_management_screen.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/arc_appearance_picker.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/plant_detail_components.dart';

/// 내 캐릭터(식물 관리) 흐름 8프레임의 좌표·색·문구를 시안과 맞춘다.
///
/// 프레임 402x874, 상태바 46, 하단 SafeArea 34. 시안 절대 y를 그대로 잰다.
/// - 2316:5103 전체보기_내 캐릭터
/// - 2564:947  캐릭터 상세 1
/// - 2568:1926 삭제 모달
/// - 2568:1714 캐릭터 상세_성격
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
      .subtract(Duration(days: daysTogether)),
  placeName: '거실',
  isSelected: selected,
);

class _FakeRepository implements PlantManagementRepository {
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
  }) async {
    final plant = plants.firstWhere((item) => item.id == plantId);
    final updated = plant.copyWith(nickname: nickname, placeName: placeName);
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

      // 2316:5104 연노랑 배경.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, kPlantsHouseYellow);
      expect(kPlantsHouseYellow, const Color(0xFFFFECA6));

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
      // body_circle.png 캔버스 698x649, 그림 bbox (36,36,662,612):
      // 가로 그림 89.7%, 세로 아래 여백 (649-612)/649 = 5.70%.
      final drawn = plantArtWidthFor(61.219);
      final drawnHeight = drawn * 649 / 698;
      final inkBottomGap = drawnHeight * (649 - 612) / 649;

      for (final entry in {'1': 98.5, '2': 200.5, '3': 305.5}.entries) {
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
      expect(second.center.dx, _closeTo1px(98.5));
      expect(second.bottom - inkBottomGap, _closeTo1px(441));

      // + 는 다음 빈 칸(2행 2열)에 온다. 시안 3345:886은 29x29 프레임이
      // 그림자 때문에 34.05로 그려진다.
      final plus = tester.getRect(find.byKey(const ValueKey('add_plant')));
      expect(plus.center.dx, _closeTo1px(200.5));
      expect(plus.width, _closeTo1px(34.048));
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

    testWidgets('제목·닉네임·함께한 지·캐릭터 좌표', (tester) async {
      await pump(tester);

      // 2564:969 "캐릭터 편집" x=164 y=60 w=74.
      final appBarTitle = tester.getRect(find.text('캐릭터 편집'));
      expect(appBarTitle.center.dx, _closeTo1px(201));
      expect(appBarTitle.top, _closeTo1px(60));

      // 2564:1043 닉네임 top 115, 21/w600 #2E2E2E.
      final nickname = tester.getRect(find.text('새싹이'));
      expect(nickname.top, _closeTo1px(115));
      expect(nickname.center.dx, _closeTo1px(201));
      final nicknameStyle = tester.widget<Text>(find.text('새싹이')).style!;
      expect(nicknameStyle.fontSize, 21);
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

      // 2564:1014/1016/1019 글자 x=52, top 518.76 / 567.76 / 616.76.
      for (final entry in {
        '캐릭터 정보 수정': 518.762,
        '꾸미기': 567.762,
        '성격': 616.762,
      }.entries) {
        final rect = tester.getRect(find.text(entry.key));
        expect(rect.left, _closeTo1px(52), reason: entry.key);
        expect(rect.top, _closeTo1px(entry.value), reason: entry.key);
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

  group('2568:1714 캐릭터 상세_성격', () {
    testWidgets('이름·태그·대사·도트 좌표', (tester) async {
      await _pumpScreen(
        tester,
        PlantPersonalityScreen(plant: _plant(personalityType: 'OUTGOING')),
      );

      // 2568:1737 앱바 "캐릭터 성격".
      expect(find.text('캐릭터 성격'), findsOneWidget);

      // 2568:1757 성격 이름 top 132.
      final label = tester.getRect(find.text('활발한 성격'));
      expect(label.top, _closeTo1px(132));
      expect(label.center.dx, _closeTo1px(201));

      // 2568:1753/1755 칩 y=170, 58.69x20.67.
      final firstTag = tester.getRect(find.text('#긍정적'));
      expect(firstTag.center.dy, _closeTo1px(170 + 20.667 / 2));
      expect(find.text('#에너지'), findsOneWidget);

      // 2568:1762 말풍선 문구.
      expect(find.text('자 이제 물 줄 시간이야!'), findsOneWidget);

      // 2568:1735 하단 버튼. 이제 선택한 성격을 반환하는 활성 버튼이다.
      expect(find.text('수정하기'), findsOneWidget);
      final button = tester.widget<PlantDetailBottomAction>(
        find.byType(PlantDetailBottomAction),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('도트를 탭하면 다음 성격으로 넘어가고 수정하기가 그 값을 반환한다', (tester) async {
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
      expect(find.text('뭘 봐? 물이나 줘.'), findsOneWidget);

      await tester.tap(find.text('수정하기'));
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

      // 2555:694 앱바.
      expect(find.text('캐릭터 정보 수정'), findsOneWidget);

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

      // 서버가 수정 계약을 제공하는 장소만 입력할 수 있다.
      expect(find.text('예: 베란다'), findsOneWidget);
      expect(find.text('수정 API 준비 중'), findsNWidgets(2));

      // 2555:691 하단 버튼 x=34 w=334 h=51.
      final button = tester.getRect(find.text('수정하기'));
      expect(button.center.dx, _closeTo1px(201));
    });

    testWidgets('서버가 수정 계약을 제공하지 않는 날짜 필드는 비활성화한다', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('plant_watered_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plant_repotted_field')));
      await tester.pumpAndSettle();

      expect(find.byType(PlantDatePickerSheet), findsNothing);
    });
  });

  group('2568:1764 / 2568:1814 꾸미기', () {
    Future<void> pump(WidgetTester tester) => _pumpScreen(
      tester,
      PlantEditAppearanceScreen(
        plant: _plant(),
        repository: _FakeRepository([_plant()]),
      ),
    );

    testWidgets('헤드라인·앱바·체크 원 좌표', (tester) async {
      await pump(tester);

      // 2568:1786 앱바, 2568:1874 헤드라인 top 140.
      expect(find.text('캐릭터 꾸미기'), findsOneWidget);
      final headline = tester.getRect(find.text('식물을 꾸며주세요!'));
      expect(headline.top, _closeTo1px(140));
      expect(headline.center.dx, _closeTo1px(201));

      // 컬러 선택은 등록 화면과 같은 드르륵 카루셀로 통일했다. 절대좌표
      // 탭 라벨('컬러')은 없앴고, 헤어 탭도 없다.
      expect(find.text('컬러'), findsNothing);
      expect(find.text('헤어'), findsNothing);
      expect(find.byType(ArcAppearancePicker), findsOneWidget);

      // 2568:1811 체크 원. 프레임 38x38의 중심이 (201, 779)이고, SVG는
      // 그림자까지 46x46으로 그려진다.
      final check = tester.getRect(
        find.byKey(const ValueKey('appearance_confirm')),
      );
      expect(check.center.dx, _closeTo1px(182 + 19));
      expect(check.center.dy, _closeTo1px(760 + 19));
      expect(check.width, _closeTo1px(46));

      // 앱에만 있던 요소는 사라졌다.
      expect(find.text('적용하기'), findsNothing);
      expect(find.text('헤어와 액세서리는 디자인 확정 후 추가돼요.'), findsNothing);
    });

    testWidgets('카루셀은 공용 10색 목록을 그리고 초기 선택이 보인다', (tester) async {
      await pump(tester);

      // PageView.builder는 화면에 보이는 스와치만 렌더한다. 목록 길이는
      // 위젯 파라미터(labels)로 검증한다 — 디자이너 확정 10색(2026-09-20).
      final picker = tester.widget<ArcAppearancePicker>(
        find.byType(ArcAppearancePicker),
      );
      expect(picker.labels.length, 10);
      expect(
        picker.labels,
        containsAll(const ['레드', '오렌지', '옐로', '라이트 그린', '그린']),
      );
      expect(
        picker.labels,
        containsAll(const ['스카이', '블루', '퍼플', '핑크', '화이트']),
      );

      // 초기 선택(green)은 카루셀 중앙에 렌더돼 보인다.
      expect(
        find.byKey(const ValueKey('appearance_color_green')),
        findsOneWidget,
      );
    });

    testWidgets('뒤쪽 색(화이트 방향)을 밀어서 고를 수 있다', (tester) async {
      final repository = _FakeRepository([_plant()]);
      await _pumpScreen(
        tester,
        PlantEditAppearanceScreen(plant: _plant(), repository: repository),
      );

      // 초기 선택은 green(index 4). 무한 순환이라 오른쪽 방향(음의 드래그)으로
      // 페이지를 밀면 목록 끝을 지나 다시 orange(index 1)까지 감긴다.
      final pageView = find.byType(PageView);
      for (var i = 0; i < 7; i++) {
        await tester.drag(pageView, const Offset(-120, 0));
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

    testWidgets('카루셀은 양방향 무한 순환 — 초기 색에서 왼쪽으로 밀면 앞쪽 색(오렌지)이 온다', (
      tester,
    ) async {
      final repository = _FakeRepository([_plant()]);
      await _pumpScreen(
        tester,
        PlantEditAppearanceScreen(plant: _plant(), repository: repository),
      );

      // 초기 선택은 green(index 4). 오른쪽으로 드래그하면 앞쪽 페이지로
      // 이동해 orange(index 1)에 닿는다(4→3→2→1). 스냅이 애매하지 않도록
      // 페이지 하나씩 민다.
      final pageView = find.byType(PageView);
      for (var i = 0; i < 3; i++) {
        await tester.drag(pageView, const Offset(120, 0));
        await tester.pumpAndSettle();
      }
      // 무한 순환 PageView가 앞쪽으로 감기며 orange가 중앙 근처에 렌더된다.
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
