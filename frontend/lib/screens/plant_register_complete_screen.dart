import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

String _isoDate(DateTime d) => d.toIso8601String().split('T').first;

// TODO(1-E): dio 붙이면 이 함수 내부만 POST /plants 실제 호출로 교체.
// 지금은 등록 흐름이 끝까지 이어지는지 확인하기 위한 가짜 성공 응답.
// 요청 본문 형태는 api-spec.md의 POST /plants 예시를 그대로 따른다.
Future<String> _submitPlantRegistration(PlantRegistrationDraft draft) async {
  // started_on은 사용자가 입력하지 않는다. 캐릭터 등록(이 요청)을 보내는 시점이
  // 곧 함께한 1일차이므로 제출 시각을 그대로 쓴다(2026-08-04 팀 확인).
  // 서버가 자기 시각 기준으로 다시 계산해 덮어쓸 수도 있음 — 참고용으로만 보낸다.
  final startedOn = DateTime.now();

  // dio 붙이면 이 requestBody를 그대로 POST /plants의 body로 전달하면 된다.
  final requestBody = <String, Object?>{
    'name': draft.name,
    'category': draft.species.categorySuggestion,
    'species_name': draft.species.displayName,
    'species_scientific_name': draft.species.scientificName,
    'species_reference_id': draft.species.referenceId,
    'species_selection_method': 'SEARCH',
    'started_on': _isoDate(startedOn),
    'character': {
      'base_type': 'SPROUT',
      'body_color': draft.bodyColorId,
      'head_item': draft.headItem,
      'accessory': draft.accessory,
      'personality_type': draft.personalityType,
    },
    'environment': {
      'place_name': draft.placeName,
      'pot_type': draft.potType,
      'placement': draft.placement,
    },
    'initial_care': {
      'last_watered_on': draft.lastWateredOn == null
          ? null
          : _isoDate(draft.lastWateredOn!),
      'last_repotted_on': draft.lastRepottedOn == null
          ? null
          : _isoDate(draft.lastRepottedOn!),
    },
  };
  await Future.delayed(const Duration(milliseconds: 400));
  debugPrint('POST /plants (dummy) body: $requestBody');
  return 'fake-plant-id'; // 실제 연동 시 응답의 id를 반환
}

class PlantRegisterCompleteScreen extends StatefulWidget {
  const PlantRegisterCompleteScreen({super.key, required this.draft});

  final PlantRegistrationDraft draft;

  @override
  State<PlantRegisterCompleteScreen> createState() =>
      _PlantRegisterCompleteScreenState();
}

class _PlantRegisterCompleteScreenState
    extends State<PlantRegisterCompleteScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await _submitPlantRegistration(widget.draft);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeScreen(plantName: widget.draft.name),
          ),
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Scaffold(
      appBar: AppBar(title: const Text('캐릭터 만들기')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Text(
                '당신의 식물 친구가 생겼어요!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                width: 175,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('애칭: ${draft.name}'),
                      Text('식물명칭: ${draft.species.displayName}'),
                      Text('장소: ${draft.placeName ?? '-'}'),
                      Text('화분: ${draft.potType ?? '-'}'),
                      Text('위치: ${draft.placement ?? '-'}'),
                      Text('성격: ${draft.personalityType ?? '-'}'),
                    ],
                  ),
                ),
              ),
              PrimaryButton(
                label: _submitting ? '등록 중...' : '다음',
                onPressed: _submitting ? () {} : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
