import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';

class _ColorOption {
  const _ColorOption(this.id, this.color);

  final String id; // POST /plants의 character.body_color 값 (color_id 형식)
  final Color color;
}

const _colorOptions = [
  _ColorOption('color_orange_01', Color(0xFFFFC98B)),
  _ColorOption('color_purple_01', Color(0xFFD9B3FA)),
  _ColorOption('color_mint_01', Color(0xFFA8E6C1)),
  _ColorOption('color_yellow_01', Color(0xFFFFF176)),
  _ColorOption('color_red_01', Color(0xFFFF8A8A)),
  _ColorOption('color_skyblue_01', Color(0xFFA8D8FF)),
  _ColorOption('color_blue_01', Color(0xFF7FA6F5)),
  _ColorOption('color_gray_01', Color(0xFFB0B0B0)),
  _ColorOption('color_pink_01', Color(0xFFFFC1DA)),
];

class PlantRegisterAppearanceScreen extends StatefulWidget {
  const PlantRegisterAppearanceScreen({super.key, required this.draft});

  final PlantRegistrationDraft draft;

  @override
  State<PlantRegisterAppearanceScreen> createState() =>
      _PlantRegisterAppearanceScreenState();
}

class _PlantRegisterAppearanceScreenState
    extends State<PlantRegisterAppearanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // 팔레트 첫 색을 미리 골라 두면 사용자가 고르지 않은 값이 그대로
  // 저장되고, 아래 null 검사도 영원히 걸리지 않는다.
  String? _selectedColorId;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (_selectedColorId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('컬러를 선택해주세요')));
      return;
    }
    widget.draft.bodyColorId = _selectedColorId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantRegisterCompleteScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RegisterStepScaffold(
      appBarTitle: '캐릭터 만들기',
      step: 5,
      title: '식물을 꾸며주세요!',
      subtitle: '',
      child: Stack(
        children: [
          const Positioned(
            top: AppLayout.appearanceCharacterTop,
            left: 0,
            right: 0,
            child: Center(
              child: PlantCharacterArt(
                width: AppLayout.appearanceCharacterWidth,
              ),
            ),
          ),
          Positioned(
            top: AppLayout.appearancePaletteTop,
            left: -54,
            right: -54,
            height: 500,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kBackgroundWhite,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8E8E8), width: 2),
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
          Positioned(
            top:
                AppLayout.appearancePaletteTop +
                AppLayout.appearanceTabTopOffset,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 132,
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) => setState(() => _activeTab = index),
                  dividerColor: Colors.transparent,
                  indicatorColor: kOrangeMain,
                  labelColor: kOrangeAccent, // 2318:3594
                  unselectedLabelColor: kTextLight,
                  labelStyle: kCaptionStyle,
                  tabs: const [
                    Tab(text: '컬러'),
                    Tab(text: '헤어'),
                  ],
                ),
              ),
            ),
          ),
          if (_activeTab == 0)
            Positioned(
              top:
                  AppLayout.appearancePaletteTop +
                  AppLayout.appearanceSwatchesTopOffset,
              left: 0,
              right: 0,
              height: 260,
              child: _SemicircleColorPalette(
                selectedColorId: _selectedColorId,
                onSelected: (id) => setState(() => _selectedColorId = id),
                onConfirm: _goToNextStep,
              ),
            )
          else
            Positioned(
              top:
                  AppLayout.appearancePaletteTop +
                  AppLayout.appearanceHairMessageTopOffset,
              left: 0,
              right: 0,
              child: Center(child: Text('헤어 꾸미기는 준비 중이에요', style: kSmallStyle)),
            ),
        ],
      ),
    );
  }
}

class _SemicircleColorPalette extends StatelessWidget {
  const _SemicircleColorPalette({
    required this.selectedColorId,
    required this.onSelected,
    required this.onConfirm,
  });

  final String? selectedColorId;
  final ValueChanged<String> onSelected;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    const swatches = [
      (optionIndex: 1, left: 46.0, top: 44.0),
      (optionIndex: 2, left: 140.0, top: 8.0),
      (optionIndex: 4, left: 234.0, top: 44.0),
      (optionIndex: 0, left: 12.0, top: 118.0),
      (optionIndex: 8, left: 268.0, top: 118.0),
    ];
    return Stack(
      children: [
        for (final swatch in swatches)
          Positioned(
            left: swatch.left,
            top: swatch.top,
            child: Builder(
              builder: (context) {
                final option = _colorOptions[swatch.optionIndex];
                final selected = selectedColorId == option.id;
                return GestureDetector(
                  key: ValueKey(option.id),
                  onTap: () => onSelected(option.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: selected ? 72 : 60,
                    height: selected ? 72 : 60,
                    decoration: BoxDecoration(
                      color: option.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFD8D8D8)
                            : Colors.white,
                        width: selected ? 5 : 2,
                      ),
                      boxShadow: selected
                          ? const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 3,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        Positioned(
          left: 160,
          top: 136,
          child: Semantics(
            button: true,
            label: '선택 완료',
            child: GestureDetector(
              key: const ValueKey('appearance_confirm'),
              onTap: onConfirm,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x16000000), blurRadius: 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
