import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/arc_appearance_picker.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';

/// 고를 수 있는 바디 3종. body_id 문자열과 화면에 보일 한글 라벨을 묶는다.
/// 색선택 화면의 `kPlantAppearanceColors`와 같은 (id, label) 구조를 따른다.
class _BodyOption {
  const _BodyOption({required this.id, required this.label});
  final String id;
  final String label;
}

const _bodies = [
  _BodyOption(id: 'body_circle', label: '동그라미'),
  _BodyOption(id: 'body_thumb', label: '통통이'),
  _BodyOption(id: 'body_square', label: '네모'),
];

/// CHAR-02 앞 단계(step 5). 캐릭터 바디 모양을 고른다. 고른 body_id는
/// draft에 담아 색선택 화면으로 넘긴다. 색선택 화면과 같은 회전 호 피커
/// (`ArcAppearancePicker`)를 재사용하되, 각 아이템을 색 원 대신 해당 바디
/// PNG 썸네일로 그린다.
class PlantRegisterBodyScreen extends StatefulWidget {
  const PlantRegisterBodyScreen({super.key, required this.draft});
  final PlantRegistrationDraft draft;
  @override
  State<PlantRegisterBodyScreen> createState() => _BodyState();
}

class _BodyState extends State<PlantRegisterBodyScreen> {
  late String _selectedBodyId =
      widget.draft.bodyId ?? PlantRegistrationDraft.defaultBodyId;

  void _confirm() {
    widget.draft.bodyId = _selectedBodyId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantRegisterAppearanceScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RegisterStepScaffold(
    appBarTitle: '캐릭터 만들기',
    step: 5,
    title: '바디를 골라주세요!',
    subtitle: '',
    bottomButton: PrimaryButton(
      key: const ValueKey('body_confirm'),
      label: '선택 완료',
      variant: PrimaryButtonVariant.enabled,
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
                PlantCharacterArt(
                  width: 200,
                  body: plantBodyFromId(_selectedBodyId),
                  colorId: widget.draft.bodyColorId,
                ),
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
                        // 색선택 화면과 같은 넓은 흰 반원 위라 곡률을 맞춰
                        // 큰 R을 준다(디자이너 피드백: 회전 궤도를 배경 원과 맞춘다).
                        arcRadius: 360,
                        initialIndex: math.max(
                          0,
                          _bodies.indexWhere((b) => b.id == _selectedBodyId),
                        ),
                        labels: [for (final b in _bodies) b.label],
                        onSelected: (index) => setState(() {
                          _selectedBodyId = _bodies[index].id;
                        }),
                        itemBuilder: (context, index) {
                          final option = _bodies[index];
                          return Container(
                            key: ValueKey(option.id),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kBackgroundWhite,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedBodyId == option.id
                                    ? kOrangeMain
                                    : const Color(0xFFE8E8E8),
                                width: 3,
                              ),
                            ),
                            child: Image.asset(
                              'assets/images/${option.id}.png',
                              fit: BoxFit.contain,
                              semanticLabel: option.label,
                            ),
                          );
                        },
                      ),
                      Text(
                        '${_bodies.firstWhere((b) => b.id == _selectedBodyId).label} 선택됨',
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
