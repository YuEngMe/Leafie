import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/plant_detail_screen.dart';
import 'package:yeso_plant/screens/plant_edit_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_edit_info_screen.dart';
import 'package:yeso_plant/screens/plant_management_screen.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';

ManagedPlant _plant({
  required String id,
  required String nickname,
  bool selected = false,
  String colorId = 'color_mint_01',
}) => ManagedPlant(
  id: id,
  nickname: nickname,
  speciesReferenceId: 'species-$id',
  speciesDisplayName: '몬스테라',
  primaryPhotoUrl: null,
  personalityType: 'CUTE',
  colorId: colorId,
  hairId: 'hair_sprout',
  startedOn: DateTime.now()
      .toUtc()
      .add(const Duration(hours: 9))
      .subtract(const Duration(days: 12)),
  isSelected: selected,
);

class _FakeRepository implements PlantManagementRepository {
  _FakeRepository(this.plants);

  List<ManagedPlant> plants;
  String detailPlaceName = '거실';
  String? detailedPlantId;
  LeafieApiException? getPlantError;
  String? selectedPlantId;
  String? renamedTo;
  String? placeNameTo;
  String? appearanceColor;
  String? deletedPlantId;

  @override
  Future<List<ManagedPlant>> listPlants() async => List.of(plants);

  @override
  Future<ManagedPlant> getPlant(String plantId) async {
    detailedPlantId = plantId;
    if (getPlantError case final error?) throw error;
    return plants
        .firstWhere((plant) => plant.id == plantId)
        .copyWith(placeName: detailPlaceName);
  }

