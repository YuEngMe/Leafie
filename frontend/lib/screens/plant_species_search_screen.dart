import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';

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

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    final results = await _searchPlantSpecies(query);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('식물명칭 검색')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: '식물 이름을 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kBorderGreen),
                  ),
                  suffixIcon: const Icon(Icons.search),
                ),
                onSubmitted: _runSearch,
              ),
            ),
            if (_loading) const CircularProgressIndicator(),
            if (!_loading)
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final candidate = _results[index];
                    return ListTile(
                      title: Text(candidate.displayName),
                      subtitle: Text(candidate.scientificName),
                      onTap: () => Navigator.pop(context, candidate),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
