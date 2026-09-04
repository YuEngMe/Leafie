import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/plant_search_components.dart';
import 'package:yeso_plant/widgets/register_progress_bar.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 사진 한 장으로 종을 알아내는 흐름의 결과.
class PlantIdentification {
  const PlantIdentification({
    required this.candidate,
    required this.familyName,
    required this.bloomSeason,
  });

  final PlantSpeciesCandidate candidate;

  /// 시안 2318:2947 '돌나무과'.
  final String familyName;

  /// 시안 2318:2949 '8월 ~ 9월'.
  final String bloomSeason;
}

/// 사진을 넘기면 종을 알려주는 함수. 테스트가 갈아끼운다.
typedef PlantIdentifier = Future<PlantIdentification> Function(File photo);

// TODO(1-E): dio 붙이면 사진을 올려 AI 인식 결과를 받는 API로 바꾼다.
// 지금은 시안(2318:2890)이 보여주는 값을 그대로 돌려준다.
Future<PlantIdentification> _identifyPlant(File photo) async {
  await Future<void>.delayed(const Duration(milliseconds: 1800));
  return const PlantIdentification(
    candidate: PlantSpeciesCandidate(
      referenceId: 'catalog:sedum-polytrichoides',
      displayName: '바위채송화',
      scientificName: 'Sedum polytrichoides',
      categorySuggestion: 'SUCCULENT',
    ),
    familyName: '돌나무과',
    bloomSeason: '8월 ~ 9월',
  );
}

/// Figma "캐릭터 등록6"(2318:2815)과 "등록7"(2318:2890).
///
/// 분석 중 화면을 먼저 띄우고, 끝나면 같은 화면에서 결과 카드로 바뀐다.
class PlantPhotoIdentifyScreen extends StatefulWidget {
  const PlantPhotoIdentifyScreen({
    super.key,
    required this.photo,
    required this.name,
    this.identifier,
  });

  /// 촬영하거나 앨범에서 고른 사진.
  final File photo;

  /// 이름 화면에서 받은 애칭.
  final String name;

  final PlantIdentifier? identifier;

  @override
  State<PlantPhotoIdentifyScreen> createState() =>
      _PlantPhotoIdentifyScreenState();
}

class _PlantPhotoIdentifyScreenState extends State<PlantPhotoIdentifyScreen> {
  PlantIdentification? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final result = await (widget.identifier ?? _identifyPlant)(widget.photo);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _accept(PlantIdentification result) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlantRegisterEnvironmentScreen(
          draft: PlantRegistrationDraft(
            name: widget.name,
            species: result.candidate,
          ),
        ),
      ),
    );
  }

  /// 시안에 '아니에요' 뒤 화면이 없다. 직접 찾도록 검색으로 돌려보낸다.
  void _reject() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '내 식물 등록하기'),
      body: SafeArea(
        child: _error != null
            ? _IdentifyFailed(onRetry: _reject)
            : result == null
            ? const _Analyzing()
            : _IdentifyResult(
                photo: widget.photo,
                result: result,
                onAccept: () => _accept(result),
                onReject: _reject,
              ),
      ),
    );
  }
}

/// Figma node 2318:2815. 캐릭터 아래 진행 막대가 도는 대기 화면.
class _Analyzing extends StatelessWidget {
  const _Analyzing();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 2318:2858 y=205, 2318:2859 중심 y=248.
        const Positioned(
          left: 0,
          right: 0,
          top: 113,
          child: Text(
            'AI가 식물을 분석하고 있어요',
            textAlign: TextAlign.center,
            style: kTitleStyle,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 149,
          child: Text(
            '잠시만 기다려주세요..',
            textAlign: TextAlign.center,
            style: kSmallStyle.copyWith(height: 1, color: kOnboardingSubtitle),
          ),
        ),
        // 2318:2844 x=148 y=375, 94x104.
        const Positioned(
          left: 0,
          right: 0,
          top: 283,
          child: Center(child: PlantCharacterArt(width: 94)),
        ),
        // 2318:2846 트랙 180x7, 2318:2847 채움 126.768.
        const Positioned(
          left: 0,
          right: 0,
          top: 400,
          child: Center(child: _AnalyzingBar()),
        ),
      ],
    );
  }
}

/// 시안(2318:2847)은 180 중 126.768을 채운 한 장면이다. 실제로는 도는
/// 막대라 그 비율을 최대치로 두고 반복한다.
class _AnalyzingBar extends StatefulWidget {
  const _AnalyzingBar();

  @override
  State<_AnalyzingBar> createState() => _AnalyzingBarState();
}

class _AnalyzingBarState extends State<_AnalyzingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const trackWidth = 180.0;
    const height = 7.0;
    return SizedBox(
      width: trackWidth,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kGaugeTrack,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => SizedBox(
              width: trackWidth * 0.7043 * _controller.value,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kOrangeMain,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma node 2318:2890. 폴라로이드 카드와 맞아요/아니에요.
class _IdentifyResult extends StatelessWidget {
  const _IdentifyResult({
    required this.photo,
    required this.result,
    required this.onAccept,
    required this.onReject,
  });

  final File photo;
  final PlantIdentification result;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Center(child: RegisterProgressBar(step: 2)),
        ),
        // 2318:2928 중심 y=179.5.
        Positioned(
          left: 0,
          right: 0,
          // 2318:2928 중심 y=179.5, 글자 상자 top 169. 앱바 아래(92) 기준.
          top: 77,
          child: Text(
            '이 식물은 ${result.candidate.displayName}이군요?',
            textAlign: TextAlign.center,
            style: kTitleStyle.copyWith(color: kPersonalityTitle),
          ),
        ),
        // 2318:2931 카드 묶음 top=238.62.
        Positioned(
          left: 0,
          right: 0,
          top: 146.62,
          child: Center(
            child: PlantResultCard(
              imageProvider: FileImage(photo),
              speciesName: result.candidate.displayName,
              familyName: result.familyName,
              bloomSeason: result.bloomSeason,
            ),
          ),
        ),
        // 2318:2965 버튼 top=759.
        Positioned(
          left: 0,
          right: 0,
          top: 667,
          child: Center(
            child: PlantResultConfirmButtons(
              onConfirm: onAccept,
              onReject: onReject,
            ),
          ),
        ),
      ],
    );
  }
}

class _IdentifyFailed extends StatelessWidget {
  const _IdentifyFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.registrationHorizontalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '사진으로 찾지 못했어요',
              style: kTitleStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '검색으로 다시 찾아볼까요?',
              style: kSmallStyle.copyWith(color: kOnboardingSubtitle),
            ),
            const SizedBox(height: 24),
            TextButton(onPressed: onRetry, child: const Text('돌아가기')),
          ],
        ),
      ),
    );
  }
}
