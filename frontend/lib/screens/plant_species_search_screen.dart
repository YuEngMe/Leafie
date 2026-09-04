import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

class PlantSpeciesCandidate {
  const PlantSpeciesCandidate({
    required this.referenceId,
    required this.displayName,
    required this.scientificName,
    required this.categorySuggestion,
  });

  final String referenceId;
  final String displayName;
  final String scientificName;
  // PlantCategory enum 값(api-spec.md). 사용자가 별도로 고르는 화면 없이
  // 검색 결과의 추천값을 그대로 POST /plants의 category로 보낸다.
  final String categorySuggestion;
}

// TODO(1-E): dio 붙이면 이 함수 내부만 GET /plant-species/search?query= 호출로 교체
Future<List<PlantSpeciesCandidate>> _searchPlantSpecies(String query) async {
  const dummyAll = [
    PlantSpeciesCandidate(
      referenceId: 'catalog:ocimum-basilicum',
      displayName: '바질',
      scientificName: 'Ocimum basilicum',
      categorySuggestion: 'HERB',
    ),
    PlantSpeciesCandidate(
      referenceId: 'catalog:monstera-deliciosa',
      displayName: '몬스테라',
      scientificName: 'Monstera deliciosa',
      categorySuggestion: 'FOLIAGE',
    ),
    PlantSpeciesCandidate(
      referenceId: 'catalog:epipremnum-aureum',
      displayName: '스킨답서스',
      scientificName: 'Epipremnum aureum',
      categorySuggestion: 'FOLIAGE',
    ),
    PlantSpeciesCandidate(
      referenceId: 'catalog:solanum-lycopersicum',
      displayName: '방울토마토',
      scientificName: 'Solanum lycopersicum',
      categorySuggestion: 'FRUIT',
    ),
    PlantSpeciesCandidate(
      referenceId: 'catalog:peperomia-tetraphylla',
      displayName: '백담청잎장',
      scientificName: 'Peperomia tetraphylla',
      categorySuggestion: 'FOLIAGE',
    ),
    PlantSpeciesCandidate(
      referenceId: 'catalog:monarda-didyma',
      displayName: '베르가못',
      scientificName: 'Monarda didyma',
      categorySuggestion: 'HERB',
    ),
  ];
  await Future.delayed(const Duration(milliseconds: 200));
  if (query.isEmpty) return dummyAll;
  return dummyAll
      .where((c) => c.displayName.contains(query))
      .toList(growable: false);
}

class PlantSpeciesSearchScreen extends StatefulWidget {
  const PlantSpeciesSearchScreen({super.key, this.name});

  /// 이름 화면(2315:2189)에서 받은 애칭. 이 값이 있으면 종을 고른 뒤
  /// 다음 단계로 넘어가고, 없으면 고른 종을 pop으로 돌려준다.
  final String? name;

  @override
  State<PlantSpeciesSearchScreen> createState() =>
      _PlantSpeciesSearchScreenState();
}

class _PlantSpeciesSearchScreenState extends State<PlantSpeciesSearchScreen> {
  final _queryController = TextEditingController();
  List<PlantSpeciesCandidate> _results = const [];
  bool _loading = false;

  // 하이라이트만 먼저 주고, 사용자가 한 번 더 눌러야 확정되는 게 아니라
  // 탭 즉시 이전 화면으로 돌려보낸다. 시안의 노란 강조는 눌리는 순간의 표시다.
  int? _highlightedIndex;

  PlantSpeciesCandidate? get _selectedCandidate {
    final i = _highlightedIndex;
    if (i == null || i >= _results.length) return null;
    return _results[i];
  }

  void _confirmSelection() {
    final candidate = _selectedCandidate;
    if (candidate == null) return;
    final name = widget.name;
    if (name == null) {
      // 이름 화면을 거치지 않고 열린 경우 — 고른 종만 돌려준다.
      Navigator.pop(context, candidate);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantRegisterEnvironmentScreen(
          draft: PlantRegistrationDraft(name: name, species: candidate),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    final results = await _searchPlantSpecies(query);
    if (mounted) {
      setState(() {
        _results = results;
        _highlightedIndex = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RegisterStepScaffold(
      appBarTitle: '내 식물 찾기',
      step: 2,
      title: '내 식물을 찾아주세요!',
      subtitle: '검색 또는 사진으로 내 식물을 찾아요.',
      bottomButton: PrimaryButton(
        label: '다음',
        variant: _selectedCandidate == null
            ? PrimaryButtonVariant.disabled
            : PrimaryButtonVariant.enabled,
        onPressed: _selectedCandidate == null ? null : _confirmSelection,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.registrationHorizontalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 부제 바닥(195)에서 식물 명칭 라벨(237)까지.
            const SizedBox(height: 42),
            RoundedInputField(
              label: '식물 명칭',
              labelIndent: AppLayout.registrationLabelIndent,
              labelGap: 5,
              height: AppLayout.onboardingControlHeight,
              hintText: '예: 바질',
              controller: _queryController,
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const FigmaSearchIcon(),
                    onPressed: () => _runSearch(_queryController.text.trim()),
                  ),
                  // 사진으로 찾기는 AI 인식 화면이 아직 없어 비활성으로 둔다.
                  const IconButton(icon: FigmaCameraIcon(), onPressed: null),
                ],
              ),
            ),
            // 카드는 결과 개수만큼만 차지하고, 많으면 시안 높이(289)에서
            // 스크롤한다.
            Flexible(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kOrangeMain));
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text('검색 결과가 없어요', style: kSmallStyle),
      );
    }
    // 입력칸 뒤로 이어지는 흰 카드(Figma node 2318:3721). pill과 맞붙으므로
    // 위쪽 모서리는 굴리지 않는다.
    return Container(
      constraints: const BoxConstraints(maxHeight: 289),
      decoration: const BoxDecoration(
        color: kBackgroundWhite,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(27)),
        boxShadow: [BoxShadow(color: Color(0x2E000000), blurRadius: 4)],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        // 2318:3721 카드 top에서 첫 텍스트까지 44px, 행 간격은 36px.
        padding: const EdgeInsets.only(top: 33, bottom: 12),
        itemExtent: 36,
        shrinkWrap: true,
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final candidate = _results[index];
          final highlighted = index == _highlightedIndex;
          return InkWell(
            // 시안(2315:2582)은 고른 항목을 노랗게 표시만 하고, 넘어가는
            // 것은 하단 '다음' 버튼이 맡는다.
            onTap: () => setState(() => _highlightedIndex = index),
            child: Container(
              // 2318:3722 하이라이트 밴드 높이.
              height: 33,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: highlighted ? kOrangeMain.withValues(alpha: 0.43) : null,
              child: Text(
                candidate.displayName,
                style: kCaptionStyle.copyWith(color: const Color(0xFF1F2E21)),
              ),
            ),
          );
        },
      ),
    );
  }
}
