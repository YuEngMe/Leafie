import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/models/plant_species_candidate.dart';

/// 등록 마법사에서 마지막으로 도착한 단계. 순서가 곧 진행 순서다.
enum RegistrationStep {
  /// 애칭만 정하고 종을 고르는 중. 아직 draft가 없다.
  species,
  environment,
  personality,
  body,
  appearance,
  complete,
}

/// 앱을 껐다 켜도 이어서 할 수 있게 저장해 둔 등록 진행 상태.
class SavedRegistration {
  const SavedRegistration({required this.step, required this.name, this.draft});

  final RegistrationStep step;
  final String name;

  /// [RegistrationStep.species]에서는 종이 없어 null이다.
  final PlantRegistrationDraft? draft;
}

/// 등록 진행 상태를 기기에 저장한다.
///
/// 각 단계 화면에 들어설 때 [save]를 부르고, 등록이 끝나거나 사용자가 새로
/// 시작하면 [clear]한다. 저장·읽기 실패는 등록을 막지 않도록 조용히 넘긴다.
class RegistrationDraftStore {
  const RegistrationDraftStore();

  static const _key = 'plant_registration_draft_v1';

  Future<void> saveName(String name) =>
      _write({'step': RegistrationStep.species.name, 'name': name});

  Future<void> save(RegistrationStep step, PlantRegistrationDraft draft) =>
      _write({
        'step': step.name,
        'name': draft.name,
        'species': {
          'reference_id': draft.species.referenceId,
          'display_name': draft.species.displayName,
          'scientific_name': draft.species.scientificName,
          'category': draft.species.categorySuggestion,
          'family_name': draft.species.familyName,
          'flowering_period': draft.species.floweringPeriod,
        },
        'client_registration_id': draft.clientRegistrationId,
        'started_on': _date(draft.startedOn),
        'species_identification_id': draft.speciesIdentificationId,
        'primary_media_file_id': draft.primaryMediaFileId,
        'place_name': draft.placeName,
        'last_watered_on': _date(draft.lastWateredOn),
        'last_repotted_on': _date(draft.lastRepottedOn),
        'personality_type': draft.personalityType,
        'body_color_id': draft.bodyColorId,
        'head_item': draft.headItem,
        'body_id': draft.bodyId,
        'expression_id': draft.expressionId,
        if (draft.submissionSnapshot case final snapshot?)
          'submitted': _encodeSnapshot(snapshot),
      });

  static Map<String, Object?> _encodeSnapshot(PlantRegistrationSnapshot s) => {
    'client_registration_id': s.clientRegistrationId,
    'name': s.name,
    'species_reference_id': s.speciesReferenceId,
    'started_on': _date(s.startedOn),
    'place_name': s.placeName,
    'last_watered_on': _date(s.lastWateredOn),
    'last_repotted_on': _date(s.lastRepottedOn),
    'personality_type': s.personalityType,
    'body_id': s.bodyId,
    'body_color_id': s.bodyColorId,
    'head_item': s.headItem,
    'expression_id': s.expressionId,
    'species_identification_id': s.speciesIdentificationId,
    'primary_media_file_id': s.primaryMediaFileId,
  };

  static PlantRegistrationSnapshot _decodeSnapshot(Map<String, dynamic> j) =>
      PlantRegistrationSnapshot(
        clientRegistrationId: j['client_registration_id'] as String,
        name: j['name'] as String,
        speciesReferenceId: j['species_reference_id'] as String,
        startedOn: DateTime.parse(j['started_on'] as String),
        placeName: j['place_name'] as String,
        lastWateredOn: _parseDate(j['last_watered_on']),
        lastRepottedOn: _parseDate(j['last_repotted_on']),
        personalityType: j['personality_type'] as String,
        bodyId: j['body_id'] as String,
        bodyColorId: j['body_color_id'] as String,
        headItem: j['head_item'] as String?,
        expressionId: j['expression_id'] as String,
        speciesIdentificationId: j['species_identification_id'] as String?,
        primaryMediaFileId: j['primary_media_file_id'] as String?,
      );

  Future<SavedRegistration?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return _decode(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 저장 형식이 깨졌으면 이어하기를 포기하고 처음부터 하게 둔다.
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  Future<void> _write(Map<String, Object?> json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(json));
    } catch (_) {}
  }

  static SavedRegistration? _decode(Map<String, dynamic> json) {
    final step = RegistrationStep.values.asNameMap()[json['step']];
    final name = json['name'];
    if (step == null || name is! String || name.isEmpty) return null;
    if (step == RegistrationStep.species) {
      return SavedRegistration(step: step, name: name);
    }
    final species = PlantSpeciesCandidate.fromJson(
      json['species'] as Map<String, dynamic>,
    );
    final submittedJson = json['submitted'];
    final submitted = submittedJson is Map<String, dynamic>
        ? _decodeSnapshot(submittedJson)
        : null;
    final draft =
        PlantRegistrationDraft(
            name: name,
            species: species,
            clientRegistrationId: json['client_registration_id'] as String,
            // 아직 보낸 적 없는 등록은 이어하는 날을 1일차로 삼는다(며칠 뒤에
            // 이어해도 D+가 부풀지 않게). 이미 보냈다면 그 본문의 날짜를 지킨다.
            startedOn: submitted?.startedOn,
            speciesIdentificationId:
                json['species_identification_id'] as String?,
            primaryMediaFileId: json['primary_media_file_id'] as String?,
          )
          ..placeName = json['place_name'] as String?
          ..lastWateredOn = _parseDate(json['last_watered_on'])
          ..lastRepottedOn = _parseDate(json['last_repotted_on'])
          ..personalityType = json['personality_type'] as String?
          ..bodyColorId = json['body_color_id'] as String?
          ..headItem = json['head_item'] as String?
          ..bodyId = json['body_id'] as String?
          ..expressionId = json['expression_id'] as String?;
    if (submitted != null) draft.restoreSubmissionSnapshot(submitted);
    return SavedRegistration(step: step, name: name, draft: draft);
  }

  static String? _date(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
