import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_personality_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/plant_search_components.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

class PlantRegisterEnvironmentScreen extends StatefulWidget {
  const PlantRegisterEnvironmentScreen({super.key, required this.draft});

  final PlantRegistrationDraft draft;

  @override
  State<PlantRegisterEnvironmentScreen> createState() =>
      _PlantRegisterEnvironmentScreenState();
}

class _PlantRegisterEnvironmentScreenState
    extends State<PlantRegisterEnvironmentScreen> {
  final _placeNameController = TextEditingController();
  final _lastWateredController = TextEditingController();
  final _lastRepottedController = TextEditingController();
  DateTime? _lastWateredOn;
  DateTime? _lastRepottedOn;

  @override
  void dispose() {
    _placeNameController.dispose();
    _lastWateredController.dispose();
    _lastRepottedController.dispose();
    super.dispose();
  }

  String _displayDate(DateTime date) =>
      '${date.year}년 ${date.month}월 ${date.day}일';

  Future<void> _pickDate({required bool watered}) async {
    final current = watered ? _lastWateredOn : _lastRepottedOn;
    // Figma node 2318:3831. 기본 캘린더 대신 시안의 휠 피커를 띄운다.
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: kModalBarrier,
      builder: (_) =>
          PlantDatePickerSheet(initialDate: current ?? DateTime.now()),
    );
    if (picked == null) return;
    setState(() {
      if (watered) {
        _lastWateredOn = picked;
        _lastWateredController.text = _displayDate(picked);
      } else {
        _lastRepottedOn = picked;
        _lastRepottedController.text = _displayDate(picked);
      }
    });
  }

  void _goToNextStep() {
    if (_placeNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('장소를 입력해주세요')));
      return;
    }

    // 화분 종류와 실내/실외는 이 화면에 입력 수단이 없다. 기본값을 채워
    // 보내면 사용자가 고르지 않은 값이 서버에 남으므로 비운 채 넘긴다.
    // TODO(design): 시안에 화분·위치 선택이 들어오면 여기서 채운다.
    widget.draft
      ..placeName = _placeNameController.text.trim()
      ..lastWateredOn = _lastWateredOn
      ..lastRepottedOn = _lastRepottedOn;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantRegisterPersonalityScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RegisterStepScaffold(
      appBarTitle: '식물 정보',
      step: 3,
      title: '내 식물을 챙긴 날은 언제인가요?',
      subtitle: '',
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
            // 헤드라인 바닥(170)에서 첫 라벨(214)까지.
            const SizedBox(height: 44),
            RoundedInputField(
              label: '장소(별명)',
              labelIndent: AppLayout.registrationLabelIndent,
              labelGap: 5,
              height: AppLayout.onboardingControlHeight,
              hintText: '예: 베란다',
              controller: _placeNameController,
            ),
            // 칸 바닥에서 다음 라벨까지 35 — 라벨 사이가 110이 된다.
            const SizedBox(height: AppLayout.registrationFieldGap),
            RoundedInputField(
              label: '마지막 물 준 날',
              labelIndent: AppLayout.registrationLabelIndent,
              labelGap: 5,
              height: AppLayout.onboardingControlHeight,
              hintText: '선택하기',
              controller: _lastWateredController,
              readOnly: true,
              onTap: () => _pickDate(watered: true),
            ),
            const SizedBox(height: AppLayout.registrationFieldGap),
            RoundedInputField(
              label: '분갈이 한 날',
              labelIndent: AppLayout.registrationLabelIndent,
              labelGap: 5,
              height: AppLayout.onboardingControlHeight,
              hintText: '선택하기',
              controller: _lastRepottedController,
              readOnly: true,
              onTap: () => _pickDate(watered: false),
            ),
          ],
        ),
      ),
    );
  }
}
