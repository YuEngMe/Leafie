import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';

const _colors = [
  (id: 'color_orange_01', label: '오렌지', color: Color(0xFFFFC98B)),
  (id: 'color_purple_01', label: '퍼플', color: Color(0xFFD9B3FA)),
  (id: 'color_mint_01', label: '민트', color: Color(0xFFA8E6C1)),
  (id: 'color_red_01', label: '레드', color: Color(0xFFFF8A8A)),
  (id: 'color_pink_01', label: '핑크', color: Color(0xFFFFC1DA)),
];

// Stable client IDs for the five exported Figma 2555:67 hair options.
const _hairs = [
  (id: 'hair_cactus_column_01', label: '기둥 선인장', asset: '32'),
  (id: 'hair_cactus_yellow_flower_01', label: '노란 꽃 선인장', asset: '34'),
  (id: 'hair_cactus_heart_01', label: '하트 선인장', asset: '36'),
  (id: 'hair_cactus_pink_flower_01', label: '분홍 꽃 선인장', asset: '35'),
  (id: 'hair_cactus_bouquet_01', label: '꽃송이 선인장', asset: '33'),
];

class PlantRegisterAppearanceScreen extends StatefulWidget {
  const PlantRegisterAppearanceScreen({super.key, required this.draft});
  final PlantRegistrationDraft draft;
  @override
  State<PlantRegisterAppearanceScreen> createState() => _AppearanceState();
}

class _AppearanceState extends State<PlantRegisterAppearanceScreen> {
  late String? _selectedColorId = widget.draft.bodyColorId;
  late String? _selectedHairId = widget.draft.headItem;
  bool _hair = false;

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
                const PlantCharacterArt(width: 200),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final label in ['컬러', '헤어'])
                            Semantics(
                              selected: _hair == (label == '헤어'),
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _hair = label == '헤어'),
                                child: Text(
                                  label,
                                  style: kSmallStyle.copyWith(
                                    color: _hair == (label == '헤어')
                                        ? kOrangeMain
                                        : kTextLight,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      IndexedStack(
                        index: _hair ? 1 : 0,
                        children: [
                          Column(
                            children: [
                              ArcAppearancePicker(
                                initialIndex: math.max(
                                  0,
                                  _colors.indexWhere(
                                    (c) =>
                                        c.id ==
                                        (_selectedColorId ?? 'color_mint_01'),
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
                            ],
                          ),
                          Column(
                            children: [
                              ArcAppearancePicker(
                                initialIndex: math.max(
                                  0,
                                  _hairs.indexWhere(
                                    (h) =>
                                        h.id ==
                                        (_selectedHairId ??
                                            'hair_cactus_heart_01'),
                                  ),
                                ),
                                labels: [for (final h in _hairs) h.label],
                                onSelected: (index) => setState(() {
                                  _selectedHairId = _hairs[index].id;
                                }),
                                itemBuilder: (context, index) {
                                  final option = _hairs[index];
                                  return Container(
                                    key: ValueKey(option.id),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _selectedHairId == option.id
                                            ? kOrangeMain
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: SizedBox(
                                        width: 140,
                                        height: 130,
                                        child: ClipRect(
                                          child: Stack(
                                            children: [
                                              Positioned(
                                                left: -switch (option.asset) {
                                                  '32' || '33' => 30.0,
                                                  '35' => 335.0,
                                                  _ => 185.0,
                                                },
                                                top:
                                                    option.asset == '36' ||
                                                        option.asset == '33'
                                                    ? -165
                                                    : -25,
                                                width: 512,
                                                height: 512,
                                                child: Image.asset(
                                                  'assets/images/plant_hair_catalog.png',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Text(
                                _hairs.any((h) => h.id == _selectedHairId)
                                    ? '${_hairs.firstWhere((h) => h.id == _selectedHairId).label} 선택됨'
                                    : '밀거나 눌러 헤어를 선택해주세요',
                                style: kSmallStyle,
                              ),
                            ],
                          ),
                        ],
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

/// Finite, snapping arc picker shared by colour and hair catalogues.
class ArcAppearancePicker extends StatefulWidget {
  const ArcAppearancePicker({
    super.key,
    required this.labels,
    required this.itemBuilder,
    required this.onSelected,
    this.initialIndex = 0,
  });
  final List<String> labels;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onSelected;
  final int initialIndex;
  @override
  State<ArcAppearancePicker> createState() => _ArcPickerState();
}

class _ArcPickerState extends State<ArcAppearancePicker> {
  late final _controller = PageController(
    initialPage: widget.initialIndex,
    viewportFraction: 0.23,
  );
  late int _index = widget.initialIndex;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _index = index);
    HapticFeedback.selectionClick();
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 130,
    child: PageView.builder(
      controller: _controller,
      itemCount: widget.labels.length,
      onPageChanged: _select,
      itemBuilder: (context, index) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final page =
              _controller.hasClients &&
                  _controller.position.hasContentDimensions
              ? _controller.page ?? _index.toDouble()
              : _index.toDouble();
          final distance = (index - page).abs();
          return Transform.translate(
            offset: Offset(0, math.min(54, distance * distance * 14)),
            child: Align(
              alignment: Alignment.topCenter,
              child: Semantics(
                label: widget.labels[index],
                button: true,
                selected: index == _index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _select(index);
                    if (MediaQuery.disableAnimationsOf(context)) {
                      _controller.jumpToPage(index);
                    } else {
                      _controller.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: widget.itemBuilder(context, index),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
