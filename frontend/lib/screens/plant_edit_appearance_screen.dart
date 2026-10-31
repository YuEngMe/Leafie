import 'package:flutter/material.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/body_glyph.dart';
import 'package:yeso_plant/widgets/color_wheel_picker.dart';
import 'package:yeso_plant/widgets/plant_appearance_colors.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/plant_detail_components.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 시안 5038:6460 "캐릭터 꾸미기"(편집).
///
/// 컬러 선택은 등록 화면(plant_register_appearance_screen)과 같은 컬러 휠
/// (`ColorWheelPicker`)이다. 색 목록도 `kPlantAppearanceColors`를 두 화면이
/// 공유한다. 휠의 주황 체크 배지(x=181 y=777 38x38)가 적용 버튼을 겸한다.
/// 헤어는 종으로 자동 결정되므로 이 화면에서는 고를 수 없고, 현재 값을
/// 미리보기에 얹어 보여주기만 한다.

class PlantEditAppearanceScreen extends StatefulWidget {
  const PlantEditAppearanceScreen({
    super.key,
    required this.plant,
    required this.repository,
  });

  final ManagedPlant plant;
  final PlantManagementRepository repository;

  @override
  State<PlantEditAppearanceScreen> createState() =>
      _PlantEditAppearanceScreenState();
}

/// 편집 화면에서 고를 수 있는 바디 3종. 등록 바디선택 화면과 같은 목록이다.
class _BodyChoice {
  const _BodyChoice({required this.id, required this.label});
  final String id;
  final String label;
}

/// 바디 스위처 실루엣 크기. 시안 6049:2699~2708은 24~28로 제각각인데
/// 묶음 확대 비율(105.96/86.71 ≈ 1.222)을 기존 22에 곱해 맞춘다.
const double _bodyGlyphSize = 22 * 105.96 / 86.71;

const _bodyChoices = [
  _BodyChoice(id: 'body_circle', label: '동그라미'),
  _BodyChoice(id: 'body_thumb', label: '통통이'),
  _BodyChoice(id: 'body_square', label: '네모'),
];

class _PlantEditAppearanceScreenState extends State<PlantEditAppearanceScreen> {
  late String _selectedColorId = widget.plant.colorId;
  late String _selectedBodyId = widget.plant.bodyId;
  bool _busy = false;

  /// 휠이 처음 가리킬 색. 목록에 없는 색이면 캐릭터가 옐로로 그려지므로
  /// (`plantBodyAssetFor`) 휠도 옐로에서 시작한다.
  int _initialColorIndex() {
    final index = kPlantAppearanceColors.indexWhere(
      (c) => c.id == _selectedColorId,
    );
    if (index >= 0) return index;
    return kPlantAppearanceColors.indexWhere((c) => c.id == 'color_yellow');
  }

  Future<void> _apply() async {
    final colorChanged = _selectedColorId != widget.plant.colorId;
    final bodyChanged = _selectedBodyId != widget.plant.bodyId;
    if (!colorChanged && !bodyChanged) {
      Navigator.of(context).pop(widget.plant);
      return;
    }
    setState(() => _busy = true);
    try {
      // PATCH는 부분 수정이라 바뀐 것만 싣되, 헤어는 이 화면에서 고를 수 없어도
      // 종으로 결정된 현재 값을 그대로 실어 보내 서버에서 누락되지 않게 한다.
      final updated = await widget.repository.updateAppearance(
        widget.plant.id,
        bodyId: bodyChanged ? _selectedBodyId : null,
        colorId: colorChanged ? _selectedColorId : null,
        hairId: widget.plant.hairId,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      // 6049:2649 제목은 검정이다(공용 앱바 기본 #444).
      appBar: const YesoAppBar(
        title: '캐릭터 꾸미기',
        titleColor: Colors.black,
      ),
      body: PlantDetailBody(
        children: [
          // 바디 스위처 5038:6460(노드 5070:906). 시안은 앱바 아래 작은 실루엣
          // 3개(원/돔/라운드사각, 각 ~22×22)를 가로로 균등·중앙 정렬한다.
          // 시안엔 이 자리에 헤드라인("식물을 꾸며주세요!")이 없고 스위처가
          // 온다 — 등록 화면과 달리 편집 화면은 헤드라인 없이 스위처를 top 143에
          // 앉힌다. 선택된 바디만 kOrangeMain으로 채우고 나머지는 회색. SVG
          // 에셋이 없어 도형을 코드로 그린다. body_*.png 썸네일은 안 쓴다.
          // 6049:2649(디자이너 수정 "아이콘 크기"): 묶음 6049:2698이 1.22배로
          // 커졌다. 아이콘 ≈27, 간격 12.22, 가운데 x≈201·top 143은 그대로다.
          PlantDetailPositioned(
            top: 143,
            height: _bodyGlyphSize,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final choice in _bodyChoices)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.22 / 2,
                      ),
                      child: GestureDetector(
                        key: ValueKey('appearance_${choice.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _busy
                            ? null
                            : () => setState(() => _selectedBodyId = choice.id),
                        child: Semantics(
                          button: true,
                          selected: _selectedBodyId == choice.id,
                          label: choice.label,
                          child: BodyGlyph(
                            id: choice.id,
                            selected: _selectedBodyId == choice.id,
                            size: _bodyGlyphSize,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 캐릭터 미리보기 5038:6460(5070:1240): 네모 몸통 폭 156, 바닥
          // y=523.9, 헤어 꼭대기 y≈205(스위처 아래). 위젯 폭 182.4는 네모 156을
          // circle 기준 폭으로 환산한 값(156/148×155.23/0.897). 헤어가 박스
          // 위로 솟으므로 박스를 몸통 바닥 기준으로 둔다(박스 위 y=366).
          PlantDetailPositioned(
            top: 366,
            height: 182.4 * 649 / 698,
            child: Center(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: PlantCharacterArt(
                  shadow: CharacterShadow.onWhite,
                  width: 182.4,
                  body: plantBodyFromId(_selectedBodyId),
                  colorId: _selectedColorId,
                  hairId: widget.plant.hairId,
                ),
              ),
            ),
          ),
          // 컬러 휠 5038:6533. 등록 꾸미기(4534:507)와 같은 묶음이라 같은
          // 위젯을 쓴다: 지름 443 원판, '컬러' 라벨·주황 호, 둘레 색 원,
          // 꼭대기 회색 선택 링, 체크 배지(y=777)가 적용 버튼이다.
          Positioned(
            left: 0,
            right: 0,
            top: ColorWheelPicker.top - PlantDetailBody.appBarBand,
            height: ColorWheelPicker.height,
            child: ColorWheelPicker(
              initialIndex: _initialColorIndex(),
              onSelected: (index) => setState(() {
                _selectedColorId = kPlantAppearanceColors[index].id;
              }),
              confirmLabel: '적용하기',
              onConfirm: _busy ? null : _apply,
            ),
          ),
        ],
      ),
    );
  }
}
