import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'package:yeso_plant/services/letter_api.dart';
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
    this.bodyId,
    this.hairId,
    this.expressionId,
    this.colorId,
  });

  final String name;
  final String? id;
  final DateTime? startedOn;
  final String? personalityType;
  final int? daysTogether;

  /// 종으로 자동 매핑된 헤어. 서버가 준 값이 없으면(예: 위젯 생성자로 직접
  /// 넘긴 경우) null이고, 이때 캐릭터는 민머리로 그려진다.
  final String? hairId;

  /// 서버가 내려준 바디·표정(BodyType/ExpressionType enum). 선택 UI는
  /// #84·#85에서 붙는다. 위젯 생성자로 직접 만든 경우 null이다.
  final String? bodyId;
  final String? expressionId;

  /// 사용자가 고른 바디 색(ColorType enum). 위젯 생성자로 직접 만든
  /// 경우 null이고, 이때 캐릭터는 원본 노란색으로 그려진다.
  final String? colorId;

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

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late HomeScene _scene;
  late bool _gaugesExpanded;
  HomePlant? _serverPlant;
  String? _serverDialogue;
  bool _loadingHome = false;
  String? _homeError;
  int _unreadNotificationCount = 0;
  int _unreadLetterCount = 0;
  List<ManagedPlant> _plants = const [];
  bool _switchingPlant = false;

  // 씬과 독립된 로컬 돌보기 모션 컨트롤러들(백엔드/씬 전환에 영향 없음).
  // late final 지연 초기화를 쓰면 build에서 한 번도 접근되지 않은 채 dispose가
  // 이들을 처음 만들며 vsync(=this)가 비활성 트리에서 MediaQuery를 조회해 터진다.
  // 그래서 initState에서 명시적으로 생성한다.
  // 햇빛: 해 아이콘 탭 시 광선 페이드 인 + scale(씬 상태와 무관하게 발동).
  late final AnimationController _raysController;
  // 물주기: 물뿌리개 탭 시 물줄기/물방울 낙하 + 캐릭터 bounce.
  late final AnimationController _wateringController;
  // 쓰담쓰담: 캐릭터 탭 시 좌우 wiggle.
  late final AnimationController _petController;

  // 광선/토스트는 씬(_scene)이 아닌 로컬 상태로 제어한다. 해를 언제 눌러도
  // 광선이 뜨고, needsLight일 때만 씬을 cared로 넘긴다.
  bool _sunActive = false;
  // 돌봄 토스트("햇빛을 줬어요!" / "물을 줬어요!")를 2초간 띄운다.
  String? _careToastLabel;
  double _careToastOpacity = 0;
  Timer? _careToastTimer;
  // 햇빛 광선도 토스트처럼 잠깐 떴다가 사라진다(탭 후 3초 유지 뒤 페이드아웃).
  Timer? _sunHideTimer;
  // 물주기가 끝난 직후에도 기쁜 표정을 잠깐(500ms) 더 유지해 뚝 끊기지 않게 한다.
  bool _wateringAfterglow = false;
  Timer? _wateringAfterglowTimer;

  late final PlantManagementRepository _plantRepository =
      widget.plantRepository ?? PlantManagementApi();
  late final PlantLetterRepository _letterRepository =
      widget.letterRepository ?? LetterApi();

  @override
  void initState() {
    super.initState();
    _raysController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _wateringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _petController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _scene = widget.initialScene;
    _gaugesExpanded = widget.initialGaugesExpanded;
    if (_scene == HomeScene.cared) {
      _sunActive = true;
      _raysController.value = 1;
    }
    if (widget.plant == null) {
      _loadingHome = true;
      _loadHome();
    }
    _loadPlants();
  }

  @override
  void dispose() {
    _careToastTimer?.cancel();
    _sunHideTimer?.cancel();
    _wateringAfterglowTimer?.cancel();
    _raysController.dispose();
    _wateringController.dispose();
    _petController.dispose();
    super.dispose();
  }

  void _petCharacter() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _petController.forward(from: 0);
  }

  void _waterPlant() {
    _showCareToast('물을 줬어요!');
    if (MediaQuery.disableAnimationsOf(context)) return;
    _wateringController.forward(from: 0);
    // 물줄기가 끝나도 기쁜 표정을 0.5초 더 유지한다.
    _wateringAfterglowTimer?.cancel();
    setState(() => _wateringAfterglow = true);
    _wateringAfterglowTimer = Timer(
      _wateringController.duration! + const Duration(milliseconds: 500),
      () {
        if (!mounted) return;
        setState(() => _wateringAfterglow = false);
      },
    );
  }

  /// 돌보기(물주기·햇빛·쓰담쓰담) 중이면 캐릭터가 기쁜 표정을 짓는다.
  bool get _isBeingCaredFor =>
      _wateringController.isAnimating ||
      _wateringAfterglow ||
      _sunActive ||
      _petController.isAnimating;

  /// 물이 주둥이에서 떨어지는 구간(0.2~0.85)의 표시 세기(0~1).
  /// 0.2~0.28 페이드인, 0.78~0.85 페이드아웃, 그 사이는 완전 표시.
  /// 물뿌리개가 붓는 자세를 유지하는 구간(0.25~0.75)보다 살짝 넓게 잡아
  /// 물이 나오는 시간을 눈에 띄게 확보한다.
  static double _wateringPourPhase(double t) {
    if (t <= 0.2 || t >= 0.85) return 0;
    if (t < 0.28) return (t - 0.2) / 0.08;
    if (t > 0.78) return (0.85 - t) / 0.07;
    return 1;
  }

  /// 돌봄 토스트를 띄우고 2초 뒤 페이드아웃한다. 접근성상 애니메이션이 꺼져
  /// 있으면 정보 전달을 위해 토스트는 그대로 띄우되 페이드 없이 즉시 사라진다.
  void _showCareToast(String label) {
    _careToastTimer?.cancel();
    setState(() {
      _careToastLabel = label;
      _careToastOpacity = 1;
    });
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _careToastTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _careToastOpacity = 0);
      if (reduceMotion) {
        setState(() => _careToastLabel = null);
        return;
      }
      // 페이드 시간(250ms) 뒤 위젯을 트리에서 제거한다.
      _careToastTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() => _careToastLabel = null);
      });
    });
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
    // 달이 뜬 시간대(evening/lateEvening)엔 해 자리에 달 아이콘이 뜬다.
    // 달을 눌러도 햇빛(광선/토스트)이 나오면 안 되므로 아무것도 하지 않는다.
    // 낮(day)·오후해(afternoon)일 때만 발동한다.
    final period = widget.period ?? HomeTimePeriod.fromDateTime(DateTime.now());
    if (period.phaseIcon == FigmaHomeIcon.moon) return;
    // 해를 언제 눌러도 광선과 토스트가 뜬다(씬 상태와 무관한 로컬 모션).
    // needsLight일 때만 씬을 감사 상태(cared)로 넘긴다.
    _showCareToast('햇빛을 줬어요!');
    _sunHideTimer?.cancel();
    setState(() {
      _sunActive = true;
      if (_scene == HomeScene.needsLight) _scene = HomeScene.cared;
    });
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _raysController.value = 1;
    } else {
      _raysController.forward(from: 0);
    }
    // 광선도 토스트처럼 잠깐 보였다가 사라진다. 3초 유지 후 페이드아웃하고
    // (접근성상 애니메이션이 꺼져 있으면 페이드 없이) 트리에서 제거한다.
    _sunHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (reduceMotion) {
        setState(() => _sunActive = false);
        return;
      }
      _raysController.reverse().whenComplete(() {
        if (mounted) setState(() => _sunActive = false);
      });
    });
  }

  Future<void> _loadHome([String? plantId]) async {
    try {
      final data = widget.loadHomeForPlant != null
          ? await widget.loadHomeForPlant!(plantId)
          : plantId == null && widget.loadHome != null
          ? await widget.loadHome!()
          : await HomeApi().fetchHome(plantId: plantId);
      if (!mounted) return;
      final room = data.room;
      final hasWateringRequest = data.todayEvents.any(
        (event) => event.careType == 'WATERING' && event.completable,
      );
      setState(() {
        final plant = data.plant;
        _serverPlant = plant == null
            ? null
            : HomePlant(
                id: plant.id,
                name: plant.nickname,
                startedOn: DateTime.tryParse(plant.startedOn),
                personalityType: plant.personalityType,
                daysTogether: plant.daysTogether,
                bodyId: plant.bodyId,
                hairId: plant.hairId,
                expressionId: plant.expressionId,
                colorId: plant.colorId,
              );
        _serverDialogue = room?.dialogue?.trim();
        _unreadNotificationCount = data.unreadNotificationCount;
        _unreadLetterCount = data.unreadLetterCount;
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
                if (_sunActive)
                  // 시안(4534:9042) 햇빛 광선. 해 아이콘에서 화면 중앙 하단으로
                  // 뻗는 대각선 vector. 시안은 흰색 중심(mix-blend overlay).
                  // SVG 자체는 연노랑(#FEFFB7)이라 노란 배경 위에서 너무
                  // 쨍하므로, ColorFilter(srcATop, 흰색)로 알파를 유지한 채 색만
                  // 흰색으로 덮고 opacity도 0.45로 낮춰 은은하게 만든다.
                  //
                  // 광선 시작점(꼭짓점)이 해 아이콘 중심에서 뻗어나오도록 맞춘다.
                  // SVG path 정점은 로컬 좌표 (≈32,15)에서 아래로 부채꼴로 퍼진다.
                  // 해 아이콘은 Positioned(29,111)+Padding(4)라 그림 좌상단이
                  // (33,115), sun 83.13×82.35라 중심이 (≈74.6,156.2). 정점을
                  // 해 중심에 맞추려면 left=74.6-32≈43, top=156.2-15≈141.
                  Positioned(
                    left: 43,
                    top: 141,
                    width: 277.172,
                    height: 421.502,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _raysController,
                        builder: (context, child) {
                          final t = Curves.easeOut.transform(
                            _raysController.value,
                          );
                          return Opacity(
                            opacity: 0.45 * t,
                            child: Transform.rotate(
                              angle: -1.84 * math.pi / 180,
                              child: Transform.scale(
                                alignment: Alignment.topLeft,
                                scale: 0.9 + 0.1 * t,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: SvgPicture.asset(
                          'assets/images/home_sun_rays.svg',
                          width: 277.172,
                          height: 421.502,
                          fit: BoxFit.fill,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcATop,
                          ),
                        ),
                      ),
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
                  // 물줄기(시안 4534:11340 "Group 1597881924").
                  //
                  // 본체는 시안 vector를 그대로 쓴다(home_water_stream_vec.svg,
                  // viewBox 122.778×241.418). 주둥이(로컬 x≈83.5 y≈4)에서 좁게
                  // 시작해 아래로 넓어지는 부채꼴이고, 색은 시안 linear
                  // 그라디언트(위 #AAE7F1 → 아래 투명)라 직접 그리지 않는다.
                  // (시안의 feTurbulence 물결 텍스처는 flutter_svg가 렌더하지
                  // 못해 생략한다.)
                  //
                  // 그 위에 _WaterFlowPainter를 얹어 시안의 작은 물방울과 흰
                  // 하이라이트가 부채꼴 안을 계속 흘러내리게 한다(콸콸 느낌).
                  // 본체 자체는 형태 고정이라 Transform으로 좌우 흔들림 +
                  // 미세 scaleX 맥동을 줘 물이 출렁이게 한다.
                  //
                  // 맨 위에는 시안 5055:181의 흩날림 레이어
                  // (home_water_splash.svg)를 얹는다. 물줄기 주변으로 튀어
                  // 흩어지며 떨어지는 눈물방울들이며, 정적 프레임이라
                  // _WaterSplashLayer가 세로로 이어붙여 아래로 흘려보낸다.
                  //
                  // 물뿌리개 앞이 아니라 뒤에 둬 주둥이가 물줄기 위를 덮는다.
                  AnimatedBuilder(
                    animation: _wateringController,
                    builder: (context, child) {
                      final t = _wateringController.value;
                      final phase = _wateringPourPhase(t);
                      if (phase <= 0) return const SizedBox.shrink();
                      final reduceMotion = MediaQuery.disableAnimationsOf(
                        context,
                      );
                      // 붓는 구간(0.2~0.85) 진행도. 흐름·출렁임의 시간축.
                      final pour = ((t - 0.2) / 0.65).clamp(0.0, 1.0);
                      // 출렁임: 붓는 동안 2.5주기 왕복. 좌우 ±2.5px + scaleX 맥동.
                      final wobblePhase = pour * 2 * math.pi * 2.5;
                      final sway = reduceMotion
                          ? 0.0
                          : math.sin(wobblePhase) * 2.5;
                      final scaleX = reduceMotion
                          ? 1.0
                          : 1 + math.sin(wobblePhase + math.pi / 3) * 0.02;
                      return Positioned(
                        // 기운 주둥이 아래(화면 ≈x240 y200)에 시안 부채꼴의 시작
                        // 점(로컬 x83.5 y4)이 오도록 맞춘다. 하단 부채꼴은
                        // 화면 y≈433, x≈169~275로 퍼져 캐릭터 정수리(y≈400)를
                        // 덮는다. 붓는 동안 물이 주둥이에서 살짝 흘러내린다.
                        left: 156,
                        top: 196 + 8 * (1 - phase),
                        width: _kWaterStreamWidth,
                        height: _kWaterStreamHeight,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: phase,
                            child: Transform(
                              alignment: Alignment.topCenter,
                              transform: Matrix4.identity()
                                ..translateByDouble(sway, 0, 0, 1)
                                ..scaleByDouble(scaleX, 1, 1, 1),
                              child: Stack(
                                children: [
                                  SvgPicture.asset(
                                    'assets/images/home_water_stream_vec.svg',
                                    width: _kWaterStreamWidth,
                                    height: _kWaterStreamHeight,
                                    fit: BoxFit.fill,
                                  ),
                                  if (!reduceMotion)
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _WaterFlowPainter(pour: pour),
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: _WaterSplashLayer(
                                      pour: pour,
                                      reduceMotion: reduceMotion,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (plant != null)
                  // 물뿌리개(시안 4534:9138)는 평소 좌하단(x≈13 y≈496)에
                  // 얌전히 있다가, 탭하면 캐릭터 위 오른쪽(시안 위치)으로 대각선
                  // 이동하며 주둥이가 캐릭터를 향하도록 반시계로 기울여 붓고,
                  // 끝나면 다시 좌하단 제자리로 내려온다. TweenSequence 대신
                  // raise(0~1)를 dx/dy·각도에 곱하는 구간별 보간을 쓴다.
                  Positioned(
                    left: 13.479,
                    top: 496,
                    width: 83.98,
                    height: 67.751,
                    child: Semantics(
                      button: true,
                      label: '물주기',
                      child: GestureDetector(
                        key: const ValueKey('home-watering-can'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _waterPlant,
                        child: AnimatedBuilder(
                          animation: _wateringController,
                          builder: (context, child) {
                            final t = _wateringController.value;
                            // 0~0.25 떠올라 이동+회전(easeOut), 0.25~0.75 붓는
                            // 자세 유지, 0.75~1.0 원위치 복귀(easeIn). raise는
                            // 목표 상태로의 진행도(0=원위치, 1=시안 붓는 위치).
                            final double raise;
                            if (t <= 0) {
                              raise = 0;
                            } else if (t < 0.25) {
                              raise = Curves.easeOut.transform(t / 0.25);
                            } else if (t < 0.75) {
                              raise = 1;
                            } else {
                              raise = 1 -
                                  Curves.easeIn.transform((t - 0.75) / 0.25);
                            }
                            // 좌하단 원위치(위젯중심 x≈55.5 y≈529.9)에서 시안
                            // 몸통 중심(x≈262 y≈180=캐릭터 위 오른쪽)까지 대각선
                            // 이동. dx/dy는 위젯 중심 기준 이동량이라 center 회전과
                            // 결합해도 몸통 중심이 목표에 머문다.
                            const dx = 206.5;
                            const dy = -349.9;
                            // 붓는 자세 유지 구간(t 0.25~0.75)에 손목으로 물을
                            // 따르듯 주둥이를 위아래로 "까딱"거린다. 붓는 구간
                            // 진행도(0~1)에 2.5주기 sin을 곱해 2~3회 왕복시키고,
                            // 아래로 까딱할 때 더 숙이도록 회전을 더 음수로 민다
                            // (진폭 ±0.08rad≈±4.6도). 올라가는·내려오는 구간엔
                            // 까딱 없이 이동만 한다.
                            double nod = 0;
                            if (t >= 0.25 && t < 0.75) {
                              final pourT = (t - 0.25) / 0.5;
                              nod = -math.sin(pourT * 2 * math.pi * 2.5) * 0.08;
                            }
                            return Transform.translate(
                              offset: Offset(dx * raise, dy * raise),
                              child: Transform.rotate(
                                // 손잡이 위·주둥이(왼쪽)가 캐릭터 정수리를
                                // 향하도록 반시계로 최대 -0.5rad(≈-30deg) 기운다.
                                alignment: Alignment.center,
                                angle: -0.5 * raise + nod,
                                child: child,
                              ),
                            );
                          },
                          child: Image.asset(
                            'assets/images/home_watering_can.png',
                            fit: BoxFit.contain,
                            semanticLabel: '물뿌리개',
                          ),
                        ),
                      ),
                    ),
                  ),
                if (plant != null && _unreadLetterCount > 0)
                  // 시안(4534:9698) 편지 배지: 우편함 위에 뜬다. x=319 y=390 55x62.
                  Positioned(
                    left: 319,
                    top: 390,
                    width: 55,
                    height: 62.188,
                    child: Image.asset(
                      'assets/images/home_letter_badge.png',
                      fit: BoxFit.contain,
                      semanticLabel: '새 편지가 도착했어요',
                    ),
                  ),
                if (plant != null)
                  // 시안(4534:8101) 캐릭터 몸통: x=123 y=396 155.2x143.
                  // PlantCharacterArt는 circle 몸통을 `width × 0.897` 폭으로
                  // 박스 가로 가운데에 그리므로 폭은 155.2/0.897≈173.02다.
                  // 몸통 위쪽은 박스 위에서 8.74 아래(박스 높이 160.87 − 바닥
                  // 여백 9.17 − 몸통 높이 142.96)라 그만큼 위로 당긴다.
                  Positioned(
                    left: 123 - (173.02 - 155.2) / 2,
                    top: 396 - 8.74,
                    width: 173.02,
                    child: Semantics(
                      button: true,
                      label: '쓰담쓰담',
                      child: GestureDetector(
                        key: const ValueKey('home-character-pet'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _petCharacter,
                        child: AnimatedBuilder(
                          // 쓰담 wiggle과 물주기 bounce를 함께 반영한다.
                          // 표정 전환도 여기서 함께 재평가된다.
                          animation: Listenable.merge([
                            _petController,
                            _wateringController,
                          ]),
                          builder: (context, _) {
                            // 쓰담: ±0.03rad를 몇 번 왕복하며 감쇠.
                            final wiggle = _petController.isAnimating
                                ? math.sin(
                                        _petController.value * math.pi * 6,
                                      ) *
                                      0.03 *
                                      (1 - _petController.value)
                                : 0.0;
                            // 물이 캐릭터에 닿는 붓는 구간(0.35~0.75)에 통통 튄다.
                            final bouncePhase =
                                ((_wateringController.value - 0.35) / 0.4)
                                    .clamp(0.0, 1.0);
                            final bounce =
                                math.sin(bouncePhase * math.pi) * 6;
                            // 돌보기 중엔 기쁜 표정, 평소엔 기본 표정.
                            // 얼굴 PNG는 캔버스가 같아 크로스페이드해도 위치가
                            // 안 튄다.
                            final expression = _isBeingCaredFor
                                ? PlantExpression.happy
                                : PlantExpression.defaultFace;
                            return Transform.translate(
                              offset: Offset(0, -bounce),
                              child: Transform.rotate(
                                angle: wiggle,
                                child: AnimatedSwitcher(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 200),
                                  child: PlantCharacterArt(
                                    key: ValueKey(expression),
                                    width: 173.02,
                                    body: plantBodyFromId(plant.bodyId),
                                    expression: expression,
                                    colorId: plant.colorId,
                                    hairId: plant.hairId,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
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
                          repository: _letterRepository,
                        ),
                        child: const FigmaHomeAssetIcon(FigmaHomeIcon.mailbox),
                      ),
                    ),
                  ),
                if (_careToastLabel != null)
                  // 돌봄 토스트(시안 4534:9220 / 11479). 상단 중앙에 뜬다.
                  // 물뿌리개가 붓는 위치(중심 ≈x262 y180, 회전 포함 대략
                  // y126~234)와 겹치지 않도록 시안처럼 위(top 113)로 올린다.
                  // top 168이던 이전 위치는 토스트 box(y168~195)가 물뿌리개
                  // 붓는 box에 완전히 들어가 겹쳤다. top 113이면 토스트 box는
                  // y113~140으로, 물뿌리개보다 위(해 아이콘 옆)에 놓여 안 겹친다.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 113,
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _careToastOpacity,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          child: _CareToast(label: _careToastLabel!),
                        ),
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

/// 돌봄 토스트(시안 4534:9220 "햇빛을 줬어요!" / 4534:11479 "물을 줬어요!").
/// 흰 pill(높이 27, radius 26, 그림자) + 왼쪽 오렌지 원·흰 체크 + 라벨.
class _CareToast extends StatelessWidget {
  const _CareToast({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 27,
      padding: const EdgeInsets.only(left: 6, right: 14),
      decoration: BoxDecoration(
        color: kBackgroundWhite,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // toast_check.svg는 오렌지 원만 있어 흰 체크를 그 위에 얹는다.
          SizedBox(
            width: 16,
            height: 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/toast_check.svg',
                  width: 16,
                  height: 16,
                  fit: BoxFit.fill,
                ),
                const Icon(Icons.check_rounded, size: 11, color: kBackgroundWhite),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF444444),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 시안 물줄기 본체 SVG(home_water_stream_vec.svg)의 viewBox 크기.
/// 오버레이 페인터가 같은 좌표계를 쓰도록 위젯 박스도 이 값으로 맞춘다.
const double _kWaterStreamWidth = 122.778;
const double _kWaterStreamHeight = 241.418;

/// 시안 흩날림 SVG(home_water_splash.svg, 5055:181)의 viewBox 크기.
const double _kWaterSplashWidth = 93.0651;
const double _kWaterSplashHeight = 164.783;

/// 물줄기 본체 박스 기준 흩날림 레이어의 좌상단 오프셋.
/// 시안 절대좌표(x 151.9, y 205.8) - 본체 Positioned(left 156, top 196).
const double _kWaterSplashLeft = -4.1;
const double _kWaterSplashTop = 9.8;

/// 물줄기 본체 SVG 위에 얹는 흩날림 레이어(시안 5055:181 = 물줄기 주변으로
/// 튀어 흩어지며 떨어지는 눈물방울들).
///
/// SVG 자체는 한 프레임의 정적 배치라 그대로 두면 물방울이 공중에 멈춰 있다.
/// 그래서 같은 SVG를 세로로 2장 이어붙인 뒤(위·아래) 전체를 아래로
/// `translateY = -(1 - p) * 높이` 만큼 흘려보내(p는 0→1 순환) 위 장이 내려가면
/// 아래 장이 이어지게 한다 — 끊김 없이 계속 떨어지는 것처럼 보인다.
/// 바깥은 `ClipRect`로 잘라 본체 영역 밖으로 튀어나오지 않게 한다.
///
/// 하단은 `ShaderMask`로 페이드아웃한다. 본체 그라디언트가 로컬
/// y≈164(68%)에서 투명해지므로 _WaterFlowPainter의 `_visibleEnd`(0.62)와 같은
/// 감각으로 그 언저리부터 물방울을 지워, 본체 없는 허공에 물방울만 떠 보이지
/// 않게 한다.
///
/// 접근성으로 애니메이션이 꺼져 있으면 한 장을 정적으로만 표시한다.
class _WaterSplashLayer extends StatelessWidget {
  const _WaterSplashLayer({required this.pour, required this.reduceMotion});

  /// 붓는 구간(0.2~0.85) 진행도(0~1). 흐름의 시간축.
  final double pour;

  final bool reduceMotion;

  /// 한 번 붓는 동안 도는 바퀴 수. 본체 안 물방울(speed 2.0~3.1)보다 살짝
  /// 느리게 잡아 흩날림이 따로 튀어 보이지 않게 한다.
  static const double _cycles = 2.4;

  /// 페이드아웃 시작/끝(본체 박스 높이 대비). `_WaterFlowPainter._visibleEnd`와
  /// 같은 지점에서 지워지기 시작해 0.76에서 완전히 사라진다.
  static const double _fadeStart = 0.62;
  static const double _fadeEnd = 0.76;

  @override
  Widget build(BuildContext context) {
    final splash = SvgPicture.asset(
      'assets/images/home_water_splash.svg',
      width: _kWaterSplashWidth,
      height: _kWaterSplashHeight,
      fit: BoxFit.fill,
    );

    final Widget flow;
    if (reduceMotion) {
      flow = Positioned(
        left: _kWaterSplashLeft,
        top: _kWaterSplashTop,
        width: _kWaterSplashWidth,
        height: _kWaterSplashHeight,
        child: splash,
      );
    } else {
      // 0→1 순환. 0일 때 위 장의 아래끝이 시작 위치에 오고, 1에 가까워지면
      // 아래 장이 그 자리를 이어받아 같은 배치로 돌아온다(끊김 없음).
      final p = (pour * _cycles) % 1.0;
      final dy = (p - 1) * _kWaterSplashHeight;
      flow = Positioned(
        left: _kWaterSplashLeft,
        top: _kWaterSplashTop + dy,
        width: _kWaterSplashWidth,
        height: _kWaterSplashHeight * 2,
        child: Column(children: [splash, splash]),
      );
    }

    return IgnorePointer(
      child: ClipRect(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Colors.white, Colors.white, Colors.transparent],
            stops: const [0.0, _fadeStart, _fadeEnd],
          ).createShader(bounds),
          child: Stack(clipBehavior: Clip.none, children: [flow]),
        ),
      ),
    );
  }
}

/// 물줄기 본체 SVG 위에 얹어 물이 흘러내리게 하는 오버레이(시안 4534:11340의
/// Ellipse 1021~1034 물방울 + Vector 1538~1545 흰 하이라이트를 움직이게 한 것).
///
/// 시안 본체 path의 좌우 경계를 y에 따라 선형 보간해(상단 좁고 하단 넓음)
/// 물방울·하이라이트를 부채꼴 안에만 배치하고, 각자 다른 속도·오프셋으로
/// 위→아래를 순환(`(pour*speed + offset) % 1`)시켜 콸콸 흐르는 느낌을 만든다.
/// 색은 시안 확대본처럼 본체(연하늘)보다 한 단계 진한 하늘색을 써서 물방울이
/// 또렷하게 대비되게 한다.
class _WaterFlowPainter extends CustomPainter {
  _WaterFlowPainter({required this.pour});

  /// 붓는 구간(0.2~0.85) 진행도(0~1). 흐름의 시간축.
  final double pour;

  /// 시안 확대본 물방울에서 직접 뽑은 진한 하늘색 rgb(173,224,238).
  /// 본체(rgb 217,240,239)보다 확실히 진해 또렷하게 대비된다.
  static const Color _dropDeep = Color(0xFFADE0EE);

  /// 물방울 밝은 쪽 색(시안의 흰빛 물방울). 소수만 이 색을 쓴다.
  static const Color _dropLight = Color(0xFFECF8EE);

  /// 본체 그라디언트가 투명해지기 시작하는 세로 위치(0~1). 시안 linear
  /// 그라디언트의 마지막 stop이 로컬 y≈163.8(=241.418의 약 0.68)이라,
  /// 그 아래로는 물방울·하이라이트가 본체 없이 떠 보이므로 여기서 사라진다.
  static const double _visibleEnd = 0.62;

  /// 흐르는 눈물방울 14개. x는 그 y에서의 부채꼴 폭 대비 위치(0=좌경계,
  /// 1=우경계), speed는 한 번 붓는 동안 도는 횟수, offset은 시작 위상,
  /// width는 물방울 폭(본체 좌표계 px). 분포는 시안 Ellipse 1021~1034를
  /// 따르되, 확대본처럼 보이도록 크기를 5~11px로 키웠다. light가 true면
  /// 흰빛 물방울(소수만).
  static const List<_FlowDrop> _drops = [
    _FlowDrop(x: 0.46, speed: 2.2, offset: 0.00, width: 10.0),
    _FlowDrop(x: 0.18, speed: 2.6, offset: 0.17, width: 6.5),
    _FlowDrop(x: 0.74, speed: 2.0, offset: 0.34, width: 8.5),
    _FlowDrop(x: 0.30, speed: 2.9, offset: 0.52, width: 5.2),
    _FlowDrop(x: 0.60, speed: 2.3, offset: 0.70, width: 9.0, light: true),
    _FlowDrop(x: 0.86, speed: 2.7, offset: 0.09, width: 6.0),
    _FlowDrop(x: 0.24, speed: 2.1, offset: 0.26, width: 11.0),
    _FlowDrop(x: 0.68, speed: 3.0, offset: 0.44, width: 5.0),
    _FlowDrop(x: 0.12, speed: 2.4, offset: 0.61, width: 7.5),
    _FlowDrop(x: 0.40, speed: 2.8, offset: 0.79, width: 5.8, light: true),
    _FlowDrop(x: 0.55, speed: 2.5, offset: 0.13, width: 9.5),
    _FlowDrop(x: 0.34, speed: 2.2, offset: 0.38, width: 5.5),
    _FlowDrop(x: 0.80, speed: 3.1, offset: 0.66, width: 7.0),
    _FlowDrop(x: 0.50, speed: 2.3, offset: 0.88, width: 6.8),
  ];

  /// 흐르는 흰 하이라이트 6개. 시안 확대본처럼 물줄기 길이의 30~60%짜리
  /// 긴 세로 곡선이며, length는 본체 높이 대비 길이.
  static const List<_FlowHighlight> _highlights = [
    _FlowHighlight(x: 0.20, speed: 1.5, offset: 0.05, length: 0.46),
    _FlowHighlight(x: 0.72, speed: 1.3, offset: 0.33, length: 0.55),
    _FlowHighlight(x: 0.44, speed: 1.7, offset: 0.58, length: 0.34),
    _FlowHighlight(x: 0.12, speed: 1.4, offset: 0.80, length: 0.42),
    _FlowHighlight(x: 0.58, speed: 1.2, offset: 0.20, length: 0.58),
    _FlowHighlight(x: 0.88, speed: 1.6, offset: 0.66, length: 0.31),
  ];

  /// 흩뿌려진 작은 흰 반짝점 10개. x가 0 미만/1 초과면 부채꼴 경계 바깥이다
  /// (시안처럼 물줄기 가장자리 밖에도 점이 튄다).
  static const List<_FlowSparkle> _sparkles = [
    _FlowSparkle(x: 0.34, speed: 1.1, offset: 0.04, radius: 1.3),
    _FlowSparkle(x: -0.12, speed: 0.9, offset: 0.21, radius: 1.0),
    _FlowSparkle(x: 0.70, speed: 1.3, offset: 0.37, radius: 1.5),
    _FlowSparkle(x: 1.10, speed: 1.0, offset: 0.50, radius: 1.1),
    _FlowSparkle(x: 0.48, speed: 1.2, offset: 0.63, radius: 0.9),
    _FlowSparkle(x: 0.20, speed: 0.8, offset: 0.76, radius: 1.4),
    _FlowSparkle(x: 0.88, speed: 1.1, offset: 0.12, radius: 1.2),
    _FlowSparkle(x: -0.08, speed: 1.4, offset: 0.45, radius: 0.8),
    _FlowSparkle(x: 0.60, speed: 0.9, offset: 0.88, radius: 1.3),
    _FlowSparkle(x: 1.06, speed: 1.2, offset: 0.29, radius: 1.0),
  ];

  /// 시안 본체 path의 세로 위치 v(0=상단, 1=하단)에서의 좌/우 경계 x.
  /// 상단 주둥이(로컬 x≈75~84)에서 시작해 하단(x≈12~119)으로 벌어진다.
  /// SVG 좌표(122.778 기준)를 폭 비율로 정규화해 쓴다.
  static (double, double) _bounds(double v) {
    // 상단은 주둥이 폭만큼 좁고, 아래로 갈수록 부채꼴이 벌어진다.
    final left = (75.0 + (12.0 - 75.0) * math.pow(v, 0.75)) / _kWaterStreamWidth;
    final right =
        (84.5 + (119.0 - 84.5) * math.pow(v, 1.6)) / _kWaterStreamWidth;
    return (left, right);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pour <= 0) return;
    _paintHighlights(canvas, size);
    _paintSparkles(canvas, size);
    _paintDrops(canvas, size);
  }

  /// 상단 페이드인 + `_visibleEnd`부터 페이드아웃. 본체 그라디언트가 로컬
  /// y≈164(68%)에서 투명해지므로 그 밑에서 디테일만 떠 보이지 않게 한다.
  static double _fadeAt(double v, double fadeIn) {
    if (v < fadeIn) return v / fadeIn;
    if (v > _visibleEnd) return 1 - (v - _visibleEnd) / 0.14;
    return 1.0;
  }

  /// 세로 위치 v에서 부채꼴 폭 대비 x(0=좌경계, 1=우경계)의 캔버스 좌표.
  /// x가 0~1 밖이면 경계 바깥으로 벗어난다(반짝점이 가장자리 밖에 튄다).
  Offset _pointAt(Size size, double v, double x) {
    final (left, right) = _bounds(v);
    return Offset(size.width * (left + (right - left) * x), size.height * v);
  }

  /// 위가 뾰족하고 아래가 둥근 눈물방울 path(시안 확대본 모양).
  static Path _teardrop(Offset center, double width) {
    final r = width / 2;
    // 전체 높이는 폭의 약 1.8배. 꼭짓점은 중심보다 위, 둥근 배는 아래.
    final apex = center.dy - r * 1.7;
    final belly = center.dy + r * 0.35;
    final bottom = center.dy + r * 1.1;
    return Path()
      ..moveTo(center.dx, apex)
      // 오른쪽 옆구리: 꼭짓점에서 가장 넓은 지점까지.
      ..quadraticBezierTo(center.dx + r * 0.62, center.dy - r * 0.5,
          center.dx + r, belly)
      // 오른쪽 아래 둥근 부분.
      ..quadraticBezierTo(center.dx + r, bottom, center.dx, bottom)
      // 왼쪽 아래 둥근 부분.
      ..quadraticBezierTo(center.dx - r, bottom, center.dx - r, belly)
      // 왼쪽 옆구리: 다시 꼭짓점으로.
      ..quadraticBezierTo(center.dx - r * 0.62, center.dy - r * 0.5,
          center.dx, apex)
      ..close();
  }

  void _paintDrops(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final drop in _drops) {
      final v = (pour * drop.speed + drop.offset) % 1.0;
      final fade = _fadeAt(v, 0.08);
      if (fade <= 0) continue;
      final center = _pointAt(size, v, drop.x);
      // 불투명하게 칠한다. 본체 SVG가 반투명이라 알파를 낮추면 뒤 배경색이
      // 배어들어 시안의 또렷한 하늘색 물방울이 탁해진다.
      paint.color = (drop.light ? _dropLight : _dropDeep).withValues(
        alpha: fade.clamp(0.0, 1.0),
      );
      canvas.drawPath(_teardrop(center, drop.width), paint);
    }
  }

  void _paintHighlights(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final h in _highlights) {
      final v = (pour * h.speed + h.offset) % 1.0;
      final fade = _fadeAt(v, 0.10);
      if (fade <= 0) continue;
      final vEnd = math.min(v + h.length, 1.0);
      final vMid = (v + vEnd) / 2;
      final start = _pointAt(size, v, h.x);
      final mid = _pointAt(size, vMid, h.x);
      final end = _pointAt(size, vEnd, h.x);
      // 부채꼴이 벌어지는 방향(중심선에서 멀어지는 쪽)으로 제어점을 밀어
      // 시안처럼 흐름을 따라 완만히 휘게 한다.
      final bend = (h.x - 0.5) * size.width * 0.10;
      final control = Offset(mid.dx + bend, mid.dy);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(
        path,
        paint
          ..strokeWidth = h.length > 0.45 ? 1.5 : 1.1
          ..color = Colors.white.withValues(
            alpha: 0.7 * fade.clamp(0.0, 1.0),
          ),
      );
    }
  }

  void _paintSparkles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in _sparkles) {
      final v = (pour * s.speed + s.offset) % 1.0;
      final fade = _fadeAt(v, 0.10);
      if (fade <= 0) continue;
      // 각자 다른 주기로 미세하게 깜빡인다.
      final twinkle =
          0.8 + 0.2 * math.sin((pour * 6 + s.offset * 7) * math.pi);
      // 본체가 반투명이라 흰 점도 알파를 낮추면 묻힌다. 거의 불투명하게 둔다.
      paint.color = Colors.white.withValues(
        alpha: (twinkle * fade).clamp(0.0, 1.0),
      );
      canvas.drawCircle(_pointAt(size, v, s.x), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_WaterFlowPainter oldDelegate) =>
      oldDelegate.pour != pour;
}

/// 흐르는 눈물방울 한 개의 정의.
class _FlowDrop {
  const _FlowDrop({
    required this.x,
    required this.speed,
    required this.offset,
    required this.width,
    this.light = false,
  });

  /// 그 y에서의 부채꼴 폭 대비 가로 위치(0=좌경계, 1=우경계).
  final double x;

  /// 한 번 붓는 동안 위→아래를 도는 횟수.
  final double speed;

  /// 시작 위상(0~1). 물방울마다 달라 흩어져 흐른다.
  final double offset;

  /// 눈물방울 폭(본체 좌표계 px, 5~11).
  final double width;

  /// true면 밝은 하늘색(소수), false면 진한 하늘색.
  final bool light;
}

/// 흩뿌려진 작은 흰 반짝점 한 개의 정의.
class _FlowSparkle {
  const _FlowSparkle({
    required this.x,
    required this.speed,
    required this.offset,
    required this.radius,
  });

  /// 부채꼴 폭 대비 가로 위치. 0~1 밖이면 경계 바깥이다.
  final double x;

  /// 한 번 붓는 동안 위→아래를 도는 횟수(물방울보다 느리다).
  final double speed;

  /// 시작 위상(0~1).
  final double offset;

  /// 반짝점 반지름(본체 좌표계 px, 0.75~1.5 = 지름 1.5~3).
  final double radius;
}

/// 흐르는 흰 하이라이트 한 개의 정의.
class _FlowHighlight {
  const _FlowHighlight({
    required this.x,
    required this.speed,
    required this.offset,
    required this.length,
  });

  /// 그 y에서의 부채꼴 폭 대비 가로 위치(0=좌경계, 1=우경계).
  final double x;

  /// 한 번 붓는 동안 위→아래를 도는 횟수.
  final double speed;

  /// 시작 위상(0~1).
  final double offset;

  /// 본체 높이 대비 하이라이트 길이.
  final double length;
}
