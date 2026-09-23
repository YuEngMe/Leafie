import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/widgets/body_glyph.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';

/// 고를 수 있는 바디 3종. body_id 문자열과 화면에 보일 한글 라벨을 묶는다.
/// 편집 화면(plant_edit_appearance_screen)의 `_bodyChoices`와 같은 목록이다.
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
/// draft에 담아 색선택 화면으로 넘긴다.
///
/// 시안 5108:721: 회전 호 피커 대신, 캐릭터 미리보기 아래에 작은 실루엣
/// 인디케이터 3개(편집 화면과 같은 `BodyGlyph` 원/돔/네모)를 가로로
/// 중앙 정렬한다. 선택된 것만 주황이고, 탭하면 미리보기가 바뀐다.
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
    title: '리피의 외형을 정해주세요!',
    subtitle: '',
    bottomButton: PrimaryButton(
      key: const ValueKey('body_confirm'),
      label: '선택',
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
                // 시안 미리보기 y=332, 스위처 y=558. 색선택 화면과 같은
                // 방식으로 미리보기를 화면 아래쪽에 앉힌다. 456은 미리보기
                // top을 시안 332에 맞추려 440에서 16px 올린 값이다(헤어가
                // 없는 화면이라 위로 올려도 헤드라인과 겹치지 않는다).
                SizedBox(height: math.max(12, constraints.maxHeight - 456)),
                PlantCharacterArt(
                  width: 200,
                  body: plantBodyFromId(_selectedBodyId),
                  colorId: widget.draft.bodyColorId,
                ),
                const SizedBox(height: 40),
                // 바디 실루엣 인디케이터 3개(중앙 정렬, 선택만 주황).
                // 22×22 글리프는 탭 영역이 좁아 편집 화면처럼 좌우 패딩과
                // opaque GestureDetector로 탭 영역을 넓힌다.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final option in _bodies)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GestureDetector(
                          key: ValueKey('body_${option.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              setState(() => _selectedBodyId = option.id),
                          child: Semantics(
                            button: true,
                            selected: _selectedBodyId == option.id,
                            label: option.label,
                            child: BodyGlyph(
                              id: option.id,
                              selected: _selectedBodyId == option.id,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    ),
  );
}
