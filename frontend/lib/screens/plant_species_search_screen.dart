import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/models/plant_species_candidate.dart';
import 'package:yeso_plant/screens/plant_photo_identify_screen.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_api.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/register_step_scaffold.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

export 'package:yeso_plant/models/plant_species_candidate.dart';

typedef PlantSpeciesSearch =
    Future<List<PlantSpeciesCandidate>> Function(String query);
typedef PlantPhotoPicker = Future<File?> Function();

/// 검색 전에도 시안의 결과 카드 구조를 유지하되, 서버 카탈로그에 실제 존재하는
/// 종만 추천한다. 검색 버튼을 누르면 이 목록은 API 결과로 교체된다.
const initialPlantSuggestions = [
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
    referenceId: 'catalog:philodendron-hederaceum',
    displayName: '필로덴드론',
    scientificName: 'Philodendron hederaceum',
    categorySuggestion: 'FOLIAGE',
  ),
  PlantSpeciesCandidate(
    referenceId: 'catalog:hedera-helix',
    displayName: '아이비',
    scientificName: 'Hedera helix',
    categorySuggestion: 'FOLIAGE',
  ),
  PlantSpeciesCandidate(
    referenceId: 'catalog:zamioculcas-zamiifolia',
    displayName: '금전수',
    scientificName: 'Zamioculcas zamiifolia',
    categorySuggestion: 'FOLIAGE',
  ),
];

Future<List<PlantSpeciesCandidate>> searchPlantSpecies(String query) =>
    PlantApi().searchSpecies(query);

class PlantSpeciesSearchScreen extends StatefulWidget {
  const PlantSpeciesSearchScreen({
    super.key,
    this.name,
    this.search,
    this.photoPicker,
  });

  /// 이름 화면(2315:2189)에서 받은 애칭. 이 값이 있으면 종을 고른 뒤
  /// 다음 단계로 넘어가고, 없으면 고른 종을 pop으로 돌려준다.
  final String? name;

  /// 네트워크 없이 화면 상태를 검증할 때 갈아끼운다.
  final PlantSpeciesSearch? search;
  final PlantPhotoPicker? photoPicker;

  @override
  State<PlantSpeciesSearchScreen> createState() =>
      _PlantSpeciesSearchScreenState();
}

class _PlantSpeciesSearchScreenState extends State<PlantSpeciesSearchScreen> {
  final _queryController = TextEditingController();
  List<PlantSpeciesCandidate> _results = initialPlantSuggestions;
  bool _loading = false;
  int _searchGeneration = 0;

  // 하이라이트만 먼저 주고, 사용자가 한 번 더 눌러야 확정되는 게 아니라
  // 탭 즉시 이전 화면으로 돌려보낸다. 시안의 노란 강조는 눌리는 순간의 표시다.
  int? _highlightedIndex;

  PlantSpeciesCandidate? get _selectedCandidate {
    final i = _highlightedIndex;
    if (i == null || i >= _results.length) return null;
    return _results[i];
  }

  Future<void> _pickPhoto() async {
    final name = widget.name;
    if (name == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('식물 이름을 먼저 입력해주세요.')));
      return;
    }
    try {
      final photo = await (widget.photoPicker ?? _pickCameraPhoto)();
      if (photo == null || !mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlantPhotoIdentifyScreen(photo: photo, name: name),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진을 불러오지 못했어요.')));
    }
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
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final generation = ++_searchGeneration;
    final normalized = query.trim();
    if (normalized.isEmpty) {
      setState(() {
        _results = initialPlantSuggestions;
        _highlightedIndex = null;
        _loading = false;
      });
      return;
    }
    if (normalized.length < 2) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('검색어를 두 글자 이상 입력해 주세요.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await (widget.search ?? searchPlantSpecies)(normalized);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = results;
        _highlightedIndex = null;
        _loading = false;
      });
    } on LeafieApiException catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = const [];
        _highlightedIndex = null;
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = const [];
        _highlightedIndex = null;
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('식물을 검색하지 못했어요.')));
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
                  IconButton(
                    icon: const FigmaCameraIcon(),
                    onPressed: _pickPhoto,
                  ),
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

Future<File?> _pickCameraPhoto() async {
  final photo = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 85,
  );
  return photo == null ? null : File(photo.path);
}
