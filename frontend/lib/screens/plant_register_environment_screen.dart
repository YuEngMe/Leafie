import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_personality_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/app_text_field.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

// Figma "와프2차 > 캐릭터 등록_화분 선택/위치 선택" 화면 기준 (2026-08-04 확인)
const _potTypes = ['토분', '플라스틱 화분', '유리 화분', '도자기 화분', '수경재배', '기타'];
const _placements = ['베란다', '창가', '거실', '침실', '책상', '기타'];

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
  String? _potType;
  String? _placement;
  DateTime? _lastWateredOn;
  DateTime? _lastRepottedOn;

  Future<void> _pickDate(ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) onPicked(picked);
  }

  // Figma의 "화분 선택"/"위치 선택"은 바텀시트로 뜨는 2열 그리드 버튼이다.
  Future<void> _pickFromBottomSheet({
    required String title,
    required List<String> options,
    required String? current,
    required ValueChanged<String> onPicked,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: options
                    .map(
                      (option) => OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: option == current
                              ? kButtonGreen
                              : null,
                          foregroundColor: option == current
                              ? Colors.white
                              : null,
                        ),
                        onPressed: () => Navigator.pop(context, option),
                        child: Text(option),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onPicked(selected);
  }

  void _goToNextStep() {
    if (_placeNameController.text.trim().isEmpty ||
        _potType == null ||
        _placement == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('장소별명, 화분, 위치를 입력해주세요')));
      return;
    }

    widget.draft
      ..placeName = _placeNameController.text.trim()
      ..potType = _potType
      ..placement = _placement
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
    return Scaffold(
      appBar: AppBar(title: const Text('키우는 환경')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.5,
                  minHeight: 6,
                  backgroundColor: kBorderGreen,
                  color: kButtonGreen,
                ),
              ),
              const SizedBox(height: 32),

              AppTextField(
                label: '장소 별명',
                hintText: '예: 우리집 베란다',
                controller: _placeNameController,
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => _pickFromBottomSheet(
                  title: '화분 선택',
                  options: _potTypes,
                  current: _potType,
                  onPicked: (v) => setState(() => _potType = v),
                ),
                child: AbsorbPointer(
                  child: AppTextField(
                    label: '화분',
                    hintText: _potType ?? '화분을 선택해주세요',
                    controller: TextEditingController(text: _potType ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => _pickFromBottomSheet(
                  title: '위치 선택',
                  options: _placements,
                  current: _placement,
                  onPicked: (v) => setState(() => _placement = v),
                ),
                child: AbsorbPointer(
                  child: AppTextField(
                    label: '위치',
                    hintText: _placement ?? '위치를 선택해주세요',
                    controller: TextEditingController(text: _placement ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // "함께한 시작일"은 사용자가 입력하지 않는다 — 캐릭터 등록(POST /plants)
              // 시점이 곧 1일차. 완성 화면 제출 시 서버 요청 시각으로 자동 설정한다.
              // (2026-08-04 팀 확인: Figma에 입력란이 없던 이유가 이것이었음)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('마지막 물준날'),
                subtitle: Text(
                  _lastWateredOn == null
                      ? '선택 안 함'
                      : _lastWateredOn!.toIso8601String().split('T').first,
                ),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () =>
                    _pickDate((d) => setState(() => _lastWateredOn = d)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('마지막 분갈이'),
                subtitle: Text(
                  _lastRepottedOn == null
                      ? '선택 안 함 (없음/날짜모름 가능)'
                      : _lastRepottedOn!.toIso8601String().split('T').first,
                ),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () =>
                    _pickDate((d) => setState(() => _lastRepottedOn = d)),
              ),
              const SizedBox(height: 40),

              PrimaryButton(label: '다음', onPressed: _goToNextStep),
            ],
          ),
        ),
      ),
    );
  }
}
