import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/screens/plant_edit_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_edit_info_screen.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/plant_detail_components.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 시안 2564:947 "전체보기_캐릭터 상세 1".
///
/// 닉네임 / 함께한 지 N일째 / 캐릭터 / 휴지통 / 3행 메뉴 카드 / 잔디 밴드.
/// 삭제는 시안 2568:1926 모달을 거친다. 앱이 쓰던 카드 안 액션 3개
/// (이름 변경·꾸미기·삭제 TextButton)는 이 화면의 3행 메뉴로 대체됐다.
class PlantDetailScreen extends StatefulWidget {
  const PlantDetailScreen({
    super.key,
    required this.plant,
    required this.repository,
  });

  final ManagedPlant plant;
  final PlantManagementRepository repository;

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  late ManagedPlant _plant = widget.plant;
  bool _busy = false;

  Future<void> _delete() async {
    // 2568:1926. ConfirmDialog(2353:1045 계열)이 좌표까지 같아 그대로 쓴다.
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: kModalBarrier,
      builder: (_) =>
          CharacterDeleteDialog(tenureLabel: '함께한지 ${_plant.daysTogether}일이에요'),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.repository.deletePlant(_plant.id);
      if (mounted) Navigator.of(context).pop();
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openEditInfo() async {
    final updated = await Navigator.of(context).push<ManagedPlant>(
      MaterialPageRoute(
        builder: (_) =>
            PlantEditInfoScreen(plant: _plant, repository: widget.repository),
      ),
    );
    if (updated != null && mounted) setState(() => _plant = updated);
  }

  Future<void> _openAppearance() async {
    final updated = await Navigator.of(context).push<ManagedPlant>(
      MaterialPageRoute(
        builder: (_) => PlantEditAppearanceScreen(
          plant: _plant,
          repository: widget.repository,
        ),
      ),
    );
    if (updated != null && mounted) setState(() => _plant = updated);
  }

  void _openPersonality() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PlantPersonalityScreen(plant: _plant)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '캐릭터 편집'),
      body: PlantDetailBody(
        showGrass: true,
        children: [
          // 닉네임 2564:1043. 시안 top 115, 21/w600 #2E2E2E.
          PlantDetailPositioned(
            top: 115,
            height: 25,
            child: Center(
              child: Text(
                _plant.nickname,
                style: kTitleStyle.copyWith(color: kPersonalityTitle),
              ),
            ),
          ),
          // 2564:1044. top 146, 12/w400 연한 텍스트.
          PlantDetailPositioned(
            top: 146,
            height: 14,
            child: Center(
              child: Text(
                '함께한 지 ${_plant.daysTogether}일째',
                style: kCaptionStyle.copyWith(height: 1),
              ),
            ),
          ),
          // 캐릭터 2564:1045. x=114.46 y=215 176.15x201.63.
          PlantDetailPositioned(
            top: 215,
            height: 201.629,
            child: Center(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: PlantCharacterArt(width: plantArtWidthFor(176.15)),
              ),
            ),
          ),
          // 휴지통 2564:1027. x=332 y=426 25.06x26.58.
          Positioned(
            left: 332,
            top: 426 - PlantDetailBody.appBarBand,
            width: 25.057,
            height: 26.576,
            child: GestureDetector(
              key: const ValueKey('delete_plant'),
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : _delete,
              child: Semantics(
                button: true,
                label: '캐릭터 삭제',
                child: SvgPicture.asset(
                  'assets/images/plant_detail_trash.svg',
                  width: 25.057,
                  height: 26.576,
                ),
              ),
            ),
          ),
          // 상세 정보 카드 2564:1013. x=29 y=465 344x198 radius 20.
          Positioned(
            left: 29,
            top: 465 - PlantDetailBody.appBarBand,
            width: 344,
            height: 198,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kBackgroundWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 5),
                ],
              ),
            ),
          ),
          // 카드 라벨 2564:1022. x=52 y=481, 12/w400 진한 텍스트.
          Positioned(
            left: 52,
            top: 481 - PlantDetailBody.appBarBand,
            child: Text(
              '캐릭터 상세 정보',
              style: kCaptionStyle.copyWith(color: kTextDark, height: 1),
            ),
          ),
          // 3행 메뉴 2564:1014/1016/1019. 글자 top 518.76 / 567.76 / 616.76.
          PlantDetailMenuRow(
            label: '캐릭터 정보 수정',
            textTop: 518.762,
            onTap: _busy ? null : _openEditInfo,
          ),
          PlantDetailMenuRow(
            label: '꾸미기',
            textTop: 567.762,
            onTap: _busy ? null : _openAppearance,
          ),
          PlantDetailMenuRow(
            label: '성격',
            textTop: 616.762,
            onTap: _busy ? null : _openPersonality,
          ),
        ],
      ),
    );
  }
}

