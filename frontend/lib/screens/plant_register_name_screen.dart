import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
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
  final _speciesController = TextEditingController();
  PlantSpeciesCandidate? _selectedSpecies;

  @override
  void dispose() {
    _nicknameController.dispose();
    _speciesController.dispose();
    super.dispose();
  }

  Future<void> _goToSpeciesSearch() async {
    final result = await Navigator.push<PlantSpeciesCandidate>(
      context,
      MaterialPageRoute(builder: (_) => const PlantSpeciesSearchScreen()),
    );
    if (result != null) {
      setState(() {
        _selectedSpecies = result;
        _speciesController.text = result.displayName;
      });
    }
  }

  void _goToNextStep() {
    if (_nicknameController.text.trim().isEmpty || _selectedSpecies == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('애칭과 식물명칭을 모두 입력해주세요')));
      return;
    }
    final draft = PlantRegistrationDraft(
      name: _nicknameController.text.trim(),
      species: _selectedSpecies!,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantRegisterEnvironmentScreen(draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RegisterStepScaffold(
      appBarTitle: '내 식물 등록하기',
      step: 1,
      title: '식물의 이름을 지어주세요!',
      subtitle: '당신의 식물을 뭐라고 부를까요?',
      bottomButton: PrimaryButton(label: '다음', onPressed: _goToNextStep),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
        child: Column(
          children: [
            // 캐릭터 일러스트 자리. 로고와 캐릭터 시안이 아직 확정 전이라
            // 에셋을 넣지 않고 자리만 비워 둔다(2026-08-29 팀 확인).
            const Expanded(child: SizedBox.shrink()),
            RoundedInputField(
              label: '애칭',
              hintText: '예: 쑥쑥이',
              controller: _nicknameController,
            ),
            const SizedBox(height: 20),
            RoundedInputField(
              label: '식물 명칭',
              hintText: '예: 바질 (필수)',
              controller: _speciesController,
              readOnly: true,
              onTap: _goToSpeciesSearch,
              suffix: IconButton(
                icon: const Icon(Icons.center_focus_weak, size: 22),
                color: kTextDark,
                onPressed: _goToSpeciesSearch,
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
