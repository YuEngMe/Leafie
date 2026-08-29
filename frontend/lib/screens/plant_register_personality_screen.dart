import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

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

// Figma "와프2차 > 캐릭터 등록_성격4" 기준 (2026-08-04 확인).
// PersonalityType enum 6종 중 시안에 실제로 있는 3종만 우선 구현.
// 나머지(CRUSH, INTROVERTED, CHUNGCHEONG)는 체크리스트 "팀에 확인 필요한 것" 참고.
const _personalities = [
  _PersonalityOption(
    type: 'OUTGOING',
    label: '활발한 성격',
    tags: '#긍정적 #에너지',
    dialogue: '자 이제 물 줄 시간이야!',
  ),
  _PersonalityOption(
    type: 'CHIC',
    label: '시크한 성격',
    tags: '#냉소적 #츤데레',
    dialogue: '뭘 봐? 물이나 줘.',
  ),
  _PersonalityOption(
    type: 'CUTE',
    label: '귀여운 성격',
    tags: '#애교 #사랑둥이',
    dialogue: '나에게 물을 주지않을랭?',
  ),
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
  final _pageController = PageController();
  int _selectedIndex = 0;

  void _goToNextStep() {
    widget.draft.personalityType = _personalities[_selectedIndex].type;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantRegisterAppearanceScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캐릭터 성격')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.75,
                  minHeight: 6,
                  backgroundColor: kBorderGreen,
                  color: kButtonGreen,
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _personalities.length,
                onPageChanged: (index) =>
                    setState(() => _selectedIndex = index),
                itemBuilder: (context, index) {
                  final p = _personalities[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.tags,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(p.dialogue),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _personalities.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _selectedIndex
                          ? kButtonGreen
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              child: PrimaryButton(label: '다음', onPressed: _goToNextStep),
            ),
          ],
        ),
      ),
    );
  }
}
