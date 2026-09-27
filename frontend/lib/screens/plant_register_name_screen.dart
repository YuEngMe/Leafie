import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_register_body_screen.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/screens/plant_register_personality_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/services/registration_draft_store.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

class PlantRegisterNameScreen extends StatefulWidget {
  const PlantRegisterNameScreen({
    super.key,
    this.draftStore = const RegistrationDraftStore(),
  });

  final RegistrationDraftStore draftStore;

  @override
  State<PlantRegisterNameScreen> createState() =>
      _PlantRegisterNameScreenState();
}

class _PlantRegisterNameScreenState extends State<PlantRegisterNameScreen> {
  final _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerResume());
  }

  /// 앱을 껐다 켜기 전에 하던 등록이 남아 있으면 이어서 할지 묻는다.
  Future<void> _offerResume() async {
    final saved = await widget.draftStore.load();
    if (saved == null || !mounted) return;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConfirmDialog(
        message: '작성하던 식물 등록이 있어요',
        subtitle: '이어서 할까요?',
        confirmLabel: '이어서 하기',
        cancelLabel: '새로 시작',
      ),
    );
    if (!mounted) return;
    if (resume != true) {
      await widget.draftStore.clear();
      return;
    }
    _nicknameController.text = saved.name;
    // 멈췄던 단계 화면만 이 화면 위에 올린다. 그 사이 단계들은 draft에 값이
    // 이미 들어 있어 다시 거칠 필요가 없다.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _screenFor(saved)),
    );
  }

  Widget _screenFor(SavedRegistration saved) {
    final draft = saved.draft;
    if (draft == null) return PlantSpeciesSearchScreen(name: saved.name);
    return switch (saved.step) {
      RegistrationStep.species => PlantSpeciesSearchScreen(name: saved.name),
      RegistrationStep.environment => PlantRegisterEnvironmentScreen(
        draft: draft,
      ),
      RegistrationStep.personality => PlantRegisterPersonalityScreen(
        draft: draft,
      ),
      RegistrationStep.body => PlantRegisterBodyScreen(draft: draft),
      RegistrationStep.appearance => PlantRegisterAppearanceScreen(
        draft: draft,
      ),
      RegistrationStep.complete => PlantRegisterCompleteScreen(draft: draft),
    };
  }

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
      title: '리피의 이름을 지어주세요!',
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
