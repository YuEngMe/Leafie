import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/arc_appearance_picker.dart';
import 'package:yeso_plant/widgets/plant_appearance_colors.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';

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

class PlantRegisterAppearanceScreen extends StatefulWidget {
  const PlantRegisterAppearanceScreen({super.key, required this.draft});
  final PlantRegistrationDraft draft;
  @override
  State<PlantRegisterAppearanceScreen> createState() => _AppearanceState();
}

class _AppearanceState extends State<PlantRegisterAppearanceScreen> {
  late String? _selectedColorId = widget.draft.bodyColorId;
  // 헤어는 사용자가 고르지 않는다. 종 category로 자동 매핑된 값을 그대로
  // draft에 저장하고, 미리보기에도 그 헤어를 얹어 보여준다.
  late final String _selectedHairId =
      widget.draft.headItem ??
      hairForCategory(widget.draft.species.categorySuggestion);

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
  Widget build(BuildContext context) => RegisterStepScaffold(
    appBarTitle: '캐릭터 만들기',
    step: 5,
    title: '식물을 꾸며주세요!',
    subtitle: '',
    bottomButton: PrimaryButton(
      key: const ValueKey('appearance_confirm'),
      label: '선택 완료',
      variant: _selectedColorId == null
          ? PrimaryButtonVariant.disabled
          : PrimaryButtonVariant.enabled,
      onPressed: _confirm,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                SizedBox(height: math.max(12, constraints.maxHeight - 440)),
                PlantCharacterArt(width: 200),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: kBackgroundWhite,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(100),
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x14000000), blurRadius: 5),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      ArcAppearancePicker(
                        // 배경이 top-radius 100의 넓은 흰 반원이라 곡률이
                        // 완만하다. 색 원들이 그 상단 호를 따라 완만히
                        // 내려가도록 큰 R을 준다(디자이너 피드백: 회전 궤도를
                        // 배경 원과 맞춘다).
                        arcRadius: 360,
                        initialIndex: math.max(
                          0,
                          _colors.indexWhere(
                            (c) =>
                                c.id == (_selectedColorId ?? 'color_green'),
                          ),
                        ),
                        labels: [for (final c in _colors) c.label],
                        onSelected: (index) => setState(() {
                          _selectedColorId = _colors[index].id;
                        }),
                        itemBuilder: (context, index) {
                          final option = _colors[index];
                          return Container(
                            key: ValueKey(option.id),
                            decoration: BoxDecoration(
                              color: option.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColorId == option.id
                                    ? kOrangeMain
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          );
                        },
                      ),
                      Text(
                        _selectedColorId == null
                            ? '밀거나 눌러 컬러를 선택해주세요'
                            : '${_colors.firstWhere((c) => c.id == _selectedColorId).label} 선택됨',
                        style: kSmallStyle,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
