import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_letter.dart';
import 'package:yeso_plant/screens/mailbox_screen.dart';
import 'package:yeso_plant/screens/calendar_screen.dart';
import 'package:yeso_plant/screens/diagnosis_screen.dart';
import 'package:yeso_plant/screens/diary_screen.dart';
import 'package:yeso_plant/screens/notification_screen.dart';
import 'package:yeso_plant/screens/plant_management_screen.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/services/home_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/main_tab_shell.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/home_components.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';

/// 홈 API가 반환한 등록 식물 정보.
class HomePlant {
  const HomePlant({
    required this.name,
    required this.startedOn,
    required this.personalityType,
    this.id,
    this.daysTogether,
  });

  final String name;
  final String? id;
  final DateTime? startedOn;
  final String? personalityType;
  final int? daysTogether;

  /// 등록한 날이 1일차다(2026-08-04 팀 확인).
  int get dayCount {
    final serverDays = daysTogether;
    if (serverDays != null) return serverDays < 1 ? 1 : serverDays;
    return startedOn == null
        ? 1
        : DateTime.now().difference(startedOn!).inDays + 1;
  }
}

/// Figma 3441:2에 있는 시간대별 홈 배경 상태.
enum HomeTimePeriod {
  day(asset: 'assets/images/home_bg_default.png', phaseIcon: FigmaHomeIcon.sun),
  afternoon(
    asset: 'assets/images/home_bg_afternoon.png',
    phaseIcon: FigmaHomeIcon.afternoon,
  ),
  evening(
    asset: 'assets/images/home_bg_evening.png',
    phaseIcon: FigmaHomeIcon.moon,
  ),
  lateEvening(
    asset: 'assets/images/home_bg_late_evening.png',
    phaseIcon: FigmaHomeIcon.moon,
  );

  const HomeTimePeriod({required this.asset, required this.phaseIcon});

  final String asset;
  final FigmaHomeIcon phaseIcon;

  /// 00~03 오후2, 03~06 오후, 06~15 기본, 15~18 오후,
  /// 18~19 오후2, 19~24 늦저녁 순서로 전환한다.
  static HomeTimePeriod fromDateTime(DateTime dateTime) {
    return switch (dateTime.hour) {
      >= 0 && < 3 => evening,
      >= 3 && < 6 => afternoon,
      >= 6 && < 15 => day,
      >= 15 && < 18 => afternoon,
      >= 18 && < 19 => evening,
      _ => lateEvening,
    };
  }

  /// 방이름: 늦저녁(2431:14981)만 `#CCCBCB`, 나머지는 진한 텍스트.
  Color get titleColor => this == lateEvening ? kGrayLightest : kTextDark;

  /// D+와 알림 벨: 주간은 진한 텍스트·오렌지, 그 외 세 시간대는 연노랑
  /// `#FFECA6`(2431:14986, 3429:1965).
  Color get counterColor => this == day ? kTextDark : kPaleYellow;
  Color get notificationColor => this == day ? kOrangeMain : kPaleYellow;
}

