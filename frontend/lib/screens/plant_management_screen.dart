import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/screens/plant_detail_screen.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/plant_detail_components.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 시안 2316:5103 "전체보기_내 캐릭터".
///
/// 노란 배경(#FFECA6) 위에 흰 집 실루엣을 얹고, 집 안 3단 선반에 캐릭터를
/// 격자로 세운다. 빈 슬롯 하나에 `+`가 붙어 등록으로 넘어간다. 카드 리스트,
/// "선택됨" 배지, 라디오 버튼, 카드 안 액션 3개는 시안에 없어 걷어냈다.
const Color kPlantsHouseYellow = Color(0xFFFFECA6); // 2316:5104 연노랑

/// 집 실루엣(2316:5240)의 프레임 좌표. 그림자 필터가 SVG 밖으로 6px씩
/// 번져 나오므로 그리는 크기는 368.03 x 729.99다(원 프레임 362.03x723.99).
const double _kHouseLeft = 20 - 3;
const double _kHouseTop = 117 - 3;
const double _kHouseWidth = 368.032;
const double _kHouseHeight = 729.991;

/// 선반 3줄(2316:5255~5257). x=57 w=287 h=3, 색은 배경과 같은 연노랑.
const List<double> _kShelfTops = [319, 441, 563];
const double _kShelfLeft = 57;
const double _kShelfWidth = 287;
const double _kShelfHeight = 3;

/// 칸 가로 중심. 시안의 캐릭터 프레임(2316:5249/5243/5248 등) 중심값이다.
/// 좌 66~67 + 폭 61~65, 중앙 167~170 + 폭 61~67, 우 274~276 + 폭 61~63.
const List<double> _kColumnCenters = [98.5, 200.5, 305.5];

/// 캐릭터가 선반 위에 서는 칸의 시안 폭. 시안 캐릭터(2316:5243~5253)는
/// 61~67 x 74~93으로 제각각이라 가장 큰 2316:5243(61.22)을 쓰고, 밑선을
/// 선반에 맞춘다. PNG 투명 여백 보정은 plantArtWidthFor가 한다.
const double _kCharacterWidth = 61.219;

/// `+` 버튼(3345:886). 시안 프레임은 x=186 y=520 29x29이지만 SVG는 그림자
/// 때문에 34.05로 넘쳐 그려진다. 그려지는 크기를 그대로 쓴다.
const double _kPlusDrawnSize = 34.048;

/// 상단 구름(2316:5225). 프레임 밖으로 나가는 부분은 잘린다.
const double _kCloudLeft = -33;
const double _kCloudTop = -155;
const double _kCloudWidth = 499;
const double _kCloudHeight = 300;

class PlantManagementScreen extends StatefulWidget {
  const PlantManagementScreen({
    super.key,
    this.repository,
    this.onSelectedPlantChanged,
    this.onAddPlant,
  });

  final PlantManagementRepository? repository;
  final ValueChanged<String?>? onSelectedPlantChanged;
  final VoidCallback? onAddPlant;

  @override
  State<PlantManagementScreen> createState() => _PlantManagementScreenState();
}

class _PlantManagementScreenState extends State<PlantManagementScreen> {
  late final PlantManagementRepository _repository =
      widget.repository ?? PlantManagementApi();
  List<ManagedPlant> _plants = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    setState(() => _loading = true);
    try {
      final plants = await _repository.listPlants();
      if (mounted) setState(() => _plants = plants);
    } on LeafieApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 시안에는 캐릭터를 누르면 상세로 가는 흐름만 있다. 선택 전환은 상세로
  /// 들어가는 김에 함께 해 홈이 그 식물을 보게 한다.
  Future<void> _openDetail(ManagedPlant plant) async {
    if (!plant.isSelected) {
      try {
        final selectedId = await _repository.selectPlant(plant.id);
        if (!mounted) return;
        setState(() {
          _plants = [
            for (final item in _plants)
              item.copyWith(isSelected: item.id == selectedId),
          ];
        });
        widget.onSelectedPlantChanged?.call(selectedId);
      } on LeafieApiException catch (error) {
        if (mounted) _showError(error.message);
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            PlantDetailScreen(plant: plant, repository: _repository),
      ),
    );
    if (!mounted) return;
    // 상세에서 이름·외형을 고치거나 삭제했을 수 있어 다시 읽는다.
    await _loadPlants();
    if (!mounted) return;
    widget.onSelectedPlantChanged?.call(
      _plants.where((item) => item.isSelected).firstOrNull?.id,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPlantsHouseYellow,
      appBar: const YesoAppBar(
        title: '내 캐릭터',
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kOrangeMain))
          : _PlantShelfHouse(
              plants: _plants,
              onTapPlant: _openDetail,
              onAddPlant: widget.onAddPlant,
            ),
    );
  }
}

