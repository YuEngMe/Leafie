import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/arc_appearance_picker.dart';
import 'package:yeso_plant/widgets/plant_appearance_colors.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/plant_detail_components.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 시안 2568:1764 "캐릭터 상세_꾸미기"(컬러 탭만 쓴다).
///
/// 컬러 선택은 등록 화면(plant_register_appearance_screen)과 같은 드르륵
/// 가로 스크롤 카루셀(`ArcAppearancePicker`)로 통일했다. 색 목록도
/// `kPlantAppearanceColors`를 두 화면이 공유한다. 아래 주황 체크 원
/// (2568:1811, x=182 y=760 38x38)이 적용 버튼을 겸한다.
/// 헤어는 종으로 자동 결정되므로 이 화면에서는 고를 수 없고, 현재 값을
/// 미리보기에 얹어 보여주기만 한다.

const double _kPaletteLeft = -25;
const double _kPaletteTop = 576;
const double _kPaletteSize = 443;

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

const _bodyChoices = [
  _BodyChoice(id: 'body_circle', label: '동그라미'),
  _BodyChoice(id: 'body_thumb', label: '통통이'),
  _BodyChoice(id: 'body_square', label: '네모'),
];

class _PlantEditAppearanceScreenState extends State<PlantEditAppearanceScreen> {
  late String _selectedColorId = widget.plant.colorId;
  late String _selectedBodyId = widget.plant.bodyId;
  bool _busy = false;

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
      appBar: const YesoAppBar(title: '캐릭터 꾸미기'),
      body: PlantDetailBody(
        children: [
          // 헤드라인 2568:1874. top 140, 21/w600 진한 텍스트.
          const PlantDetailPositioned(
            top: 140,
            height: 25,
            child: Center(child: Text('식물을 꾸며주세요!', style: kTitleStyle)),
          ),
          // 캐릭터 미리보기 2568:1785. x=103 y=287 196x168.
          PlantDetailPositioned(
            top: 287,
            height: 168,
            child: Center(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: PlantCharacterArt(
                  width: plantArtWidthFor(196),
                  body: plantBodyFromId(_selectedBodyId),
                  colorId: _selectedColorId,
                  hairId: widget.plant.hairId,
                ),
              ),
            ),
          ),
          // 바디 선택 행. 미리보기(~455)와 팔레트 원(576) 사이 공간에 바디 3종을
          // 한 줄로 앉힌다. 색은 회전 카루셀로 고르지만 바디는 3종뿐이라 한눈에
          // 보이도록 고정 행으로 둔다. 선택된 바디는 kOrangeMain 테두리.
          PlantDetailPositioned(
            top: 470,
            height: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final choice in _bodyChoices)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
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
                        child: Container(
                          width: 72,
                          height: 72,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kBackgroundWhite,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedBodyId == choice.id
                                  ? kOrangeMain
                                  : const Color(0xFFE8E8E8),
                              width: 3,
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/${choice.id}.png',
                            fit: BoxFit.contain,
                            semanticLabel: choice.label,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 팔레트 큰 원 2568:1796.
          Positioned(
            left: _kPaletteLeft,
            top: _kPaletteTop - PlantDetailBody.appBarBand,
            width: _kPaletteSize,
            height: _kPaletteSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kBackgroundWhite,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8E8E8)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),
          // 컬러 카루셀 2568:1797. 절대좌표 스와치 대신 등록 화면과 같은
          // 드르륵 가로 스냅 카루셀을 팔레트 원 위 영역에 앉힌다.
          PlantDetailPositioned(
            top: 630,
            height: 130,
            child: ArcAppearancePicker(
              // 색 원들이 뒤 팔레트 원(지름 443, 반지름 ≈ 221)의 호를 따라
              // 돌도록 R을 그 원 반지름에 맞춘다(디자이너 피드백: 돌아가는
              // 축이 배경 원과 맞아야 자연스럽다).
              arcRadius: _kPaletteSize / 2,
              initialIndex: math.max(
                0,
                kPlantAppearanceColors.indexWhere(
                  (c) => c.id == _selectedColorId,
                ),
              ),
              labels: [for (final c in kPlantAppearanceColors) c.label],
              onSelected: (index) => setState(() {
                _selectedColorId = kPlantAppearanceColors[index].id;
              }),
              itemBuilder: (context, index) {
                final option = kPlantAppearanceColors[index];
                return DecoratedBox(
                  // 계약 테스트가 이 prefix로 스와치를 찾는다
                  // (appearance_color_<id>). 등록 화면과 명명 규칙이
                  // 다르니 여기서는 반드시 prefix를 붙인다.
                  key: ValueKey('appearance_${option.id}'),
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                    // 2568:1799 선택 링은 검정 15%, 굵기 4.
                    border: _selectedColorId == option.id
                        ? Border.all(color: const Color(0x26000000), width: 4)
                        : null,
                  ),
                );
              },
            ),
          ),
          // 체크 원 2568:1811. 프레임 x=182 y=760 38x38이지만 SVG는 그림자
          // 때문에 46x46으로 그려진다(원 지름 38, 중심이 프레임 중심).
          Positioned(
            left: 182 - 4,
            top: 760 - 4 - PlantDetailBody.appBarBand,
            width: 46,
            height: 46,
            child: GestureDetector(
              key: const ValueKey('appearance_confirm'),
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : _apply,
              child: Semantics(
                button: true,
                label: '적용하기',
                child: SvgPicture.asset(
                  'assets/images/plants_appearance_check.svg',
                  width: 46,
                  height: 46,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