/// Figma 3441:2의 대표 홈 대화 상태.
/// idle은 말풍선 없음(2590:12165), happy는 "히히/신난다/좋은 하루야!" 세 개
/// (2346:479 등 6프레임). happy를 띄우는 조건은 팀 확인 대기(TODOLIST).
enum HomeScene { idle, happy, needsWater, needsLight, cared }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.plant,
    this.period,
    this.initialScene = HomeScene.idle,
    this.initialGaugesExpanded = true,
    this.loadHome,
    this.loadHomeForPlant,
    this.plantRepository,
    this.notificationBuilder,
    this.plantManagementBuilder,
    this.letterRepository,
  });

  /// 등록 직후 서버에 보낸 snapshot을 바로 표시할 때만 전달한다.
  final HomePlant? plant;
  final PlantLetterRepository? letterRepository;
  final HomeTimePeriod? period;
  final HomeScene initialScene;
  final bool initialGaugesExpanded;

  /// 기본값은 실제 GET /home 호출이다. 테스트에서는 고정 응답으로 교체한다.
  final Future<HomeDashboardData> Function()? loadHome;
  final Future<HomeDashboardData> Function(String? plantId)? loadHomeForPlant;
  final PlantManagementRepository? plantRepository;
  final WidgetBuilder? notificationBuilder;
  final Widget Function(
    BuildContext context,
    PlantManagementRepository repository,
    ValueChanged<String?> onSelectedPlantChanged,
    VoidCallback onAddPlant,
  )?
  plantManagementBuilder;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeScene _scene;
  late bool _gaugesExpanded;
  HomePlant? _serverPlant;
  String? _serverDialogue;
  bool _loadingHome = false;
  String? _homeError;
  int _unreadNotificationCount = 0;
  List<ManagedPlant> _plants = const [];
  bool _switchingPlant = false;

  late final PlantManagementRepository _plantRepository =
      widget.plantRepository ?? PlantManagementApi();

  @override
  void initState() {
    super.initState();
    _scene = widget.initialScene;
    _gaugesExpanded = widget.initialGaugesExpanded;
    if (widget.plant == null) {
      _loadingHome = true;
      _loadHome();
    }
    _loadPlants();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialScene != widget.initialScene) {
      _scene = widget.initialScene;
    }
    if (oldWidget.initialGaugesExpanded != widget.initialGaugesExpanded) {
      _gaugesExpanded = widget.initialGaugesExpanded;
    }
  }

  void _startPlantRegistration(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlantRegisterNameScreen()));
  }

  void _handlePeriodIconTap() {
    if (_scene == HomeScene.needsLight) {
      setState(() => _scene = HomeScene.cared);
    }
  }

  Future<void> _loadHome([String? plantId]) async {
    try {
      final data = widget.loadHomeForPlant != null
          ? await widget.loadHomeForPlant!(plantId)
          : plantId == null && widget.loadHome != null
          ? await widget.loadHome!()
          : await HomeApi().fetchHome(plantId: plantId);
      if (!mounted) return;
      final character = data.character;
      final hasWateringRequest = data.todayEvents.any(
        (event) => event.type == 'WATERING' && event.completable,
      );
      setState(() {
        final plant = data.plant;
        _serverPlant = plant == null
            ? null
            : HomePlant(
                id: plant.id,
                name: plant.nickname,
                startedOn: null,
                personalityType: character?.personalityType,
                daysTogether: plant.daysTogether,
              );
        _serverDialogue = character?.dialogue?.trim();
        _unreadNotificationCount = data.unreadNotificationCount;
        _loadingHome = false;
        _homeError = null;
        if (_serverDialogue?.isNotEmpty == true || hasWateringRequest) {
          _scene = HomeScene.needsWater;
        }
      });
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingHome = false;
        _homeError = error.message;
      });
    }
  }

  Future<void> _loadPlants() async {
    try {
      final plants = await _plantRepository.listPlants();
      if (mounted) setState(() => _plants = plants);
    } on LeafieApiException {
      // 홈 본문은 /home 응답으로 표시할 수 있으므로 목록 실패만으로 막지 않는다.
    }
  }

  Future<void> _switchPlant(int delta) async {
    if (_switchingPlant || _plants.length < 2) return;
    final currentId = (_serverPlant ?? widget.plant)?.id;
    var currentIndex = _plants.indexWhere((plant) => plant.id == currentId);
    if (currentIndex < 0) {
      currentIndex = _plants.indexWhere((plant) => plant.isSelected);
    }
    if (currentIndex < 0) currentIndex = 0;
    final nextIndex = (currentIndex + delta) % _plants.length;
    final next = _plants[nextIndex];
    setState(() => _switchingPlant = true);
    try {
      await _plantRepository.selectPlant(next.id);
      await _loadHome(next.id);
      await _loadPlants();
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _switchingPlant = false);
    }
  }

  Future<void> _openPlantManagement() async {
    String? selectedPlantId;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) =>
            widget.plantManagementBuilder?.call(
              routeContext,
              _plantRepository,
              (value) => selectedPlantId = value,
              () => Navigator.of(routeContext).push(
                MaterialPageRoute(
                  builder: (_) => const PlantRegisterNameScreen(),
                ),
              ),
            ) ??
            PlantManagementScreen(
              repository: _plantRepository,
              onSelectedPlantChanged: (value) => selectedPlantId = value,
              onAddPlant: () => Navigator.of(routeContext).push(
                MaterialPageRoute(
                  builder: (_) => const PlantRegisterNameScreen(),
                ),
              ),
            ),
      ),
    );
    if (!mounted) return;
    await _loadHome(selectedPlantId);
    await _loadPlants();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            widget.notificationBuilder ?? (_) => const NotificationScreen(),
      ),
    );
    if (!mounted) return;
    await _loadHome((_serverPlant ?? widget.plant)?.id);
  }

  @override
  Widget build(BuildContext context) {
    final plant = _serverPlant ?? widget.plant;
    return MainTabShell(
      home: _buildHome(context),
      diaryBuilder: (_) => DiaryScreen(
        key: ValueKey(plant?.id),
        plantId: plant?.id,
        resolvePlantIdIfMissing: false,
        showBottomNav: false,
      ),
      calendarBuilder: (_) => CalendarScreen(
        key: ValueKey(plant?.id),
        plantId: plant?.id,
        plantName: plant?.name,
        showBottomNav: false,
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final plant = _serverPlant ?? widget.plant;
    final period = widget.period ?? HomeTimePeriod.fromDateTime(DateTime.now());

    return Scaffold(
      backgroundColor: kHomeGreen,
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: AppLayout.referenceViewport.width,
            height: AppLayout.referenceViewport.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  period.asset,
                  key: ValueKey(period.asset),
                  fit: BoxFit.fill,
                ),
                _HomeHeader(
                  roomName: plant?.name,
                  dayCount: plant?.dayCount,
                  period: period,
                  unreadNotificationCount: _unreadNotificationCount,
                  canSwitchPlant: _plants.length > 1 && !_switchingPlant,
                  onPreviousPlant: () => _switchPlant(-1),
                  onNextPlant: () => _switchPlant(1),
                  onManagePlants: _openPlantManagement,
                  onNotifications: _openNotifications,
                ),
                if (_scene == HomeScene.cared)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _CareRaysPainter()),
                    ),
                  ),
                Positioned(
                  left: 29,
                  top: 111,
                  child: GestureDetector(
                    key: const ValueKey('home-period-control'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _handlePeriodIconTap,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: FigmaHomeAssetIcon(period.phaseIcon),
                    ),
                  ),
                ),
                Positioned(
                  left: 333,
                  top: 113,
                  child: FigmaHomeViewSwitch(
                    onOverviewTap: () {},
                    onDiagnosisTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DiagnosisScreen(
                          plantId: plant?.id,
                          plantName: plant?.name,
                        ),
                      ),
                    ),
                  ),
                ),
                if (plant != null && !_gaugesExpanded)
                  _HomeConversation(
                    scene: _scene,
                    serverDialogue: _serverDialogue,
                  ),
                if (plant != null)
                  const Positioned(
                    left: 78,
                    top: 282,
                    width: 248,
                    height: 248,
                    child: PlantCharacterArt(width: 248, sprouted: true),
                  ),
                if (plant != null)
                  Positioned(
                    left: 304,
                    top: 453,
                    child: Semantics(
                      button: true,
                      label: '우편함 열기',
                      child: GestureDetector(
                        key: const ValueKey('home-mailbox'),
                        onTap: () => showPlantMailbox(
                          context,
                          plantId: plant.id,
                          repository: widget.letterRepository,
                        ),
                        child: const FigmaHomeAssetIcon(FigmaHomeIcon.mailbox),
                      ),
                    ),
                  ),
                if (_loadingHome)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 350,
                    child: Center(
                      child: CircularProgressIndicator(color: kOrangeMain),
                    ),
                  )
                else if (_homeError != null)
                  Positioned(
                    left: 42,
                    right: 42,
                    top: 340,
                    child: _HomeMessageCard(
                      message: '$_homeError\n다시 불러오기',
                      onTap: () {
                        setState(() => _loadingHome = true);
                        _loadHome();
                      },
                    ),
                  )
                else if (plant == null)
                  Positioned(
                    left: 42,
                    right: 42,
                    top: 340,
                    child: _HomeMessageCard(
                      message: '등록된 식물이 없어요.\n식물을 등록해주세요.',
                      onTap: () => _startPlantRegistration(context),
                    ),
                  )
                else if (_gaugesExpanded)
                  _HomeEnvironmentPanel(
                    onCollapse: () => setState(() => _gaugesExpanded = false),
                  )
                else
                  _HomeStatusCard(
                    onTap: () => setState(() => _gaugesExpanded = true),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.roomName,
    required this.dayCount,
    required this.period,
    required this.unreadNotificationCount,
    required this.canSwitchPlant,
    required this.onPreviousPlant,
    required this.onNextPlant,
    required this.onManagePlants,
    required this.onNotifications,
  });

  final String? roomName;
  final int? dayCount;
  final HomeTimePeriod period;
  final int unreadNotificationCount;
  final bool canSwitchPlant;
  final VoidCallback onPreviousPlant;
  final VoidCallback onNextPlant;
  final VoidCallback onManagePlants;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final titleColor = period.titleColor;
    final counterColor = period.counterColor;
    final notificationColor = period.notificationColor;

    return Stack(
      children: [
        if (dayCount != null)
          Positioned(
            left: 43,
            top: 63,
            child: Text(
              'D+ $dayCount',
              style: kCaptionStyle.copyWith(color: counterColor, height: 1),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: 55,
          height: 31,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  key: const ValueKey('home-previous-plant'),
                  onTap: canSwitchPlant ? onPreviousPlant : null,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: titleColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 3),
                GestureDetector(
                  key: const ValueKey('home-manage-plants'),
                  onTap: onManagePlants,
                  child: Text(
                    roomName == null ? '내 식물' : '$roomName 방',
                    style: kItemStyle.copyWith(color: titleColor),
                  ),
                ),
                const SizedBox(width: 3),
                GestureDetector(
                  key: const ValueKey('home-next-plant'),
                  onTap: canSwitchPlant ? onNextPlant : null,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: titleColor,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 22,
          top: 47,
          width: 56,
          height: 48,
          child: Semantics(
            button: true,
            label: '알림',
            child: GestureDetector(
              key: const ValueKey('home-notifications'),
              behavior: HitTestBehavior.opaque,
              onTap: onNotifications,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FigmaHomeAssetIcon(
                    FigmaHomeIcon.notification,
                    color: notificationColor,
                  ),
                  if (unreadNotificationCount > 0)
                    Positioned(
                      right: 3,
                      top: 1,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5A52),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadNotificationCount > 99
                              ? '99+'
                              : '$unreadNotificationCount',
                          style: kSmallStyle.copyWith(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeConversation extends StatelessWidget {
  const _HomeConversation({required this.scene, required this.serverDialogue});

  final HomeScene scene;
  final String? serverDialogue;

  @override
  Widget build(BuildContext context) {
    return switch (scene) {
      HomeScene.needsWater => Positioned(
        left: 0,
        right: 0,
        top: 209,
        child: Center(
          child: PlantRequestBubble(
            message: serverDialogue?.isNotEmpty == true
                ? serverDialogue!
                : '나 지금 목말라.. 물이 필요해',
          ),
        ),
      ),
      HomeScene.needsLight => const Positioned(
        left: 0,
        right: 0,
        top: 209,
        child: Center(child: PlantRequestBubble(message: '나 햇빛이 부족해..')),
      ),
      HomeScene.cared => const Positioned(
        left: 0,
        right: 0,
        top: 209,
        child: Center(
          child: _RoomBubble(
            label: '아 따뜻해~고마워!',
            width: 132,
            height: 41,
            color: kBubbleGreenLight,
          ),
        ),
      ),
      // 2346:594 / 592 / 590 — 102×38, 흰 60%.
      HomeScene.happy => const Positioned.fill(
        child: Stack(
          children: [
            Positioned(
              left: 130,
              top: 156,
              child: _RoomBubble(
                label: '히히',
                width: 102,
                height: 38,
                opacity: 0.6,
              ),
            ),
            Positioned(
              left: 169,
              top: 184,
              child: _RoomBubble(
                label: '신난다',
                width: 102,
                height: 38,
                opacity: 0.6,
              ),
            ),
            Positioned(
              left: 145,
              top: 251,
              child: _RoomBubble(
                label: '좋은 하루야!',
                width: 102,
                height: 38,
                opacity: 0.6,
              ),
            ),
          ],
        ),
      ),
      HomeScene.idle => const SizedBox.shrink(),
    };
  }
}

class _HomeStatusCard extends StatelessWidget {
  const _HomeStatusCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 21,
      right: 21,
      top: 727,
      height: 49,
      child: Semantics(
        button: true,
        label: '조도 습도 체크하기',
        child: GestureDetector(
          key: const ValueKey('home-environment-card'),
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Color(0x26000000), blurRadius: 4),
                  ],
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 8),
                    FigmaHomeAssetIcon(FigmaHomeIcon.environmentCheck),
                    SizedBox(width: 14),
                    Text('조도 습도 체크하기', style: kItemStyle),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeEnvironmentPanel extends StatelessWidget {
  const _HomeEnvironmentPanel({required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 575,
      height: 220,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(35),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 1,
                  height: 18,
                  child: GestureDetector(
                    key: const ValueKey('home-environment-collapse'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onCollapse,
                    child: const Center(
                      child: SizedBox(
                        width: 71.6,
                        height: 2,
                        child: ColoredBox(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 34,
                  right: 34,
                  // Figma 3822:601: y=683, relative to the panel at y=575.
                  top: 108,
                  child: Text(
                    '기기연결이 필요합니다',
                    textAlign: TextAlign.center,
                    style: kTitleStyle.copyWith(color: const Color(0xFF434343)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeMessageCard extends StatelessWidget {
  const _HomeMessageCard({required this.message, required this.onTap});

  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: kBodyStyle.copyWith(color: kTextDark),
        ),
      ),
    ),
  );
}

class _RoomBubble extends StatelessWidget {
  const _RoomBubble({
    required this.label,
    required this.width,
    this.height = 40,
    this.color = kTextDark,
    this.opacity = 1,
  });

  final String label;
  final double width;
  final double height;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kBackgroundWhite.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(AppLayout.controlRadius),
        boxShadow: const [
          BoxShadow(color: Color(0x2E000000), blurRadius: 3.338),
        ],
      ),
      child: Text(
        label,
        style: kSmallStyle.copyWith(fontSize: 13.353, color: color),
      ),
    );
  }
}

class _CareRaysPainter extends CustomPainter {
  const _CareRaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.27);
    canvas.drawPath(
      Path()
        ..moveTo(75, 178)
        ..lineTo(103, 456)
        ..lineTo(164, 456)
        ..lineTo(91, 174)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(103, 180)
        ..lineTo(188, 429)
        ..lineTo(248, 429)
        ..lineTo(121, 172)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
