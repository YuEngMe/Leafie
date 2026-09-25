import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

class PlantRegisterNameScreen extends StatefulWidget {
  const PlantRegisterNameScreen({super.key});

  @override
  State<PlantRegisterNameScreen> createState() =>
      _PlantRegisterNameScreenState();
}

class _PlantRegisterNameScreenState extends State<PlantRegisterNameScreen> {
  final _nicknameController = TextEditingController();

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    final name = _nicknameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('애칭을 입력해주세요')));
      return;
    }
    // 종은 다음 화면(2315:2515)에서 고른다.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlantSpeciesSearchScreen(name: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RegisterStepScaffold(
      appBarTitle: '내 식물 등록하기',
      step: 1,
      title: '식물의 이름을 지어주세요!',
      subtitle: '당신의 식물을 뭐라고 부를까요?',
      scrollable: true,
      bottomButton: PrimaryButton(
        label: '다음',
        variant: PrimaryButtonVariant.enabled,
        onPressed: _goToNextStep,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.registrationHorizontalPadding,
        ),
        child: Column(
          children: [
            // 부제 바닥(195)에서 캐릭터 top(267)까지.
            const SizedBox(height: AppLayout.registrationNameCharacterTopGap),
            const Center(
              child: PlantCharacterArt(
                width: AppLayout.registrationNameCharacterWidth,
              ),
            ),
            // 캐릭터 바닥(417)에서 애칭 라벨(493)까지.
            const SizedBox(height: AppLayout.registrationNameFieldsGap),
            RoundedInputField(
              label: '애칭',
              labelIndent: AppLayout.registrationLabelIndent,
              labelGap: 5,
              height: AppLayout.onboardingControlHeight,
              hintText: '예: 쑥쑥이',
              controller: _nicknameController,
            ),
          ],
        ),
      ),
    );
  }
}