/// 집 배경 + 선반 + 캐릭터 격자. 시안 좌표를 그대로 옮기려고 Stack을 쓴다.
/// 시안 y는 프레임 절대값이라 상태바(46)와 앱바(46)를 뺀 값을 얹는다.
class _PlantShelfHouse extends StatelessWidget {
  const _PlantShelfHouse({
    required this.plants,
    required this.onTapPlant,
    required this.onAddPlant,
  });

  static const double _appBarBand = 46 + YesoAppBar.height;

  final List<ManagedPlant> plants;
  final ValueChanged<ManagedPlant> onTapPlant;
  final VoidCallback? onAddPlant;

  /// 슬롯은 3열 x 3단 = 9칸. 마지막 캐릭터 다음 칸이 `+`다.
  static const int _slotCount = 9;

  @override
  Widget build(BuildContext context) {
    final visible = plants.take(_slotCount).toList();
    // 빈 칸이 없으면 `+`를 못 놓는다. 시안(3345:886)은 7번째 칸이었다.
    final plusSlot = visible.length < _slotCount ? visible.length : null;

    // 구름(2316:5225)은 앱바·상태바 뒤까지 올라간다. 몸통을 자르면 제목
    // 아래에 구름 밑동만 남으므로 자르지 않고 앱바를 투명하게 둔다.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _kCloudLeft,
          top: _kCloudTop - _appBarBand,
          width: _kCloudWidth,
          height: _kCloudHeight,
          child: SvgPicture.asset(
            'assets/images/plants_cloud_top.svg',
            width: _kCloudWidth,
            height: _kCloudHeight,
            // contain으로 두면 SVG가 제 비율대로 그려진다. fill은 구름
            // 덩어리를 늘려 제목 아래에 흰 타원 조각을 만들었다.
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          left: _kHouseLeft,
          top: _kHouseTop - _appBarBand,
          width: _kHouseWidth,
          height: _kHouseHeight,
          child: SvgPicture.asset(
            'assets/images/plants_house_bg.svg',
            width: _kHouseWidth,
            height: _kHouseHeight,
            fit: BoxFit.contain,
            semanticsLabel: '식물들이 사는 집',
          ),
        ),
        // 굴뚝 2316:5254. 지붕 오른쪽 흰 사각 x=278.04 y=152.07 41x86.
        // 집 SVG에 포함되지 않아 따로 얹는다.
        Positioned(
          left: 278.036,
          top: 152.074 - _appBarBand,
          width: 41,
          height: 86,
          child: const ColoredBox(color: kBackgroundWhite),
        ),
        for (final shelfTop in _kShelfTops)
          Positioned(
            left: _kShelfLeft,
            top: shelfTop - _appBarBand,
            width: _kShelfWidth,
            height: _kShelfHeight,
            child: const ColoredBox(color: kPlantsHouseYellow),
          ),
        for (var index = 0; index < visible.length; index++)
          _slot(
            index: index,
            child: GestureDetector(
              key: ValueKey('plant_slot_${visible[index].id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTapPlant(visible[index]),
              child: Semantics(
                button: true,
                label: visible[index].nickname,
                child: PlantCharacterArt(
                  width: plantArtWidthFor(_kCharacterWidth),
                  body: plantBodyFromId(visible[index].bodyId),
                  colorId: visible[index].colorId,
                  hairId: visible[index].hairId,
                ),
              ),
            ),
          ),
        if (plusSlot != null)
          _slot(
            index: plusSlot,
            child: Center(
              child: GestureDetector(
                key: const ValueKey('add_plant'),
                behavior: HitTestBehavior.opaque,
                onTap: onAddPlant,
                child: Semantics(
                  button: true,
                  label: '식물 등록',
                  child: SvgPicture.asset(
                    'assets/images/plants_add_plus.svg',
                    width: _kPlusDrawnSize,
                    height: _kPlusDrawnSize,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 그려지는 캐릭터 상자. PNG 여백 때문에 시안 프레임보다 크다.
  static final double _drawnWidth = plantArtWidthFor(_kCharacterWidth);
  static final double _drawnHeight = _drawnWidth * 649 / 698;

  /// PlantCharacterArt는 박스 바닥에서 박스 높이의 37/649(5.70%) 위에 circle
  /// 몸통 밑선을 둔다. 그림 밑선이 선반에 닿도록 그만큼 더 내린다.
  static final double _inkBottomGap = _drawnHeight * (649 - 612) / 649;

  /// index를 3열 x 3단 격자 좌표로 편다. 캐릭터는 선반 위에 밑선을 맞춘다.
  Widget _slot({required int index, required Widget child}) {
    final row = index ~/ 3;
    final column = index % 3;
    final shelfTop = _kShelfTops[row];
    return Positioned(
      left: _kColumnCenters[column] - _drawnWidth / 2,
      top: shelfTop - _appBarBand - _drawnHeight + _inkBottomGap,
      width: _drawnWidth,
      height: _drawnHeight,
      child: child,
    );
  }
}
