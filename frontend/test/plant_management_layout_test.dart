import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/plant_detail_screen.dart';
import 'package:yeso_plant/screens/plant_edit_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_edit_info_screen.dart';
import 'package:yeso_plant/screens/plant_management_screen.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
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
  String colorId = 'color_mint_01',
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
  hairId: 'NONE',
  accessoryId: 'NONE',
  daysTogether: daysTogether,
  isSelected: selected,
);

class _FakeRepository implements PlantManagementRepository {
  _FakeRepository(this.plants);

  List<ManagedPlant> plants;

  @override
  Future<List<ManagedPlant>> listPlants() async => List.of(plants);

  @override
  Future<String?> selectPlant(String? plantId) async {
    plants = [
      for (final plant in plants)
        plant.copyWith(isSelected: plant.id == plantId),
    ];
    return plantId;
  }

  @override
  Future<ManagedPlant> updateNickname(String plantId, String nickname) async =>
      plants.firstWhere((item) => item.id == plantId).copyWith(
        nickname: nickname,
      );

  @override
  Future<ManagedPlant> updateAppearance(
    String plantId, {
    String? colorId,
    String? hairId,
    String? accessoryId,
  }) async => plants
      .firstWhere((item) => item.id == plantId)
      .copyWith(colorId: colorId);

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
      await _pumpScreen(
        tester,
        PlantManagementScreen(repository: repository),
      );

      // 캐릭터 PNG는 캔버스에 투명 여백이 있어 그려지는 상자가 시안
      // 프레임(61.22)보다 크다. 그림 밑선이 선반에 닿는지를 잰다.
      // 새싹 PNG 그림은 캔버스 아래 (512-476)/512 = 7.03%를 남긴다.
      final drawn = plantArtWidthFor(61.219, sprouted: true);
      final inkBottomGap = drawn * (512 - 476) / 512;