  @override
  Future<String?> selectPlant(String? plantId) async {
    selectedPlantId = plantId;
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
  }) async {
    renamedTo = nickname;
    placeNameTo = placeName;
    final plant = plants.firstWhere((item) => item.id == plantId);
    final updated = plant.copyWith(nickname: nickname, placeName: placeName);
    plants = [
      for (final item in plants)
        if (item.id == plantId) updated else item,
    ];
    return updated;
  }

  @override
  Future<ManagedPlant> updateAppearance(
    String plantId, {
    String? colorId,
    String? hairId,
  }) async {
    appearanceColor = colorId;
    final plant = plants.firstWhere((item) => item.id == plantId);
    final updated = plant.copyWith(colorId: colorId);
    plants = [
      for (final item in plants)
        if (item.id == plantId) updated else item,
    ];
    return updated;
  }

  @override
  Future<void> deletePlant(String plantId) async {
    deletedPlantId = plantId;
    plants = plants.where((item) => item.id != plantId).toList();
    if (plants.isNotEmpty && !plants.any((item) => item.isSelected)) {
      plants[0] = plants[0].copyWith(isSelected: true);
    }
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeRepository repository, {
  ValueChanged<String?>? onSelected,
  VoidCallback? onAddPlant,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  await tester.pumpWidget(
    MaterialApp(
      home: PlantManagementScreen(
        repository: repository,
        onSelectedPlantChanged: onSelected,
        onAddPlant: onAddPlant,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('캐릭터를 누르면 선택이 바뀌고 상세 화면이 열린다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
      _plant(id: '2', nickname: '초록이'),
    ]);
    String? selected;
    await _pumpScreen(tester, repository, onSelected: (id) => selected = id);

    await tester.tap(find.byKey(const ValueKey('plant_slot_2')));
    await tester.pumpAndSettle();

    expect(repository.selectedPlantId, '2');
    expect(selected, '2');
    expect(find.byType(PlantDetailScreen), findsOneWidget);
    expect(find.text('캐릭터 편집'), findsOneWidget);
    expect(find.text('초록이'), findsOneWidget);
  });

  testWidgets('빈 슬롯의 + 를 누르면 등록으로 넘어간다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
    ]);
    var tapped = false;
    await _pumpScreen(tester, repository, onAddPlant: () => tapped = true);

    await tester.tap(find.byKey(const ValueKey('add_plant')));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('상세 > 정보 수정에서 닉네임을 바꾼다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
    ]);
    await _pumpScreen(tester, repository);

    await tester.tap(find.byKey(const ValueKey('plant_slot_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plant_detail_menu_캐릭터 정보 수정')));
    await tester.pumpAndSettle();
    expect(find.byType(PlantEditInfoScreen), findsOneWidget);
    final placeField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('plant_place_field')),
        matching: find.byType(TextField),
      ),
    );
    expect(placeField.controller!.text, '거실');
    expect(repository.detailedPlantId, '1');

    await tester.enterText(
      find.byKey(const ValueKey('plant_nickname_field')),
      '반짝이',
    );
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();

    expect(repository.renamedTo, '반짝이');
    expect(repository.placeNameTo, isNull);
    expect(find.text('반짝이'), findsOneWidget);
  });

  testWidgets('상세 조회 실패 시 편집 화면을 열지 않고 오류를 표시한다', (tester) async {
    final repository =
        _FakeRepository([_plant(id: '1', nickname: '새싹이', selected: true)])
          ..getPlantError = const LeafieApiException(
            code: 'PLANT_NOT_FOUND',
            message: '식물을 찾을 수 없습니다.',
            statusCode: 404,
          );
    await _pumpScreen(tester, repository);

    await tester.tap(find.byKey(const ValueKey('plant_slot_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plant_detail_menu_캐릭터 정보 수정')));
    await tester.pumpAndSettle();

    expect(find.byType(PlantEditInfoScreen), findsNothing);
    expect(find.text('식물을 찾을 수 없습니다.'), findsOneWidget);
  });

  testWidgets('상세 > 정보 수정에서 장소를 바꾼다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
    ]);
    await _pumpScreen(tester, repository);

    await tester.tap(find.byKey(const ValueKey('plant_slot_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plant_detail_menu_캐릭터 정보 수정')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plant_place_field')),
      '베란다',
    );
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();

    expect(repository.renamedTo, isNull);
    expect(repository.placeNameTo, '베란다');
  });

  testWidgets('상세 > 꾸미기에서 색상을 바꾼다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
    ]);
    await _pumpScreen(tester, repository);

    await tester.tap(find.byKey(const ValueKey('plant_slot_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plant_detail_menu_꾸미기')));
    await tester.pumpAndSettle();
    expect(find.byType(PlantEditAppearanceScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('appearance_color_pink_01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance_confirm')));
    await tester.pumpAndSettle();

    expect(repository.appearanceColor, 'color_pink_01');
  });

  testWidgets('상세 > 성격은 식물의 성격 글자를 보여준다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
    ]);
    await _pumpScreen(tester, repository);

    await tester.tap(find.byKey(const ValueKey('plant_slot_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plant_detail_menu_성격')));
    await tester.pumpAndSettle();

    // personalityType 'CUTE' = 귀여운 성격(2318:3129~3430).
    expect(find.text('캐릭터 성격'), findsOneWidget);
    expect(find.text('귀여운 성격'), findsOneWidget);
    expect(find.text('#애교'), findsOneWidget);
    expect(find.text('새싹이 물 먹고시포!'), findsOneWidget);
  });

  testWidgets('상세의 휴지통으로 삭제하면 목록에서 사라지고 다음 선택값을 전달한다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
      _plant(id: '2', nickname: '초록이'),
    ]);
    String? selected;
    await _pumpScreen(tester, repository, onSelected: (id) => selected = id);

    await tester.tap(find.byKey(const ValueKey('plant_slot_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete_plant')));
    await tester.pumpAndSettle();

    // 시안 2568:1926의 문구.
    expect(find.text('삭제하시겠습니까?'), findsOneWidget);
    expect(find.text('함께한지 12일이에요'), findsOneWidget);
    await tester.tap(find.text('네'));
    await tester.pumpAndSettle();

    expect(repository.deletedPlantId, '1');
    expect(selected, '2');
    expect(find.byKey(const ValueKey('plant_slot_1')), findsNothing);
  });
}
