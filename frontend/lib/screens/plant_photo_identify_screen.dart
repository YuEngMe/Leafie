import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/models/plant_species_candidate.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/services/plant_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_motion.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_search_components.dart';
import 'package:yeso_plant/widgets/register_progress_bar.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 사진 한 장으로 종을 알아내는 흐름의 결과.
class PlantIdentification {
  const PlantIdentification({
    required this.candidate,
    required this.familyName,
    required this.bloomSeason,
    this.identificationId,
    this.mediaFileId,
  });

  final PlantSpeciesCandidate candidate;

  /// 시안 2318:2947 '돌나무과'.
  final String familyName;

  /// 시안 2318:2949 '8월 ~ 9월'.
  final String bloomSeason;
  final String? identificationId;
  final String? mediaFileId;
}

/// 사진을 넘기면 종을 알려주는 함수. 테스트가 갈아끼운다.
typedef PlantIdentifier = Future<PlantIdentification> Function(File photo);

Future<PlantIdentification> _identifyPlant(File photo) async {
  final result = await PlantApi().identifySpecies(await photo.readAsBytes());
  return PlantIdentification(
    candidate: result.candidate,
    familyName: result.candidate.familyName ?? '정보 없음',
    bloomSeason: result.candidate.floweringPeriod ?? '정보 없음',
    identificationId: result.identificationId,
    mediaFileId: result.mediaFileId,
  );
}

/// Figma "캐릭터 등록6"(4889:421)과 "등록7"(2318:2890).
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
            speciesIdentificationId: result.identificationId,
            primaryMediaFileId: result.mediaFileId,
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
      // 시안 4889:421 분석 중 화면은 앱바 제목 없이 꺾쇠만 있다.
      appBar: YesoAppBar(
        title: result == null && _error == null ? '' : '내 식물 등록하기',
      ),
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

/// Figma node 4889:421(LF-018). 주황 캐릭터 셋 아래에 문구를 둔 대기 화면.
///
/// 옛 시안 2318:2815는 노란 캐릭터 하나와 진행 막대였다. 최신 시안에는
/// 막대도 모션 데이터도 없다(get_motion_context 빈 결과). 그대로 두면 분석이
/// 길어질 때 화면이 멈춘 것처럼 보여, 세 캐릭터가 차례로 살짝 뛰게 한다
/// (_AnalyzingCharacters). 쉬는 자세는 시안 좌표 그대로다.
/// 좌표는 앱바 아래(상태바 46 + 앱바 46 = 92) 기준이다.
class _Analyzing extends StatelessWidget {
  const _Analyzing();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 4889:445 묶음 x=129 y=363, 144x42.4.
        const Positioned(
          left: 129,
          top: 271,
          child: _AnalyzingCharacters(key: ValueKey('analyzing-characters')),
        ),
        // 4889:442 x=80 y=458, 왼쪽 정렬. Flutter 글자가 시안보다 3~4px 넓어
        // 가운데 정렬하면 왼쪽 끝이 어긋나므로 시안처럼 왼쪽 끝을 맞춘다.
        // 글자 상자(29)가 시안(24)보다 커서, 보이는 글자 top이 시안 렌더(461)에
        // 오도록 상자 top을 456(92 + 364)으로 둔다.
        Positioned(
          left: 80,
          top: 364,
          child: Text(
            'AI가 식물을 분석하고 있어요',
            style: kTitleStyle.copyWith(fontSize: 20),
          ),
        ),
        // 4889:443 중심 x=202.5 y=501. left 3이면 가운데가 202.5가 된다.
        // 보이는 글자 top 495(시안 렌더와 같음).
        Positioned(
          left: 3,
          right: 0,
          top: 400,
          child: Text(
            '잠시만 기다려주세요..',
            textAlign: TextAlign.center,
            style: kSmallStyle.copyWith(color: kOnboardingSubtitle),
          ),
        ),
      ],
    );
  }
}

/// 4889:445. 둥근·유령·네모 몸통(#FFB52A)에 같은 얼굴(4889:455/459/463)을
/// 얹는다. 세 얼굴 SVG는 소수점 넷째 자리까지만 달라 한 파일을 쓴다.
///
/// 분석을 기다리는 동안 왼쪽부터 하나씩 [_hopHeight]만큼 뛰었다 내려온다.
/// 한 바퀴의 시작과 끝은 모두 시안 자리라 첫 프레임은 정지 화면과 같다.
/// 동작 줄이기 설정에서는 뛰지 않는다.
class _AnalyzingCharacters extends StatefulWidget {
  const _AnalyzingCharacters({super.key});

