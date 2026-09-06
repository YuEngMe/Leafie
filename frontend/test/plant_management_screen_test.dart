import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/plant_management_screen.dart';
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
  hairId: 'NONE',
  accessoryId: 'NONE',
  daysTogether: 12,
  isSelected: selected,
);

class _FakeRepository implements PlantManagementRepository {
  _FakeRepository(this.plants);

  List<ManagedPlant> plants;
  String? selectedPlantId;
  String? renamedTo;
  String? appearanceColor;
  String? deletedPlantId;

  @override
  Future<List<ManagedPlant>> listPlants() async => List.of(plants);

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
  Future<ManagedPlant> updateNickname(String plantId, String nickname) async {
    renamedTo = nickname;
    final plant = plants.firstWhere((item) => item.id == plantId);
    final updated = plant.copyWith(nickname: nickname);
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
    String? accessoryId,
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
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: PlantManagementScreen(
        repository: repository,
        onSelectedPlantChanged: onSelected,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('목록에서 식물을 선택하면 서버 선택값과 화면 표시가 바뀐다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
      _plant(id: '2', nickname: '초록이'),
    ]);
    String? selected;
    await _pumpScreen(tester, repository, onSelected: (id) => selected = id);

    await tester.tap(find.byKey(const ValueKey('select_plant_2')));
    await tester.pumpAndSettle();

    expect(repository.selectedPlantId, '2');
    expect(selected, '2');
    expect(find.text('선택됨'), findsOneWidget);
  });

  testWidgets('식물 이름을 변경한다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
    ]);
    await _pumpScreen(tester, repository);

    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plant_nickname_field')),
      '반짝이',
    );
    await tester.tap(find.byKey(const ValueKey('confirm_plant_rename')));
    await tester.pumpAndSettle();

    expect(repository.renamedTo, '반짝이');
    expect(find.text('반짝이'), findsOneWidget);
  });

  testWidgets('색상 외형을 수정한다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
    ]);
    await _pumpScreen(tester, repository);

    await tester.tap(find.text('꾸미기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance_color_pink_01')));
    await tester.tap(find.text('적용하기'));
    await tester.pumpAndSettle();

    expect(repository.appearanceColor, 'color_pink_01');
  });

  testWidgets('선택 식물을 삭제한 뒤 서버가 정한 다음 선택값을 전달한다', (tester) async {
    final repository = _FakeRepository([
      _plant(id: '1', nickname: '새싹이', selected: true),
      _plant(id: '2', nickname: '초록이'),
    ]);
    String? selected;
    await _pumpScreen(tester, repository, onSelected: (id) => selected = id);

    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_plant_delete')));
    await tester.pumpAndSettle();

    expect(repository.deletedPlantId, '1');
    expect(selected, '2');
    expect(find.text('새싹이'), findsNothing);
  });
}
