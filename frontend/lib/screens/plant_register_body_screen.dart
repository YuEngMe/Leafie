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
/// 중앙 정렬한다. 선택된 것만 주황이다. 캐릭터를 좌우로 밀거나(성격 화면과
/// 같은 PageView) 인디케이터를 탭하면 바디가 바뀐다.
class PlantRegisterBodyScreen extends StatefulWidget {
  const PlantRegisterBodyScreen({super.key, required this.draft});
  final PlantRegistrationDraft draft;
  @override
  State<PlantRegisterBodyScreen> createState() => _BodyState();
}

class _BodyState extends State<PlantRegisterBodyScreen> {
  late String _selectedBodyId =
      widget.draft.bodyId ?? PlantRegistrationDraft.defaultBodyId;
  late final PageController _pageController = PageController(
    initialPage: _indexOf(_selectedBodyId),
  );

  static int _indexOf(String id) {
    final index = _bodies.indexWhere((b) => b.id == id);
    return index < 0 ? 0 : index;
  }

  void _selectFromIndicator(String id) {
    setState(() => _selectedBodyId = id);
    _pageController.animateToPage(
      _indexOf(id),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
    // 스캐폴드가 왼쪽 정렬이라 폭을 꽉 채워 가운데 정렬한다.
    child: SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            // 시안 5028:1193: 몸통(circle) 폭 170.44, 바닥 y=489,
            // 인디케이터 y=558. 폭 190 = 170.44 / 0.897.
            const SizedBox(height: _kArtTopGap),
            // 몸통 박스 높이(= 폭 × 649/698)만큼 밀어서 넘기는 영역.
            SizedBox(
              height: _kArtWidth * 649 / 698,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _bodies.length,
                onPageChanged: (index) =>
                    setState(() => _selectedBodyId = _bodies[index].id),
                itemBuilder: (context, index) => Center(
                  child: PlantCharacterArt(
                    width: _kArtWidth,
                    body: plantBodyFromId(_bodies[index].id),
                    colorId: widget.draft.bodyColorId,
                  ),
                ),
              ),
            ),
            const SizedBox(height: _kArtToIndicatorGap),
            // 바디 실루엣 인디케이터 3개(시안 폭 86.7 → 글리프 간격 약 10).
            // 22×22 글리프는 탭 영역이 좁아 opaque GestureDetector로 넓힌다.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in _bodies)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: GestureDetector(
                      key: ValueKey('body_${option.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectFromIndicator(option.id),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

const double _kArtWidth = 190;
// 스캐폴드 본문 시작(헤드라인 아래)에서 몸통 박스 위까지. 박스 위 = 몸통 바닥
// 489 + 박스 아래 여백(0.053 × 190) − 박스 높이(190 × 649/698).
const double _kArtTopGap = 152;
// 박스 바닥(≈499)에서 인디케이터 y=558까지.
const double _kArtToIndicatorGap = 59;