      for (final entry in {'1': 98.5, '2': 200.5, '3': 305.5}.entries) {
        final rect = tester.getRect(
          find.byKey(ValueKey('plant_slot_${entry.key}')),
        );
        expect(rect.center.dx, _closeTo1px(entry.value));
        expect(rect.bottom - inkBottomGap, _closeTo1px(319));
        // 시안 캐릭터 61.22 폭이 실제로 그만큼 보이도록 그려진다.
        expect(rect.width * 0.7070, _closeTo1px(61.219));
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
      await _pumpScreen(
        tester,
        PlantManagementScreen(repository: repository),
      );

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
      final tenureStyle = tester
          .widget<Text>(find.text('함께한 지 128일째'))
          .style!;
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
        find.descendant(
          of: find.byType(ConfirmDialog),
          matching: find.byType(SizedBox),
        ).first,
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

      // 2568:1735 하단 버튼. 성격 변경 API가 없어 비활성이다.
      expect(find.text('수정하기'), findsOneWidget);
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

      // 힌트 문구(2555:700/705/710).
      expect(find.text('예: 베란다'), findsOneWidget);
      expect(find.text('선택하기'), findsNWidgets(2));

      // 2555:691 하단 버튼 x=34 w=334 h=51.
      final button = tester.getRect(find.text('수정하기'));
      expect(button.center.dx, _closeTo1px(201));
    });

    testWidgets('2568:1683 날짜 피커 시트가 402x325로 뜬다', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('plant_watered_field')));
      await tester.pumpAndSettle();

      expect(find.byType(PlantDatePickerSheet), findsOneWidget);
      final sheet = tester.getRect(find.byType(PlantDatePickerSheet));
      expect(sheet.width, _closeTo1px(402));
      expect(sheet.height, _closeTo1px(PlantDatePickerSheet.sheetHeight));
      expect(PlantDatePickerSheet.sheetHeight, 325);
      // 2568:1686 시트는 오렌지다. 흰 시트는 시안에 없다.
      final sheetBox = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PlantDatePickerSheet),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (sheetBox.decoration! as BoxDecoration).color,
        kOrangeMain,
      );
    });

    testWidgets('실기기 인셋(top 62 / bottom 34)에서도 시트가 바닥에 붙고 버튼이 휠 위로 안 올라온다', (
      tester,
    ) async {
      // iPhone 16 Pro처럼 상단 62 / 하단 34인 기기.
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(
        MaterialApp(
          home: PlantEditInfoScreen(
            plant: _plant(),
            repository: _FakeRepository([_plant()]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plant_watered_field')));
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byType(PlantDatePickerSheet));
      // 하단 SafeArea를 시트 안에서 또 더하면 여기서 325를 넘긴다.
      expect(sheet.height, _closeTo1px(325));
      expect(sheet.bottom, _closeTo1px(874));

      // 버튼(시트 안 y=241..292)이 휠(강조 줄 아래 끝 138.35)과 겹치지 않는다.
      // 화면에도 같은 라벨의 버튼이 있어 시트 안쪽으로 좁힌다.
      final button = tester.getRect(
        find.descendant(
          of: find.byType(PlantDatePickerSheet),
          matching: find.text('수정하기'),
        ),
      );
      final highlightBottom =
          sheet.top +
          PlantDatePickerSheet.highlightTop +
          PlantDatePickerSheet.rowHeight;
      expect(button.top, greaterThan(highlightBottom));
      expect(
        button.center.dy,
        _closeTo1px(sheet.top + PlantDatePickerSheet.buttonTop + 51 / 2),
      );
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

    testWidgets('헤드라인·탭·체크 원 좌표', (tester) async {
      await pump(tester);

      // 2568:1786 앱바, 2568:1874 헤드라인 top 140.
      expect(find.text('캐릭터 꾸미기'), findsOneWidget);
      final headline = tester.getRect(find.text('식물을 꾸며주세요!'));
      expect(headline.top, _closeTo1px(140));
      expect(headline.center.dx, _closeTo1px(201));

      // 2568:1806/1807 탭 글자 x=159 / 211, y=595.
      final colorTab = tester.getRect(find.text('컬러'));
      expect(colorTab.center.dx, _closeTo1px(159 + 11));
      expect(colorTab.center.dy, _closeTo1px(595 + 7));
      final hairTab = tester.getRect(find.text('헤어'));
      expect(hairTab.center.dx, _closeTo1px(211 + 11));

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

    testWidgets('스와치 5개 + 체크 버튼, 지름 60(선택 74)', (tester) async {
      await pump(tester);

      final swatches = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'appearance_color_',
            ),
      );
      // 시안 원호는 스와치 5개고, 아래 가운데는 적용 겸 체크 버튼이다.
      expect(swatches, findsNWidgets(5));
      expect(
        find.byKey(const ValueKey('appearance_color_yellow_01')),
        findsNothing,
      );

      // 선택된 mint(2568:1799)는 링 포함 74.
      final selected = tester.getRect(
        find.byKey(const ValueKey('appearance_color_mint_01')),
      );
      expect(selected.width, _closeTo1px(74));
      // 2568:1798 중심 x=45+151, y=630+37.
      expect(selected.center.dx, _closeTo1px(196));
      expect(selected.center.dy, _closeTo1px(667));

      // 안 고른 것은 60. 2568:1802 중심 x=45+64, y=630+67.
      final purple = tester.getRect(
        find.byKey(const ValueKey('appearance_color_purple_01')),
      );
      expect(purple.width, _closeTo1px(60));
      expect(purple.center.dx, _closeTo1px(109));
      expect(purple.center.dy, _closeTo1px(697));
    });

    testWidgets('헤어 탭으로 넘기면 스와치가 사라진다', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('appearance_tab_헤어')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('appearance_color_mint_01')),
        findsNothing,
      );
      // 헤어 PNG 에셋이 아직 없어 안내만 둔다.
      expect(find.text('헤어 꾸미기는 준비 중이에요'), findsOneWidget);
    });
  });
}