  @override
  State<_AnalyzingCharacters> createState() => _AnalyzingCharactersState();
}

class _AnalyzingCharactersState extends State<_AnalyzingCharacters>
    with SingleTickerProviderStateMixin {
  // (몸통, 얼굴) 묶음. 묶음 왼쪽 위(129, 363) 기준 좌표.
  static const _characters =
      <((String, double, double, double, double), (double, double))>[
        (
          ('identify_analyzing_body_round', 0, 0.48, 45.494, 41.906),
          (11.03, 18.23),
        ), // 4889:447·455
        (
          ('identify_analyzing_body_ghost', 50.85, 0, 42.699, 40.772),
          (60.92, 16.79),
        ), // 4889:452·459
        (
          ('identify_analyzing_body_square', 99.30, 1.52, 44.705, 39.161),
          (110.32, 16.79),
        ), // 4889:454·463
      ];
  static const _faceWidth = 23.214;
  static const _faceHeight = 10.073;

  /// 한 바퀴: 셋이 차례로 뛰고 잠깐 쉰다.
  static const _cycle = Duration(milliseconds: 1500);

  /// 한 캐릭터가 뛰었다 내려오는 시간과 다음 캐릭터가 출발하는 간격.
  static const _hop = 420.0;
  static const _stagger = 180.0;
  static const _hopHeight = 6.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [index]번째 캐릭터의 위쪽 이동량(0 이하).
  double _lift(int index) {
    final ms = _controller.value * _cycle.inMilliseconds - index * _stagger;
    if (ms <= 0 || ms >= _hop) return 0;
    // 출발·도착이 부드러운 반원 궤적.
    return -_hopHeight * math.sin(math.pi * ms / _hop);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 144.005,
      height: 42.386,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (
                    index,
                    ((name, left, top, width, height), (faceLeft, faceTop)),
                  )
                  in _characters.indexed) ...[
                Positioned(
                  left: left,
                  top: top + _lift(index),
                  child: SvgPicture.asset(
                    'assets/images/$name.svg',
                    width: width,
                    height: height,
                  ),
                ),
                Positioned(
                  left: faceLeft,
                  top: faceTop + _lift(index),
                  child: SvgPicture.asset(
                    'assets/images/identify_analyzing_face.svg',
                    width: _faceWidth,
                    height: _faceHeight,
                  ),
                ),
              ],
            ],
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
          child: _RevealIn(
            child: Text(
              '이 식물은 ${result.candidate.displayName}이군요?',
              textAlign: TextAlign.center,
              style: kTitleStyle.copyWith(color: kPersonalityTitle),
            ),
          ),
        ),
        // 2318:2931 카드 묶음 top=238.62.
        Positioned(
          left: 0,
          right: 0,
          top: 146.62,
          child: Center(
            child: _RevealIn(
              key: const ValueKey('identify-result-card'),
              rise: 24,
              duration: const Duration(milliseconds: 500),
              child: PlantResultCard(
                imageProvider: FileImage(photo),
                speciesName: result.candidate.displayName,
                familyName: result.familyName,
                bloomSeason: result.bloomSeason,
              ),
            ),
          ),
        ),
        // 2318:2965 버튼 top=759.
        Positioned(
          left: 0,
          right: 0,
          top: 667,
          child: Center(
            child: _RevealIn(
              child: PlantResultConfirmButtons(
                onConfirm: onAccept,
                onReject: onReject,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 분석 화면에서 결과로 바뀔 때 한 번 재생하는 등장. [rise]만큼 아래에서
/// 떠오르며 투명도가 0에서 1로 올라간다(rise 0이면 페이드만).
///
/// 식물마다 한 번뿐인 "이 식물은 ○○이군요?" 순간이라 디자이너 확인을 거쳐
/// 결과 카드가 떠오르며 등장하게 했다. 모션을 끈 사용자에게는 움직임 없이
/// 페이드만 남긴다.
class _RevealIn extends StatelessWidget {
  const _RevealIn({
    super.key,
    required this.child,
    this.rise = 0,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final double rise;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: AppMotion.easeOut,
      // 투명도·위치가 바뀌는 동안 카드(사진 포함)를 다시 그리지 않게 한다.
      child: RepaintBoundary(child: child),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, reduceMotion ? 0 : rise * (1 - t)),
          child: child,
        ),
      ),
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