/// 시안 2568:1714 "캐릭터 상세_성격". 등록 흐름과 달리 고른 성격 하나만
/// 보여 주는 읽기 화면이다. 이름·태그·대사는 등록 흐름(2318:3129~3430)의
/// 글자를 그대로 쓴다.
class PlantPersonalityScreen extends StatelessWidget {
  const PlantPersonalityScreen({super.key, required this.plant});

  final ManagedPlant plant;

  @override
  Widget build(BuildContext context) {
    final personality = kPlantPersonalities[plant.personalityType];
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '캐릭터 성격'),
      body: PlantDetailBody(
        children: [
          // 성격 이름 2568:1757. top 132, 21/w600 #2E2E2E.
          PlantDetailPositioned(
            top: 132,
            height: 25,
            child: Center(
              child: Text(
                personality?.label ?? '성격 없음',
                style: kTitleStyle.copyWith(color: kPersonalityTitle),
              ),
            ),
          ),
          // 태그 칩 2568:1753/1755. y=170, 58.69x20.67, 간격 6.6.
          PlantDetailPositioned(
            top: 170,
            height: 20.667,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final tag in personality?.tags ?? const <String>[])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.31),
                    child: _PersonalityChip(label: tag),
                  ),
              ],
            ),
          ),
          // 캐릭터 2568:1871. x=103 y=287 196x168.
          PlantDetailPositioned(
            top: 287,
            height: 168,
            child: Center(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: PlantCharacterArt(width: plantArtWidthFor(196)),
              ),
            ),
          ),
          // 말풍선 2568:1759. x=74.5 y=475 253x47.05.
          PlantDetailPositioned(
            top: 475,
            height: 47.053,
            child: Center(
              child: Container(
                width: 253,
                height: 47.053,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kBackgroundWhite,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1F000000), blurRadius: 5),
                  ],
                ),
                // 2568:1762는 16.506이지만 반올림해 본문 크기를 쓴다.
                child: Text(
                  personality?.dialogue ?? '',
                  style: kBodyStyle.copyWith(
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          // 페이지 도트 2568:1744. x=152 y=561 98x8. 성격 6개 중 현재 것만
          // 켠다. 이 화면은 넘길 수 없으므로 위치 표시로만 쓴다.
          PlantDetailPositioned(
            top: 561.05,
            height: 8,
            child: Center(
              child: _PersonalityDots(
                selectedIndex: kPlantPersonalityOrder.indexOf(
                  plant.personalityType,
                ),
              ),
            ),
          ),
        ],
      ),
      // 하단 버튼 2568:1735. x=34 y=790 334x51. 성격을 바꾸는 API가 없다.
      bottomNavigationBar: const PlantDetailBottomAction(
        label: '수정하기',
        // TODO(design): PATCH /plants/{id}에 personality_type이 없어
        // '수정하기'가 열 화면이 없다. API가 생기면 성격 선택으로 잇는다.
        onPressed: null,
      ),
    );
  }
}

/// 2568:1753. 등록 흐름의 칩과 같은 모양이되 시안 크기(58.69x20.67)를 쓴다.
class _PersonalityChip extends StatelessWidget {
  const _PersonalityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58.693,
      height: 20.667,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kBackgroundWhite,
        border: Border.all(color: kTagOrange, width: 0.827),
        borderRadius: BorderRadius.circular(41.333),
      ),
      child: Text(
        label,
        style: kCaptionStyle.copyWith(
          color: kTagOrange,
          fontSize: 9.92,
          height: 1,
        ),
      ),
    );
  }
}

/// 2568:1744. 8px 원 6개, 활성만 오렌지.
class _PersonalityDots extends StatelessWidget {
  const _PersonalityDots({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < kPlantPersonalityOrder.length; index++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == selectedIndex ? kOrangeMain : kProgressInactive,
            ),
          ),
      ],
    );
  }
}
