import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_register_body_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_progress_bar.dart';
import 'package:yeso_plant/widgets/svg_drop_shadow.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';
import 'package:yeso_plant/services/registration_draft_store.dart';

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

// 이름·태그는 시안 2318:3129~3430의 글자 그대로다(2026-09-07 대조).
// 대사는 시안 예시 대신 팀 노션 '성격별 말투'의 '평소' 줄을 쓴다. 홈에서
// 서버가 내려 주는 평소 대사(backend HOME_DIALOGUES NORMAL)와 같아서,
// 고를 때 들은 말투를 홈에서도 그대로 듣는다.
// 순서도 시안 프레임 순서(활발→시크→귀여운→소심→짝사랑→충청도)를 따른다.
const _personalities = [
  _PersonalityOption(
    type: 'OUTGOING',
    label: '활발한 성격',
    tags: '#긍정적   #에너지',
    dialogue: '오늘도 같이 놀자!',
  ),
  _PersonalityOption(
    type: 'CHIC',
    label: '시크한 성격',
    tags: '#냉소적   #츤데레',
    dialogue: '됐어. 그냥 있어.',
  ),
  _PersonalityOption(
    type: 'CUTE',
    label: '귀여운 성격',
    tags: '#애교   #사랑둥이',
    dialogue: '오늘은 뭐 하고 놀까?',
  ),
  _PersonalityOption(
    type: 'INTROVERTED',
    label: '소심한 성격',
    tags: '#내성적   #눈치',
    dialogue: '와줬네… 사실 조금 기다렸어.',
  ),
  _PersonalityOption(
    type: 'CRUSH',
    label: '짝사랑 성격',
    tags: '#미연시   #적극적',
    dialogue: '오늘도 네 생각만 했어….',
  ),
  _PersonalityOption(
    type: 'CHUNGCHEONG',
    label: '충청도 성격',
    tags: '#느긋한   #구수한',
    dialogue: '기다리고 있었구먼유.',
  ),
];

/// 말풍선 SVG(그림자 여백 포함) 크기. 4534:175 Union 253x47.05 + 사방 4.126.
const Size _bubbleSvgSize = Size(261.253, 55.3058);

/// 시안 순서 그대로의 성격 이름. 테스트가 글자를 고정한다.
List<String> get kPersonalityLabels => [
  for (final p in _personalities) p.label,
];

class PlantRegisterPersonalityScreen extends StatefulWidget {
  const PlantRegisterPersonalityScreen({super.key, required this.draft});

  final PlantRegistrationDraft draft;

  @override
  State<PlantRegisterPersonalityScreen> createState() =>
      _PlantRegisterPersonalityScreenState();
}

class _PlantRegisterPersonalityScreenState
    extends State<PlantRegisterPersonalityScreen> {
  @override
  void initState() {
    super.initState();
    const RegistrationDraftStore().save(
      RegistrationStep.personality,
      widget.draft,
    );
  }

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
              // 캐릭터·말풍선·점은 제자리에 두고, 넘기면 성격 이름·태그·대사만
              // 넘어간다(디자이너 답 10-A). 넘기는 손짓은 화면 어디서나 받도록
              // PageView를 맨 위 전체에 깐다.
              child: Stack(
                children: [
                  Positioned(
                    top: AppLayout.personalityCharacterTop,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: PlantCharacterArt(
                        dropShadow: true,
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
                  // 말풍선 4534:174. 위로 꼬리가 난 Union(253x47.05)을
                  // 시안 SVG 그대로 그린다(성격 수정 4889:2259와 같은
                  // 모양이라 같은 에셋을 쓴다). 그림자(흐림 2.063, 18%)는
                  // flutter_svg가 그리지 않아 SvgDropShadow로 다시 깐다.
                  Positioned(
                    top: AppLayout.personalityBubbleTop,
                    left: 0,
                    right: 0,
                    height: _bubbleSvgSize.height,
                    child: Center(
                      child: SvgDropShadow(
                        stdDeviation: 2.06324,
                        opacity: 0.18,
                        child: SvgPicture.asset(
                          'assets/images/personality_bubble.svg',
                          width: _bubbleSvgSize.width,
                          height: _bubbleSvgSize.height,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _personalities.length,
                      onPageChanged: (index) =>
                          setState(() => _selectedIndex = index),
                      itemBuilder: (context, index) {
                        final personality = _personalities[index];
                        return Stack(
                          children: [
                            Positioned(
                              top: AppLayout.personalityTitleTop,
                              left: 0,
                              right: 0,
                              child: Center(
                                // 2318:3964만 kTextDark가 아닌 #2E2E2E를 쓴다.
                                child: Text(
                                  personality.label,
                                  style: kTitleStyle.copyWith(
                                    color: kPersonalityTitle,
                                  ),
                                ),
                              ),
                            ),
                            // 태그 4534:169/171: 58.69x20.67 알약 둘, 사이 6.62.
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
                            // 대사 4534:178: Paperlogy Regular 16.506 검정, 가운데
                            // y=532.23. 옛 구현은 상자 가운데 정렬이라 4px 위였다.
                            Positioned(
                              top: AppLayout.personalityBubbleTextTop,
                              left: 0,
                              right: 0,
                              child: Text(
                                personality.dialogue,
                                textAlign: TextAlign.center,
                                style: kBodyStyle.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: AppLayout.personalityDotsTop,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: _PersonalityDots(selectedIndex: _selectedIndex),
                    ),
                  ),
                ],
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
                label: '선택',
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
    // 4534:169: 글자 길이와 관계없이 58.69x20.67 고정 알약이다. 여백으로
    // 크기를 잡으면 Flutter 글자 상자(14)만큼 높이가 24로 커졌다.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.31),
      child: Container(
        width: 58.693,
        height: 20.667,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kBackgroundWhite,
          border: Border.all(color: kTagOrange, width: 0.827),
          borderRadius: BorderRadius.circular(41.333),
        ),
        child: Text(
          label,
          style: kCaptionStyle.copyWith(
            color: kTagOrange,
            fontSize: 9.92,
            height: 1,
          ),
        ),
      ),
    );
  }
}
