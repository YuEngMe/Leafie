import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_register_body_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_progress_bar.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

class _PersonalityOption {
  const _PersonalityOption({
    required this.type,
    required this.label,
    required this.tags,
    required this.dialogue,
  });

  final String type; // PersonalityType enum 값 (api-spec.md)
  final String label;
  final String tags;
  final String dialogue;
}

// 이름·태그·대사는 시안 2318:3129~3430의 글자 그대로다(2026-09-07 대조).
// 순서도 시안 프레임 순서(활발→시크→귀여운→소심→짝사랑→충청도)를 따른다.
const _personalities = [
  _PersonalityOption(
    type: 'OUTGOING',
    label: '활발한 성격',
    tags: '#긍정적   #에너지',
    dialogue: '자 이제 물 줄 시간이야!',
  ),
  _PersonalityOption(
    type: 'CHIC',
    label: '시크한 성격',
    tags: '#냉소적   #츤데레',
    dialogue: '뭘 봐? 물이나 줘.',
  ),
  _PersonalityOption(
    type: 'CUTE',
    label: '귀여운 성격',
    tags: '#애교   #사랑둥이',
    dialogue: '새싹이 물 먹고시포!',
  ),
  _PersonalityOption(
    type: 'INTROVERTED',
    label: '소심한 성격',
    tags: '#내성적   #눈치',
    dialogue: '저..물 좀 주시면..안될까요..?',
  ),
  _PersonalityOption(
    type: 'CRUSH',
    label: '짝사랑 성격',
    tags: '#미연시   #적극적',
    dialogue: '물 줄래, 나랑 사귈래',
  ),
  _PersonalityOption(
    type: 'CHUNGCHEONG',
    label: '충청도 성격',
    tags: '#느긋한   #구수한',
    dialogue: '말라죽겄슈',
  ),
];

/// 시안 순서 그대로의 성격 이름. 테스트가 글자를 고정한다.
List<String> get kPersonalityLabels => [for (final p in _personalities) p.label];

class PlantRegisterPersonalityScreen extends StatefulWidget {
  const PlantRegisterPersonalityScreen({super.key, required this.draft});

  final PlantRegistrationDraft draft;

  @override
  State<PlantRegisterPersonalityScreen> createState() =>
      _PlantRegisterPersonalityScreenState();
}

class _PlantRegisterPersonalityScreenState
    extends State<PlantRegisterPersonalityScreen> {
  final _pageController = PageController();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    widget.draft.personalityType = _personalities[_selectedIndex].type;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantRegisterBodyScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '캐릭터 성격'),
      body: SafeArea(
        child: Column(
          children: [
            const Center(child: RegisterProgressBar(step: 4)),
            const SizedBox(height: 12),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _personalities.length,
                onPageChanged: (index) =>
                    setState(() => _selectedIndex = index),
                itemBuilder: (context, index) {
                  final personality = _personalities[index];
                  return Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        // 2318:3964만 kTextDark가 아닌 #2E2E2E를 쓴다.
                        child: Text(
                          personality.label,
                          style: kTitleStyle.copyWith(color: kPersonalityTitle),
                        ),
                      ),
                      Positioned(
                        top: AppLayout.personalityTagsTop,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: personality.tags
                              .split('   ')
                              .map((tag) => _PersonalityTag(label: tag))
                              .toList(),
                        ),
                      ),
                      Positioned(
                        top: AppLayout.personalityCharacterTop,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: PlantCharacterArt(
                            width: AppLayout.personalityCharacterWidth,
                            body: plantBodyFromId(widget.draft.bodyId),
                            // 성격 단계엔 아직 헤어를 draft에 저장하기 전이라
                            // 종 매핑값으로 미리 얹어 보여준다.
                            hairId:
                                widget.draft.headItem ??
                                hairForSpecies(widget.draft.species),
                          ),
                        ),
                      ),
                      Positioned(
                        top: AppLayout.personalityBubbleTop,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 255,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: kBackgroundWhite,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1F000000),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: Text(
                              personality.dialogue,
                              style: kBodyStyle,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: AppLayout.personalityDotsTop,
                        left: 0,
                        right: 0,
                        child: _PersonalityDots(selectedIndex: _selectedIndex),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.registrationHorizontalPadding,
                18,
                AppLayout.registrationHorizontalPadding,
                AppLayout.bottomPadding,
              ),
              child: PrimaryButton(
                label: '다음',
                variant: PrimaryButtonVariant.enabled,
                onPressed: _goToNextStep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalityDots extends StatelessWidget {
  const _PersonalityDots({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _personalities.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // 2318:3925 활성 점은 kOrangeMain이다.
            color: index == selectedIndex
                ? kOrangeMain
                : const Color(0xFFD9D9D9),
          ),
        ),
      ),
    );
  }
}

class _PersonalityTag extends StatelessWidget {
  const _PersonalityTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // 2318:3960 테두리는 0.827px, 색은 kTagOrange다.
        border: Border.all(color: kTagOrange, width: 0.827),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: kCaptionStyle.copyWith(color: kTagOrange, fontSize: 10),
      ),
    );
  }
}
