import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/app_text_field.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

class PlantRegisterNameScreen extends StatefulWidget {
  const PlantRegisterNameScreen({super.key});

  @override
  State<PlantRegisterNameScreen> createState() =>
      _PlantRegisterNameScreenState();
}

class _PlantRegisterNameScreenState extends State<PlantRegisterNameScreen> {
  final _nicknameController = TextEditingController();
  String? _selectedSpeciesName;
  PlantSpeciesCandidate? _selectedSpecies;

  Future<void> _goToSpeciesSearch() async {
    final result = await Navigator.push<PlantSpeciesCandidate>(
      context,
      MaterialPageRoute(builder: (_) => const PlantSpeciesSearchScreen()),
    );
    if (result != null) {
      setState(() {
        _selectedSpecies = result;
        _selectedSpeciesName = result.displayName;
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
    return Scaffold(
      appBar: AppBar(title: const Text('내 식물 등록하기')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 등록 진행 단계 표시 (1/4 정도)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.25,
                  minHeight: 6,
                  backgroundColor: kBorderGreen,
                  color: kButtonGreen,
                ),
              ),
              const SizedBox(height: 32),

              // 캐릭터 이미지 자리 (일단 회색 네모)
              Center(
                child: Container(
                  width: 175,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              AppTextField(
                label: '애칭',
                hintText: '예: 씩씩이',
                controller: _nicknameController,
              ),
              const SizedBox(height: 16),

              // 식물명칭: 직접 입력이 아니라 검색 화면으로 이동하는 버튼
              GestureDetector(
                onTap: _goToSpeciesSearch,
                child: AbsorbPointer(
                  child: AppTextField(
                    label: '식물명칭',
                    hintText: _selectedSpeciesName ?? '식물을 검색해주세요',
                    controller: TextEditingController(
                      text: _selectedSpeciesName ?? '',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              PrimaryButton(
                label: '내 식물 등록하기',
                onPressed: _goToNextStep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
