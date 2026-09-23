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
    setState(() => _busy = true);
    late final ManagedPlant detail;
    try {
      detail = await widget.repository.getPlant(_plant.id);
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    final editablePlant = detail.copyWith(isSelected: _plant.isSelected);
    setState(() {
      _plant = editablePlant;
      _busy = false;
    });
    final updated = await Navigator.of(context).push<ManagedPlant>(
      MaterialPageRoute(
        builder: (_) => PlantEditInfoScreen(
          plant: editablePlant,
          repository: widget.repository,
        ),
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

  Future<void> _openPersonality() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => PlantPersonalityScreen(plant: _plant)),
    );
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.repository.updatePlant(
        _plant.id,
        personalityType: selected,
      );
      if (mounted) setState(() => _plant = updated);
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: YesoAppBar(
        title: '캐릭터 편집',
        actions: _busy
            ? const [
                Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      color: kOrangeMain,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ]
            : null,
      ),
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
          // 캐릭터 4534:7390(5038:6743): circle 몸통 폭 139.78, 바닥 y=436.4,
          // 헤어 꼭대기 y≈169(날짜 문구 아래). 헤어가 박스 위로 솟으므로 박스를
          // 몸통 바닥 기준으로 둔다(박스 위 y=299.8).
          PlantDetailPositioned(
            top: 299.8,
            height: plantArtWidthFor(139.78) * 649 / 698,
            child: Center(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: PlantCharacterArt(
                  width: plantArtWidthFor(139.78),
                  body: plantBodyFromId(_plant.bodyId),
                  colorId: _plant.colorId,
                  hairId: _plant.hairId,
                ),
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

/// 시안 2568:1714 "캐릭터 상세_성격". 진입 시 현재 성격을 선택 상태로
/// 시작하고, 좌우로 넘겨 6종 중 하나를 고른 뒤 "수정하기"로 반환한다.
/// 이름·태그·대사는 등록 흐름(2318:3129~3430)의 글자를 그대로 쓴다.
class PlantPersonalityScreen extends StatefulWidget {
  const PlantPersonalityScreen({super.key, required this.plant});

  final ManagedPlant plant;

  @override
  State<PlantPersonalityScreen> createState() =>
      _PlantPersonalityScreenState();
}

class _PlantPersonalityScreenState extends State<PlantPersonalityScreen> {
  late int _selectedIndex = kPlantPersonalityOrder.indexOf(
    widget.plant.personalityType,
  ).clamp(0, kPlantPersonalityOrder.length - 1);
  late final PageController _pageController = PageController(
    initialPage: _selectedIndex,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= kPlantPersonalityOrder.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = kPlantPersonalityOrder[_selectedIndex];
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '캐릭터 성격'),
      body: PlantDetailBody(
        children: [
          // 이름(top132)+태그(top170)+캐릭터(top287)+대사(top475,
          // height47.053, 즉 끝 522.053)를 한 PageView 페이지로 묶어
          // 손가락 따라 통째로 슬라이드되게 한다. 각 요소는 페이지 내부
          // Stack에서 이 슬롯의 top(132)을 뺀 상대좌표로 앉혀 시안의
          // 절대 top 값을 그대로 지킨다.
          PlantDetailPositioned(
            top: 132,
            height: 522.053 - 132,
            child: PageView.builder(
              controller: _pageController,
              itemCount: kPlantPersonalityOrder.length,
              onPageChanged: (index) => setState(() => _selectedIndex = index),
              itemBuilder: (context, index) {
                final type = kPlantPersonalityOrder[index];
                final personality = kPlantPersonalities[type];
                return Stack(
                  children: [
                    // 성격 이름 2568:1757. top 132 -> 상대 0.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 25,
                      child: Center(
                        child: Text(
                          personality?.label ?? '성격 없음',
                          style: kTitleStyle.copyWith(
                            color: kPersonalityTitle,
                          ),
                        ),
                      ),
                    ),
                    // 태그 칩 2568:1753/1755. top 170 -> 상대 38.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 170 - 132,
                      height: 20.667,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final tag in personality?.tags ?? const <String>[])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3.31,
                              ),
                              child: _PersonalityChip(label: tag),
                            ),
                        ],
                      ),
                    ),
                    // 캐릭터. 원래 시안(2568:1714)이 사라져 등록 성격 화면
                    // (5460:721) 비율을 쓴다. 몸통 바닥을 말풍선 위 12(y=463)에
                    // 두고, 가장 긴 헤어(산세베리아)가 태그 아래에서 시작하도록
                    // 몸통 폭을 134(= 149.4 × 0.897)로 맞췄다. 박스 위 y=332.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 332 - 132,
                      height: 149.4 * 649 / 698,
                      child: Center(
                        child: OverflowBox(
                          maxWidth: double.infinity,
                          maxHeight: double.infinity,
                          child: PlantCharacterArt(
                            width: 149.4,
                            body: plantBodyFromId(widget.plant.bodyId),
                            colorId: widget.plant.colorId,
                            hairId: widget.plant.hairId,
                          ),
                        ),
                      ),
                    ),
                    // 말풍선 2568:1759. top 475 -> 상대 343.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 475 - 132,
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
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 5,
                              ),
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
                  ],
                );
              },
            ),
          ),
          // 페이지 도트 2568:1744. x=152 y=561 98x8. 성격 6개 중 선택된
          // 것을 켜고, 탭해서도 넘길 수 있게 한다.
          PlantDetailPositioned(
            top: 561.05,
            height: 8,
            child: Center(
              child: _PersonalityDots(
                selectedIndex: _selectedIndex,
                onTapIndex: _goTo,
              ),
            ),
          ),
        ],
      ),
      // 하단 버튼 2568:1735. x=34 y=790 334x51. 선택한 성격을 상위로
      // 반환한다.
      bottomNavigationBar: PlantDetailBottomAction(
        label: '수정하기',
        onPressed: () => Navigator.of(context).pop(selectedType),
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

/// 2568:1744. 8px 원 6개, 활성만 오렌지. 탭해서도 넘길 수 있다.
class _PersonalityDots extends StatelessWidget {
  const _PersonalityDots({required this.selectedIndex, this.onTapIndex});

  final int selectedIndex;
  final ValueChanged<int>? onTapIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < kPlantPersonalityOrder.length; index++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapIndex == null ? null : () => onTapIndex!(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == selectedIndex
                    ? kOrangeMain
                    : kProgressInactive,
              ),
            ),
          ),
      ],
    );
  }
}
