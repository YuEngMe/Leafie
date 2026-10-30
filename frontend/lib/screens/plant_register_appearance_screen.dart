import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/models/plant_species_candidate.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/widgets/color_wheel_picker.dart';
import 'package:yeso_plant/widgets/plant_appearance_colors.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';
import 'package:yeso_plant/services/registration_draft_store.dart';

const _colors = kPlantAppearanceColors;

/// 식별된 종의 category(`PlantSpeciesCandidate.categorySuggestion`)로 헤어를
/// 자동 매핑한다. 사용자는 헤어를 고르지 않는다 — 종에 따라 결정된다.
String hairForCategory(String category) => switch (category) {
  'FLOWER' => 'hair_sunflower',
  'SUCCULENT_CACTUS' => 'hair_flower_cactus',
  'FOLIAGE' => 'hair_monstera',
  'FRUIT' => 'hair_cherry_tomato',
  'HERB' => 'hair_sprout',
  'TREE' => 'hair_sprout',
  'VINE' => 'hair_sprout',
  _ => 'hair_sprout',
};

/// 종별로 헤어를 세분화해 매핑한다. category 매핑(같은 category = 같은 헤어)만으로는
/// 데이지·수국·에케베리아·하월시아처럼 전용 헤어가 있는 종을 구분할 수 없어,
/// 안정적인 `species.referenceId`(catalog:<학명-slug>)로 먼저 분기하고 표에 없는
/// 종은 `hairForCategory`로 폴백한다. (백엔드 HairType enum에 9종 전부 있어 어떤
/// hair_id를 보내도 POST /plants가 통과한다.)
String hairForSpecies(PlantSpeciesCandidate species) =>
    switch (species.referenceId) {
      'catalog:helianthus-annuus' => 'hair_sunflower',
      'catalog:bellis-perennis' => 'hair_daisy',
      'catalog:hydrangea-macrophylla' => 'hair_hydrangea',
      'catalog:monstera-deliciosa' => 'hair_monstera',
      'catalog:cactaceae' => 'hair_flower_cactus',
      'catalog:echeveria-elegans' => 'hair_rosette_succulent',
      'catalog:haworthiopsis-attenuata' => 'hair_pointed_succulent',
      _ => hairForCategory(species.categorySuggestion),
    };

class PlantRegisterAppearanceScreen extends StatefulWidget {
  const PlantRegisterAppearanceScreen({super.key, required this.draft});
  final PlantRegistrationDraft draft;
  @override
  State<PlantRegisterAppearanceScreen> createState() => _AppearanceState();
}

class _AppearanceState extends State<PlantRegisterAppearanceScreen> {
  @override
  void initState() {
    super.initState();
    const RegistrationDraftStore().save(
      RegistrationStep.appearance,
      widget.draft,
    );
  }

  late String? _selectedColorId = widget.draft.bodyColorId;
  // 헤어는 사용자가 고르지 않는다. 종(referenceId)으로 자동 매핑된 값을 그대로
  // draft에 저장하고, 미리보기에도 그 헤어를 얹어 보여준다.
  late final String _selectedHairId =
      widget.draft.headItem ?? hairForSpecies(widget.draft.species);

  void _confirm() {
    if (_selectedColorId == null) return;
    widget.draft.bodyColorId = _selectedColorId;
    widget.draft.headItem = _selectedHairId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantRegisterCompleteScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 스캐폴드 안쪽은 SafeArea가 안전영역을 지운 MediaQuery를 보므로 하단
    // 안전영역은 여기(스캐폴드 바깥)에서 읽는다.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return RegisterStepScaffold(
      appBarTitle: '캐릭터 꾸미기',
      // 시안은 바디와 컬러를 같은 마지막 단계로 본다(4534:507 진행선이
      // 끝까지 주황).
      step: 5,
      title: '리피를 꾸며주세요!',
      centerTitle: true,
      subtitle: '',
      // 시안 4534:507에는 하단 버튼이 없다. 휠의 체크 배지가 확정 버튼이다.
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 본문은 화면 바닥에서 하단 안전영역만큼 위에서 끝난다. 시안 화면
          // y를 본문 좌표로 바꿀 때 바닥을 기준으로 잡아 휠이 늘 화면 바닥에
          // 붙게 한다(402x874에서는 시안 y와 그대로 같다).
          final bottom = constraints.maxHeight + bottomInset;
          double fromDesign(double y) => bottom - (874 - y);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 캐릭터 미리보기 4889:886: 네모 몸통 폭 156, 바닥 y=523.9로
              // 편집 화면(5038:6460)과 같은 자리·크기다. 위젯 폭 182.4와 박스
              // 위 y=366은 편집 화면과 같은 환산이다.
              Positioned(
                left: 0,
                right: 0,
                top: fromDesign(366),
                height: 182.4 * 649 / 698,
                child: Center(
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: PlantCharacterArt(
                      dropShadow: true,
                      width: 182.4,
                      body: plantBodyFromId(widget.draft.bodyId),
                      colorId: _selectedColorId,
                      hairId: _selectedHairId,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: fromDesign(ColorWheelPicker.top),
                height: ColorWheelPicker.height,
                child: ColorWheelPicker(
                  // 아직 고르지 않았으면 미리보기 몸통(색 없음 → 옐로)과 같은
                  // 옐로를 꼭대기에 둔다(시안도 옐로가 꼭대기).
                  initialIndex: math.max(
                    0,
                    _colors.indexWhere(
                      (c) => c.id == (_selectedColorId ?? 'color_yellow'),
                    ),
                  ),
                  onSelected: (index) => setState(() {
                    _selectedColorId = _colors[index].id;
                  }),
                  confirmLabel: '선택 완료',
                  // 기존처럼 색을 한 번 고르기 전에는 확정할 수 없다.
                  onConfirm: _selectedColorId == null ? null : _confirm,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
