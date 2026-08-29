import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
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
  ];
  await Future.delayed(const Duration(milliseconds: 200));
  if (query.isEmpty) return dummyAll;
  return dummyAll
      .where((c) => c.displayName.contains(query))
      .toList(growable: false);
}

class PlantSpeciesSearchScreen extends StatefulWidget {
  const PlantSpeciesSearchScreen({super.key});

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
      step: 1,
      title: '내 식물을 찾아주세요!',
      subtitle: '검색 또는 사진으로 내 식물을 찾아요.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            RoundedInputField(
              label: '식물 명칭',
              hintText: '예: 바질',
              controller: _queryController,
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.search, size: 22),
                    color: kTextDark,
                    onPressed: () => _runSearch(_queryController.text.trim()),
                  ),
                  // 사진으로 찾기는 AI 인식 화면이 아직 없어 비활성으로 둔다.
                  IconButton(
                    icon: const Icon(Icons.center_focus_weak, size: 22),
                    color: kTextLight,
                    onPressed: null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 카드는 결과 개수만큼만 차지하고, 많으면 시안 높이(309)에서 스크롤한다.
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
    // 입력칸 아래에 겹쳐 떨어지는 흰 카드(Figma node 1841:513).
    return Container(
      constraints: const BoxConstraints(maxHeight: 309),
      decoration: BoxDecoration(
        color: kBackgroundWhite,
        borderRadius: BorderRadius.circular(27),
        boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 4)],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shrinkWrap: true,
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final candidate = _results[index];
          final highlighted = index == _highlightedIndex;
          return InkWell(
            onTap: () {
              setState(() => _highlightedIndex = index);
              Navigator.pop(context, candidate);
            },
            child: Container(
              height: 36,
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
