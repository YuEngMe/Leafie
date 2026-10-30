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
import 'package:yeso_plant/services/notification_api.dart';
import 'package:yeso_plant/services/notification_target.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_motion.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/main_tab_shell.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/instant_page_route.dart';
import 'package:yeso_plant/widgets/home_components.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/services/sensor_api.dart';
import 'package:yeso_plant/widgets/home_sensor_gauges.dart';
import 'package:yeso_plant/widgets/retry_feedback.dart';
import 'package:yeso_plant/widgets/room_slide_switcher.dart';
import 'package:yeso_plant/services/home_dialogue_seen_store.dart';

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
  day(
    asset: 'assets/images/home_bg_default.png',
    phaseIcon: FigmaHomeIcon.sun,
    phaseIconOrigin: Offset(28, 113),
  ),
  afternoon(
    asset: 'assets/images/home_bg_afternoon.png',
    phaseIcon: FigmaHomeIcon.afternoon,
    phaseIconOrigin: Offset(34, 120),
  ),
  evening(
    asset: 'assets/images/home_bg_evening.png',
    phaseIcon: FigmaHomeIcon.moon,
    phaseIconOrigin: Offset(38, 119),
  ),
  lateEvening(
    asset: 'assets/images/home_bg_late_evening.png',
    phaseIcon: FigmaHomeIcon.moon,
    phaseIconOrigin: Offset(38, 119),
  );

  const HomeTimePeriod({
    required this.asset,
    required this.phaseIcon,
    required this.phaseIconOrigin,
  });

  final String asset;
  final FigmaHomeIcon phaseIcon;

  /// 시간대 아이콘 노드의 화면 좌상단. 해(4534:9603)·오후 해(4534:17769)·
  /// 달은 크기가 달라 시안에서도 자리가 조금씩 다르다. 달은 노드를 받지 않고
  /// 저녁 시안 이미지(LF-088·090)에 PNG를 맞대어 찾은 자리다.
  final Offset phaseIconOrigin;

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
    this.notificationRepository,
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

  /// 기본 알림 화면이 쓸 저장소. 테스트에서 갈아끼운다.
  final NotificationRepository? notificationRepository;
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
  String? _serverDialogueKey;
  SensorAssessment? _serverSensor;

  // 홈 대사 큐(#123). 서버가 준 오늘의 대사를 하나씩 정해진 시간만큼 보여
  // 준다. 보여 준 대사는 기기에 남겨 다시 띄우지 않는다.
  final _seenDialogues = const HomeDialogueSeenStore();
  Set<String>? _seenDialogueIds;
  final List<HomeDialogueEvent> _pendingDialogues = [];
  HomeDialogueEvent? _playingDialogue;
  Timer? _dialogueTimer;

  /// 이 화면에서 큐 대사를 하나라도 끝까지 보여 줬는가. 그랬다면 진단 유도
  /// 대사(DIAGNOSIS_PROMPT)는 다시 띄우지 않는다(api-spec 홈 §8).
  bool _playedDialogue = false;
  bool _loadingHome = false;
  String? _homeError;

  /// 마지막 홈 조회가 서버에 닿지도 못하고(연결 실패·시간 초과) 끝났는가.
  /// 이때는 오류 카드 대신 연결 끊김 모달(4955:3086)을 띄우고, 뒤의 게이지·
  /// 캐릭터는 직전 응답 그대로 둔다.
  bool _homeOffline = false;

  /// 연결 끊김 모달이 떠 있는 동안 다시 띄우지 않으려고 둔다.
  bool _disconnectedDialogOpen = false;

  /// 우편함이 홈 위에 떠 있는 동안. 시안 우체통 프레임(4534:11529~16319)은
  /// 알림 벨 자리에 닫기 X만 두므로, 그동안 벨·배지를 그리지 않는다.
  bool _mailboxOpen = false;

  /// 연결이 끊긴 조회의 식물. 다시 시도는 같은 요청을 다시 보낸다.
  String? _offlinePlantId;
  int _unreadNotificationCount = 0;
  int _unreadLetterCount = 0;
  List<ManagedPlant> _plants = const [];
  bool _switchingPlant = false;
  // 우편함을 열기 전 편지가 있는지 확인하는 중이면 다시 누른 탭을 무시한다.
  bool _checkingMailbox = false;
  // < > 로 방을 옮길 때 캐릭터·방 이름이 미끄러지는 방향(다음 1, 이전 −1).
  // 알림·관리 화면처럼 화살표가 아닌 이동은 0이라 미끄러지지 않는다.
  int _slideDirection = 0;
  // 캐릭터를 좌우로 문지르는 중이면 쓰담 반응을 계속 이어 간다(디자이너 답 7-B).
  bool _rubbing = false;
  final _tabShellKey = GlobalKey<MainTabShellState>();

  /// 내 캐릭터에서 돌아올 때마다 올려 캘린더 탭을 새로 만든다.
  int _careDataVersion = 0;

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
  // 달: 밤에 해 자리의 달을 탭하면 좌우로 흔들리다 멈춘다.
  late final AnimationController _moonController;

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
    _moonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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
    } else {
      // 등록 직후처럼 /home을 부르지 않는 경로도 배지는 센다.
      _refreshLetterBadge();
    }
    _loadPlants();
  }

  @override
  void dispose() {
    _dialogueTimer?.cancel();
    _careToastTimer?.cancel();
    _sunHideTimer?.cancel();
    _wateringAfterglowTimer?.cancel();
    _raysController.dispose();
    _wateringController.dispose();
    _petController.dispose();
    _moonController.dispose();
    super.dispose();
  }

  void _petCharacter() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _petController.forward(from: 0);
  }

  void _startRub() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    setState(() => _rubbing = true);
    _petController.forward(from: 0);
  }

  /// 문지르는 동안 흔들림이 끝날 때마다 다시 흔든다. 도중에 처음부터 다시
  /// 돌리면 흔들림이 끊겨 떨리는 것처럼 보여서 끝난 뒤에만 잇는다.
  void _continueRub() {
    if (!_rubbing || _petController.isAnimating) return;
    _petController.forward(from: 0);
  }

  void _endRub() {
    if (_rubbing) setState(() => _rubbing = false);
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
      _rubbing ||
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncDialoguePlayback(),
    );
  }

  void _startPlantRegistration(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlantRegisterNameScreen()));
  }

  void _handlePeriodIconTap() {
    // 달이 뜬 시간대(evening/lateEvening)엔 해 자리에 달 아이콘이 뜬다.
    // 달을 눌러도 햇빛(광선/토스트)은 나오면 안 되고, 달만 흔들린다
    // (디자이너 요청 2026-10: 눌러도 반응이 없었다).
    // 햇빛은 낮(day)·오후해(afternoon)일 때만 발동한다.
    final period = widget.period ?? HomeTimePeriod.fromDateTime(DateTime.now());
    if (period.phaseIcon == FigmaHomeIcon.moon) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _moonController.forward(from: 0);
      }
      return;
    }
    // 해를 언제 눌러도 광선과 토스트가 뜬다(씬 상태와 무관한 로컬 모션).
    // needsLight일 때만 씬을 감사 상태(cared)로 넘긴다.
    _showCareToast('햇빛을 줬어요!');
    _sunHideTimer?.cancel();
    setState(() {
      _sunActive = true;
      if (_scene == HomeScene.needsLight) _scene = HomeScene.cared;
    });
    _syncDialoguePlayback();
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
        _syncDialoguePlayback();
        return;
      }
      _raysController.reverse().whenComplete(() {
        if (!mounted) return;
        setState(() => _sunActive = false);
        // 감사 반응이 끝나면 멈춰 둔 큐 대사를 이어서 보여 준다.
        _syncDialoguePlayback();
      });
    });
  }

  /// 늦게 도착한 이전 식물 응답이 새 식물 화면을 덮지 않도록 마지막 요청만
  /// 반영한다.
  int _homeRequest = 0;

  /// 응답을 반영했으면 true. 실패했거나 더 새 요청에 밀렸으면 false.
  Future<bool> _loadHome([String? plantId]) async {
    final request = ++_homeRequest;
    try {
      final data = widget.loadHomeForPlant != null
          ? await widget.loadHomeForPlant!(plantId)
          : plantId == null && widget.loadHome != null
          ? await widget.loadHome!()
          : await HomeApi().fetchHome(plantId: plantId);
      if (!mounted || request != _homeRequest) return false;
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
        _serverDialogueKey = room?.dialogueKey;
        _serverSensor = room?.sensor;
        _unreadNotificationCount = data.unreadNotificationCount;
        _loadingHome = false;
        _homeError = null;
        _homeOffline = false;
        // 씬은 매 응답에서 다시 정한다. 한 번 needsWater가 되면 되돌리는
        // 곳이 없어 다른 식물로 넘어가도 목마른 말풍선이 남았다. 서버 대사는
        // 성격별 평소 대사(NORMAL)도 항상 채워 오므로 대사 유무가 아니라
        // 상황으로 정한다. 물은 오늘 할 일이라 햇빛보다 먼저 띄운다.
        _scene = switch (room?.dialogueKey) {
          _ when hasWateringRequest => HomeScene.needsWater,
          'SOIL_MOISTURE_LOW' => HomeScene.needsWater,
          'LIGHT_LOW' => HomeScene.needsLight,
          _ => HomeScene.idle,
        };
      });
      unawaited(_refreshLetterBadge());
      unawaited(
        _enqueueDialogues(room?.dialogueQueue ?? const [], room?.dialogueKey),
      );
      return true;
    } on LeafieApiException catch (error) {
      if (!mounted || request != _homeRequest) return false;
      // 시안 4955:3086 문구가 '리피와 연결이 끊겼어요 / 인터넷 연결을
      // 확인하고'라 서버에 닿지 못한 경우만 모달로 보낸다. 서버가 답한
      // 오류(4xx·5xx)는 연결 문제가 아니어서 기존 오류 카드에 남긴다.
      final offline = _isConnectionFailure(error);
      setState(() {
        _loadingHome = false;
        _homeOffline = offline;
        _homeError = offline ? null : error.message;
      });
      if (offline) {
        _offlinePlantId = plantId;
        unawaited(_showDisconnectedDialog());
      }
      return false;
    }
  }

  /// LeafieApiClient가 IOException·TimeoutException을 바꿔 던지는 코드.
  static bool _isConnectionFailure(LeafieApiException error) =>
      error.code == 'NETWORK_ERROR' || error.code == 'NETWORK_TIMEOUT';

  Future<void> _showDisconnectedDialog() async {
    if (_disconnectedDialogOpen) return;
    _disconnectedDialogOpen = true;
    // 시안에 닫기 버튼이 없고 '다시 시도' 하나뿐이라 딤을 눌러 닫지 않는다.
    await showConfirmDialog(
      context,
      barrierColor: kModalBarrier,
      barrierDismissible: false,
      dialog: _HomeDisconnectedDialog(onRetry: _retryAfterDisconnect),
    );
    _disconnectedDialogOpen = false;
  }

  /// 모달을 닫아도 되면 true. 다시 연결에 실패하면 모달을 그대로 둔다.
  Future<bool> _retryAfterDisconnect() async {
    await _loadHome(_offlinePlantId);
    return !mounted || !_homeOffline;
  }

  /// 우편함은 지금 방 식물의 편지만 보여 주므로(시안 우체통_0~5) 배지도
  /// 같은 식물 기준으로 센다. 홈 응답의 unread_letter_count는 전체 식물
  /// 합계라 쓰지 않는다.
  Future<void> _refreshLetterBadge() async {
    final plantId = (_serverPlant ?? widget.plant)?.id;
    if (plantId == null) {
      if (mounted) setState(() => _unreadLetterCount = 0);
      return;
    }
    try {
      final count = await _letterRepository.unreadCount(plantId);
      // 그사이 다른 식물로 넘어갔으면 이전 식물 개수를 띄우지 않는다.
      if (!mounted || (_serverPlant ?? widget.plant)?.id != plantId) return;
      setState(() => _unreadLetterCount = count);
    } catch (_) {
      // 배지는 부가 정보라 조회에 실패해도 홈을 막지 않고 배지만 숨긴다.
      if (mounted) setState(() => _unreadLetterCount = 0);
    }
  }

  void _openDiagnosis() {
    final plant = _serverPlant ?? widget.plant;
    Navigator.of(context).push(
      // 홈에서 잠깐 열어 보는 화면이라 슬라이드 없이 한 번에 띄운다(10/31).
      InstantPageRoute<void>(
        builder: (_) =>
            DiagnosisScreen(plantId: plant?.id, plantName: plant?.name),
      ),
    );
  }

  /// 권유 대사를 누르면 그 일을 할 화면으로 보낸다(디자이너 확인).
  /// 일기 권유 → 다이어리 탭, 진단 권유 → 진단 화면.
  void _openPrompt(String dialogueKey) {
    switch (dialogueKey) {
      case 'DIARY_PROMPT':
        _tabShellKey.currentState?.select(FigmaNavIcon.diary);
      case 'DIAGNOSIS_PROMPT':
        _openDiagnosis();
    }
  }

  Future<void> _openMailbox(String? plantId) async {
    if (_checkingMailbox || _mailboxOpen) return;
    // 편지가 하나도 없으면 빈 우편함 창을 띄우지 않고 아무 반응도 하지
    // 않는다(디자이너 답 4-C). 목록을 못 불러오면 우편함이 직접 오류를
    // 보여 주도록 그대로 연다.
    List<PlantLetter>? letters;
    if (plantId != null) {
      _checkingMailbox = true;
      try {
        letters = await _letterRepository.listLetters(plantId);
      } catch (_) {
        letters = null;
      } finally {
        _checkingMailbox = false;
      }
      if (!mounted || (letters != null && letters.isEmpty)) return;
    }
    setState(() => _mailboxOpen = true);
    try {
      await showPlantMailbox(
        context,
        plantId: plantId,
        repository: _letterRepository,
        initialLetters: letters,
      );
    } finally {
      if (mounted) setState(() => _mailboxOpen = false);
    }
    // 편지를 읽거나 지웠을 수 있으니 닫힌 뒤 다시 센다.
    if (mounted) await _refreshLetterBadge();
  }

  Future<void> _loadPlants() async {
    try {
      final plants = await _plantRepository.listPlants();
      if (mounted) setState(() => _plants = plants);
    } on LeafieApiException {
      // 홈 본문은 /home 응답으로 표시할 수 있으므로 목록 실패만으로 막지 않는다.
    }
  }

  /// 요청 말풍선에 넣을 서버 대사. 말풍선과 같은 상황의 대사만 쓴다.
  /// 평소 대사(NORMAL)나 다른 상황의 대사를 넣으면 말풍선과 안 맞는 문장이
  /// 뜨므로, 그때는 null을 돌려 시안 문구를 쓰게 한다.
  String? get _requestDialogue {
    final expectedKey = switch (_scene) {
      HomeScene.needsWater => 'SOIL_MOISTURE_LOW',
      HomeScene.needsLight => 'LIGHT_LOW',
      _ => null,
    };
    return expectedKey != null && _serverDialogueKey == expectedKey
        ? _serverDialogue
        : null;
  }

  /// 방을 옮길 때 이전 식물에 걸던 돌보기 모션·토스트·말풍선을 지운다.
  /// 새 식물의 씬은 _loadHome 응답으로 다시 정해진다.
  void _resetRoomMotion() {
    _careToastTimer?.cancel();
    _sunHideTimer?.cancel();
    _wateringAfterglowTimer?.cancel();
    _raysController.value = 0;
    _wateringController.value = 0;
    _petController.value = 0;
    _rubbing = false;
    _slideDirection = 0;
    _sunActive = false;
    _wateringAfterglow = false;
    _careToastLabel = null;
    _careToastOpacity = 0;
    _serverDialogue = null;
    _serverDialogueKey = null;
    _serverSensor = null;
    _dialogueTimer?.cancel();
    _pendingDialogues.clear();
    _playingDialogue = null;
    _scene = HomeScene.idle;
  }

  /// [plantId]를 서버에 고르고 그 식물의 홈을 불러온다. 고르기에 실패하면
  /// 예외를 그대로 던진다(아무것도 바뀌지 않았다).
  ///
  /// 고르기는 됐는데 홈을 못 불러오면 화면은 이전 식물에 남는다. 서버
  /// 선택만 새 식물로 넘어가 있으면 다음 실행·알림 이동이 화면과 다른
  /// 식물을 연다(HG-ISS-009). 그래서 서버가 오류로 답한 경우 선택을 이전
  /// 식물로 되돌리고, 되돌렸으면 오류 카드 대신 안내만 띄워 이전 방을
  /// 그대로 보여 준다. 연결이 끊긴 경우는 되돌리기도 닿지 않으므로 선택을
  /// 새 식물에 두고, 연결 끊김 모달의 다시 시도가 새 식물을 불러온다.
  Future<bool> _selectAndLoad(String plantId) async {
    final previousId = (_serverPlant ?? widget.plant)?.id;
    await _plantRepository.selectPlant(plantId);
    final request = _homeRequest + 1;
    if (await _loadHome(plantId)) {
      await _loadPlants();
      return true;
    }
    // 그사이 다른 조회가 시작돼 이 응답을 버렸으면 실패가 아니다.
    final failure = _homeError;
    if (!mounted ||
        request != _homeRequest ||
        failure == null ||
        previousId == null) {
      return false;
    }
    try {
      await _plantRepository.selectPlant(previousId);
    } on LeafieApiException {
      // 되돌리지 못하면 서버 선택은 새 식물이다. 오류 카드의 다시 불러오기가
      // 서버 선택(새 식물)을 불러오므로 카드를 그대로 둔다.
      return false;
    }
    if (!mounted) return false;
    setState(() => _homeError = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure)));
    await _loadPlants();
    return false;
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
    setState(() {
      _switchingPlant = true;
      _resetRoomMotion();
      _slideDirection = delta.sign;
    });
    try {
      await _selectAndLoad(next.id);
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
      // 내 캐릭터(전체보기)도 홈에서 잠깐 열어 보는 화면이라 한 번에 띄운다.
      InstantPageRoute(
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
    // 내 캐릭터에서 물 준 날·분갈이 날을 고치면 서버가 다음 예정일을 다시
    // 계산한다(#116). 이미 열어 둔 캘린더 탭은 처음 만들 때만 일정을
    // 불러오므로, 새로 만들어 다시 불러오게 한다.
    setState(() => _careDataVersion++);
    await _loadHome(selectedPlantId);
    await _loadPlants();
  }

  Future<void> _openNotifications() async {
    // 알림을 누르면 목록을 닫고 그 알림을 돌려받아 홈에서 이동한다. 우편함은
    // 홈 위에 뜨는 화면이고 캘린더는 홈의 탭이라, 알림 화면 위에 쌓지 않는다.
    final selected = await Navigator.of(context).push<NotificationData>(
      // 알림센터는 슬라이드 없이 한 번에 띄운다(10/31 피드백).
      InstantPageRoute(
        builder:
            widget.notificationBuilder ??
            (routeContext) => NotificationScreen(
              repository: widget.notificationRepository,
              plants: _plants,
              onNotificationSelected: (notification) {
                // 갈 곳이 없는 알림은 읽음 처리만 하고 목록에 머문다.
                if (notificationTargetOf(notification) == null) return;
                // 두 알림을 빠르게 연달아 누르면 pop이 두 번 불려 홈까지
                // 닫힐 수 있다. 알림 화면이 맨 위일 때만 닫는다.
                if (ModalRoute.of(routeContext)?.isCurrent != true) return;
                Navigator.of(routeContext).pop(notification);
              },
            ),
      ),
    );
    if (!mounted) return;
    await _loadHome((_serverPlant ?? widget.plant)?.id);
    // 연결이 끊겼으면 방금 띄운 연결 끊김 모달 위로 화면을 쌓지 않는다.
    // 쌓으면 그 화면이 모달을 가려 뒤로 가야 모달이 보였다.
    if (!mounted || selected == null || _homeOffline) return;
    await _openNotificationTarget(selected);
  }

  /// 서버가 준 오늘의 큐로 대기열을 다시 만든다. 서버가 뺀 이벤트(해결된
  /// 센서 이상 등)는 버리고, 상황 말풍선이 이미 같은 대사를 띄우는 키는 건너뛴다.
  Future<void> _enqueueDialogues(
    List<HomeDialogueEvent> events,
    String? fallbackKey,
  ) async {
    final plantId = (_serverPlant ?? widget.plant)?.id;
    final seen = _seenDialogueIds ??= await _seenDialogues.load();
    // 본 목록을 읽는 사이 다른 식물로 넘어갔으면 이전 식물 대사를 붙이지 않는다.
    if (!mounted || plantId != (_serverPlant ?? widget.plant)?.id) return;
    final playingId = _playingDialogue?.eventId;
    _pendingDialogues
      ..clear()
      ..addAll(
        events.where(
          (event) =>
              !seen.contains(event.eventId) &&
              event.eventId != playingId &&
              event.dialogueKey != fallbackKey,
        ),
      );
    _syncDialoguePlayback();
  }

  /// 큐 대사가 실제로 보이는 상태인가. 게이지 패널이 펼쳐졌거나 돌봄 반응
  /// 말풍선이 떠 있으면 가려진 것으로 본다. 해를 눌러 생긴 감사 반응
  /// ("아 따뜻해~고마워!")은 광선이 떠 있는 동안(약 3초)만 큐를 비켜 준다.
  bool get _dialogueVisible =>
      !_gaugesExpanded &&
      !(_scene == HomeScene.cared && _sunActive) &&
      _scene != HomeScene.happy;

  /// 보이면 이어서 재생하고, 가려지면 지금 대사를 멈춰 대기열 맨 앞으로
  /// 되돌린다. 보이는 상태가 바뀌는 모든 곳에서 부른다.
  void _syncDialoguePlayback() {
    if (!mounted) return;
    if (_dialogueVisible) {
      _playNextDialogue();
      return;
    }
    final playing = _playingDialogue;
    if (playing == null) return;
    _dialogueTimer?.cancel();
    _pendingDialogues.insert(0, playing);
    setState(() => _playingDialogue = null);
  }

  void _playNextDialogue() {
    if (!mounted ||
        _playingDialogue != null ||
        !_dialogueVisible ||
        _pendingDialogues.isEmpty) {
      return;
    }
    final next = _pendingDialogues.removeAt(0);
    setState(() => _playingDialogue = next);
    _dialogueTimer?.cancel();
    _dialogueTimer = Timer(next.duration, () {
      if (!mounted) return;
      // 끝까지 보여 준 대사만 본 것으로 남긴다. 중간에 가려지면 다시 나온다.
      _seenDialogueIds?.add(next.eventId);
      unawaited(_seenDialogues.markSeen(next.eventId));
      setState(() {
        _playingDialogue = null;
        _playedDialogue = true;
      });
      _playNextDialogue();
    });
  }

  /// 알림이 가리키는 식물로 방을 옮긴다. 이미 그 식물이면 그대로 둔다.
  /// 옮기지 못했으면(다른 전환 중, 실패) false.
  Future<bool> _showPlant(String plantId) async {
    if (plantId == (_serverPlant ?? widget.plant)?.id) return true;
    if (_switchingPlant) return false;
    setState(() {
      _switchingPlant = true;
      _resetRoomMotion();
    });
    var loaded = false;
    try {
      loaded = await _selectAndLoad(plantId);
    } on LeafieApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _switchingPlant = false);
    }
    return loaded;
  }

  Future<void> _openNotificationTarget(NotificationData notification) async {
    switch (notificationTargetOf(notification)) {
      case MailboxTarget(:final plantId):
        await _openMailbox(plantId);
      case DiagnosisTarget(:final diagnosisId):
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DiagnosisDetailScreen(diagnosisId: diagnosisId),
          ),
        );
      case CalendarTarget(:final plantId):
        // 캘린더 탭은 지금 방의 식물을 보여 주므로 알림의 식물로 먼저 옮긴다.
        // 식물을 못 옮겼으면 엉뚱한 식물의 캘린더를 열지 않는다.
        if (!await _showPlant(plantId) || !mounted) return;
        _tabShellKey.currentState?.select(FigmaNavIcon.calendar);
      case PlantHomeTarget(:final plantId):
        // 센서 알림은 그 식물의 방으로 옮겨 게이지를 펼쳐 보여 준다.
        if (!await _showPlant(plantId) || !mounted) return;
        _tabShellKey.currentState?.select(FigmaNavIcon.home);
        setState(() => _gaugesExpanded = true);
        _syncDialoguePlayback();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plant = _serverPlant ?? widget.plant;
    return MainTabShell(
      key: _tabShellKey,
      home: _buildHome(context),
      diaryBuilder: (_) => DiaryScreen(
        key: ValueKey(plant?.id),
        plantId: plant?.id,
        resolvePlantIdIfMissing: false,
        showBottomNav: false,
      ),
      calendarBuilder: (_) => CalendarScreen(
        key: ValueKey('${plant?.id}#$_careDataVersion'),
        plantId: plant?.id,
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
                  roomKey: plant?.id,
                  slideDirection: _slideDirection,
                  dayCount: plant?.dayCount,
                  period: period,
                  unreadNotificationCount: _unreadNotificationCount,
                  showNotifications: !_mailboxOpen,
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
                  // 해 노드(4534:9603)는 (28,113)에 80×80이라 중심이 (68,153).
                  // 정점을 해 중심에 맞추려면 left=68-32=36, top=153-15=138.
                  Positioned(
                    left: 36,
                    top: 138,
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
                // 누르기 쉽게 사방 4px을 더 받으므로 노드 좌상단에서 4를 뺀다.
                Positioned(
                  left: period.phaseIconOrigin.dx - 4,
                  top: period.phaseIconOrigin.dy - 4,
                  child: GestureDetector(
                    key: const ValueKey('home-period-control'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _handlePeriodIconTap,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AnimatedBuilder(
                        animation: _moonController,
                        // 달: ±0.15rad(약 9°)를 세 번 왕복하며 줄어든다.
                        builder: (context, child) => Transform.rotate(
                          key: const ValueKey('home-moon-swing'),
                          angle: _moonController.isAnimating
                              ? math.sin(_moonController.value * math.pi * 6) *
                                    0.15 *
                                    (1 - _moonController.value)
                              : 0,
                          child: child,
                        ),
                        child: FigmaHomeAssetIcon(period.phaseIcon),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 333,
                  top: 113,
                  child: FigmaHomeViewSwitch(
                    onOverviewTap: _openPlantManagement,
                    onDiagnosisTap: _openDiagnosis,
                  ),
                ),
                if (plant != null && !_gaugesExpanded)
                  _HomeConversation(
                    scene: _scene,
                    serverDialogue: _requestDialogue,
                    queueMessage: _playingDialogue?.dialogue,
                    queueKey: _playingDialogue?.dialogueKey,
                    fallbackKey: _serverDialogueKey,
                    onPromptTap: _openPrompt,
                    // 상황 말풍선이 없을 때는 서버의 기본 대사(평소·일기·진단
                    // 권유·조도 적당 등)를 띄운다.
                    fallbackMessage:
                        _serverDialogueKey == 'DIAGNOSIS_PROMPT' &&
                            _playedDialogue
                        ? null
                        : _serverDialogue,
                  ),
                if (plant != null && _unreadLetterCount > 0)
                  // 시안(4534:9698) 편지 배지: 우편함 위에 뜬다. 노드는 x=319
                  // y=390 55×62.188이고, PNG에는 그림자 여백 4(시안 inset
                  // −7.27%·−6.43%)가 사방에 들어 있어 그만큼 넘쳐 그린다. 노드
                  // 상자에 PNG 전체를 넣으면 봉투가 약 13% 작아졌다.
                  Positioned(
                    left: 319 - 4,
                    top: 390 - 4,
                    width: 55 + 8,
                    height: 62.188 + 8,
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
                  // 화살표로 방을 옮기면 지금 캐릭터는 밀려 나가고 다음 캐릭터가
                  // 반대쪽에서 들어온다(디자이너 답 5-A). 배경은 시간대 그림이라
                  // 그대로 둔다.
                  //
                  // 머리(잎)는 박스 위로 넘쳐 그려져 박스만으로는 눌리지 않는다.
                  // 그래서 자리를 _kCharacterHairRoom만큼 위로 넓히고, 그 안에서
                  // 몸통 박스와 머리 그림 영역만 터치를 받게 해 잎을 눌러도
                  // 쓰다듬는다(10/31 피드백). 잎 옆 빈 하늘은 그대로 통과한다.
                  Positioned(
                    // 앞쪽 말풍선·배지가 생기고 사라져도 전환 중인 캐릭터 상태를
                    // 다른 자리와 바꿔 쓰지 않도록 키로 묶는다.
                    key: const ValueKey('home-character-slot'),
                    left: 123 - (173.02 - 155.2) / 2,
                    top: 396 - 8.74 - _kCharacterHairRoom,
                    width: 173.02,
                    child: RoomSlideSwitcher(
                      direction: _slideDirection,
                      // 캐릭터 폭 두 배를 밀어야 402 화면 밖으로 완전히 나간다.
                      distance: 2,
                      child: Semantics(
                        key: ValueKey('home-room-${plant.id}'),
                        button: true,
                        label: '쓰담쓰담',
                        child: GestureDetector(
                          key: const ValueKey('home-character-pet'),
                          behavior: HitTestBehavior.deferToChild,
                          onTap: _petCharacter,
                          onHorizontalDragStart: (_) => _startRub(),
                          onHorizontalDragUpdate: (_) => _continueRub(),
                          onHorizontalDragEnd: (_) => _endRub(),
                          onHorizontalDragCancel: _endRub,
                          child: _CharacterHitArea(
                            hairPath: PlantCharacterArt.hairHitPath(
                              width: 173.02,
                              body: plantBodyFromId(plant.bodyId),
                              hairId: plant.hairId,
                            ),
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
                                // 돌보기 중엔 기쁜 표정, 평소엔 서버가 정한 표정
                                // (#124: 센서가 부족·과다면 슬픔, 둘 다 적당하면
                                // 기쁨, 그 외 기본). 얼굴만 크로스페이드한다.
                                final expression = _isBeingCaredFor
                                    ? PlantExpression.happy
                                    : plantExpressionFromId(plant.expressionId);
                                return Transform.translate(
                                  offset: Offset(0, -bounce),
                                  child: Transform.rotate(
                                    angle: wiggle,
                                    child: PlantCharacterArt(
                                      width: 173.02,
                                      body: plantBodyFromId(plant.bodyId),
                                      expression: expression,
                                      colorId: plant.colorId,
                                      hairId: plant.hairId,
                                      faceSwitchDuration:
                                          MediaQuery.disableAnimationsOf(
                                            context,
                                          )
                                          ? Duration.zero
                                          : const Duration(milliseconds: 200),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (plant != null)
                  // 물줄기(시안 4534:11340 "Group 1597881924").
                  //
                  // 시안 "물 주는 모션"(4534:10942)에서 물줄기·물뿌리개 그룹은
                  // 캐릭터 그룹 위에 있다. 물이 잎 앞으로 쏟아지도록 캐릭터
                  // 다음에 둔다.
                  //
                  // 본체는 시안 vector(Vector 1537)를 3배로 렌더한 PNG다. 주둥이
                  // (로컬 x≈83.5 y≈4~24)에서 왼쪽으로 휘어 나간 뒤 아래로
                  // 떨어지는 곡선이고, 색은 시안 linear 그라디언트(위 #AAE7F1 →
                  // 아래 투명), 가장자리는 시안 feTurbulence 물결 질감이다.
                  // flutter_svg가 이 질감을 못 그려서 SVG 대신 PNG를 쓴다.
                  //
                  // 그 위에 _WaterFlowPainter가 시안의 흰 선·물방울·반짝점을
                  // 물줄기 곡선을 따라 주둥이에서 흘려보낸다(콸콸 느낌). 본체
                  // 자체는 형태 고정이라 Transform으로 좌우 흔들림 + 미세 scaleX
                  // 맥동을 줘 물이 출렁이게 한다.
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
                        // 시안 절대좌표. 붓는 동안 물이 주둥이에서 살짝
                        // 흘러내린다.
                        left: _kWaterStreamLeft,
                        top: _kWaterStreamTop + 8 * (1 - phase),
                        width: _kWaterStreamWidth,
                        height: _kWaterStreamHeight,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: phase,
                            child: Transform(
                              // 주둥이 쪽을 축으로 흔들어 입구는 제자리에 둔다.
                              alignment: const Alignment(0.36, -1),
                              transform: Matrix4.identity()
                                ..translateByDouble(sway, 0, 0, 1)
                                ..scaleByDouble(scaleX, 1, 1, 1),
                              child: Stack(
                                children: [
                                  Image.asset(
                                    'assets/images/home_water_stream.png',
                                    width: _kWaterStreamWidth,
                                    height: _kWaterStreamHeight,
                                    fit: BoxFit.fill,
                                  ),
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _WaterFlowPainter(
                                        pour: reduceMotion
                                            ? _kWaterStillPour
                                            : pour,
                                      ),
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
                            // 0~0.25 떠올라 이동+회전, 0.25~0.75 붓는 자세 유지,
                            // 0.75~1.0 원위치 복귀. raise는 목표 상태로의
                            // 진행도(0=원위치, 1=시안 붓는 위치).
                            // 떠오를 때는 탭에 바로 반응하도록 빨리 출발하는
                            // ease-out, 돌아올 때는 화면을 가로지르는 이동이라
                            // ease-in-out으로 부드럽게 내려앉힌다. 예전
                            // easeIn은 끝까지 가속해 제자리에 "쾅" 멈췄다.
                            final double raise;
                            if (t <= 0) {
                              raise = 0;
                            } else if (t < 0.25) {
                              raise = AppMotion.easeOut.transform(t / 0.25);
                            } else if (t < 0.75) {
                              raise = 1;
                            } else {
                              raise = 1 -
                                  AppMotion.easeInOut.transform(
                                    (t - 0.75) / 0.25,
                                  );
                            }
                            // 좌하단 원위치(위젯중심 x≈55.5 y≈529.9)에서 시안
                            // 몸통 중심(x≈262 y≈193=캐릭터 위 오른쪽)까지 대각선
                            // 이동. dx/dy는 위젯 중심 기준 이동량이라 center 회전과
                            // 결합해도 몸통 중심이 목표에 머문다. 목표는 시안
                            // LF-078 이미지에 1.355배·34.48° 물뿌리개를 맞대어
                            // 찾은 자리다.
                            const dx = 206.5;
                            const dy = -336.9;
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
                                // 향하도록 반시계로 기운다. 시안 붓는 프레임
                                // (4534:11397)은 34.48°(≈0.602rad)다.
                                alignment: Alignment.center,
                                angle: -_kWateringPourAngle * raise + nod,
                                child: Transform.scale(
                                  // 붓는 물뿌리개는 113.804×91.812로, 평소
                                  // 83.98×67.751보다 1.355배 크다.
                                  scale: 1 + (_kWateringPourScale - 1) * raise,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          // PNG에는 그림자 여백(시안 inset 위아래 −2.24%,
                          // 오른쪽 −1.81%, 왼쪽 −0.77%)이 들어 있어 노드
                          // 상자 밖으로 넘쳐 그린다. 회전·확대 중심은 노드
                          // 상자 가운데 그대로다.
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: -0.6467,
                                top: -1.5176,
                                width: 83.98 + 0.6467 + 1.52,
                                height: 67.751 + 1.5176 * 2,
                                child: Image.asset(
                                  'assets/images/home_watering_can.png',
                                  fit: BoxFit.fill,
                                  semanticLabel: '물뿌리개',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (plant != null)
                  // 우체통 노드(4534:9607) 좌상단. 그림자 여백은 아이콘이
                  // 바깥으로 넘쳐 그린다.
                  Positioned(
                    left: 310,
                    top: 461,
                    child: Semantics(
                      button: true,
                      label: '우편함 열기',
                      child: GestureDetector(
                        key: const ValueKey('home-mailbox'),
                        onTap: () => _openMailbox(plant.id),
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
                else if (_homeOffline && plant == null)
                  // 첫 조회부터 끊겼으면 식물을 모른다. 연결 끊김 모달이 덮고
                  // 있으니 '등록된 식물이 없어요' 안내를 잘못 띄우지 않는다.
                  const SizedBox.shrink()
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
                    sensor: _serverSensor,
                    plantName: plant.name,
                    onCollapse: () {
                      setState(() => _gaugesExpanded = false);
                      _syncDialoguePlayback();
                    },
                  )
                else
                  _HomeStatusCard(
                    onTap: () {
                      setState(() => _gaugesExpanded = true);
                      _syncDialoguePlayback();
                    },
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
    required this.showNotifications,
    required this.canSwitchPlant,
    this.roomKey,
    this.slideDirection = 0,
    required this.onPreviousPlant,
    required this.onNextPlant,
    required this.onManagePlants,
    required this.onNotifications,
  });

  final String? roomName;
  final int? dayCount;
  final HomeTimePeriod period;
  final int unreadNotificationCount;

  /// 우편함 닫기 X(지름 37)가 벨 자리를 덮지만 배지가 원 밖으로 비쳐서,
  /// 우편함이 떠 있는 동안에는 벨을 통째로 뺀다.
  final bool showNotifications;
  final bool canSwitchPlant;

  /// 방 이름이 바뀔 때 미끄러지는 기준. 식물 id가 바뀌면 [slideDirection]
  /// 쪽으로 밀려 나가고 새 이름이 반대쪽에서 들어온다.
  final String? roomKey;
  final int slideDirection;
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
          // 시안 4534:17295 D+ 글자 x=33 y=60. Flutter 글자 상자가 시안보다
          // 커서 보이는 글자 윗변(시안 63)이 맞도록 top을 61로 둔다.
          Positioned(
            left: 33,
            top: 61,
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
                  // 시안 4534:17207 방 이름: Paperlogy 5 Medium(500) 16.
                  // 이름 칸 안에서만 미끄러지게 잘라 화살표 위로 넘치지 않게 한다.
                  child: ClipRect(
                    child: RoomSlideSwitcher(
                      direction: slideDirection,
                      distance: 1,
                      child: Text(
                        roomName == null ? '내 식물' : '$roomName 방',
                        key: ValueKey('home-room-name-$roomKey'),
                        style: kItemStyle.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
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
        // 시안 4534:17221 벨 노드 (341,55) 28×31을 56×48 탭 영역 가운데에
        // 둔다(402 − 341 − 28 − 14 = 19).
        if (showNotifications)
          Positioned(
            right: 19,
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
  const _HomeConversation({
    required this.scene,
    required this.serverDialogue,
    this.queueMessage,
    this.fallbackMessage,
    this.queueKey,
    this.fallbackKey,
    this.onPromptTap,
  });

  /// 누르면 화면을 옮기는 권유 대사 키.
  static const promptKeys = {'DIARY_PROMPT', 'DIAGNOSIS_PROMPT'};

  final String? queueKey;
  final String? fallbackKey;
  final ValueChanged<String>? onPromptTap;

  final HomeScene scene;
  final String? serverDialogue;

  /// 지금 재생 중인 큐 대사. 있으면 상황 말풍선보다 먼저 보인다.
  final String? queueMessage;

  /// 상황 말풍선이 없을 때(idle) 띄울 서버 기본 대사.
  final String? fallbackMessage;

  /// 디자이너 확인: 새 대사 말풍선은 기존 요청 말풍선 모양을 재사용한다.
  /// 권유 대사면 누를 수 있게 감싼다.
  Widget _serverBubble(Key key, String message, String? dialogueKey) {
    Widget bubble = PlantRequestBubble(key: key, message: message);
    final onTap = onPromptTap;
    if (onTap != null && promptKeys.contains(dialogueKey)) {
      bubble = Semantics(
        button: true,
        child: GestureDetector(
          key: ValueKey('home-dialogue-prompt-$dialogueKey'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(dialogueKey!),
          child: bubble,
        ),
      );
    }
    return Positioned(
      left: 20,
      right: 20,
      top: 209,
      child: Center(child: bubble),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (queueMessage case final message? when message.isNotEmpty) {
      return _serverBubble(
        const ValueKey('home-dialogue-queue'),
        message,
        queueKey,
      );
    }
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
      HomeScene.needsLight => Positioned(
        left: 0,
        right: 0,
        top: 209,
        child: Center(
          child: PlantRequestBubble(
            message: serverDialogue?.isNotEmpty == true
                ? serverDialogue!
                : '나 햇빛이 부족해..',
          ),
        ),
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
      // 시안 4534:17213 / 17219 / 17211 — 102×38 흰 말풍선. '히히'만
      // 말풍선 전체(글자·그림자 포함)가 투명도 60%이고 나머지 둘은 불투명이다.
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
              child: _RoomBubble(label: '신난다', width: 102, height: 38),
            ),
            Positioned(
              left: 145,
              top: 251,
              child: _RoomBubble(label: '좋은 하루야!', width: 102, height: 38),
            ),
          ],
        ),
      ),
      HomeScene.idle => switch (fallbackMessage) {
        final message? when message.isNotEmpty => _serverBubble(
          const ValueKey('home-dialogue-fallback'),
          message,
          fallbackKey,
        ),
        _ => const SizedBox.shrink(),
      },
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
  const _HomeEnvironmentPanel({
    required this.sensor,
    required this.plantName,
    required this.onCollapse,
  });

  final SensorAssessment? sensor;
  final String plantName;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 575,
      height: 220,
      // 시안 4534:7922: 흰 30%. 배경 흐림(background blur) 효과는 없어 뒤
      // 풀밭이 또렷하게 비친다. 시안의 바깥 그림자(0 0 5, 20%)는 Flutter
      // BoxShadow가 반투명 판 안쪽까지 깔려 판 전체가 어두워지므로 넣지 않는다.
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
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
            if (sensorPanelMessage(sensor) case final message?)
              Positioned(
                left: 34,
                right: 34,
                // Figma 3822:601: y=683, relative to the panel at y=575.
                top: 108,
                child: Text(
                  message,
                  key: const ValueKey('home-environment-message'),
                  textAlign: TextAlign.center,
                  // 최신 시안(4534:22)에는 이 상태가 없어 옛 시안(3822:601)의
                  // 21을 그대로 둔다. 타이틀 스타일이 20으로 바뀌어 명시한다.
                  style: kTitleStyle.copyWith(
                    fontSize: 21,
                    color: const Color(0xFF434343),
                  ),
                ),
              )
            else ...[
              // 시안 4534:7570: 습도 게이지 y=606, 조도 게이지 y=697
              // (패널 top 575 기준 31·122), x=33.8, 폭 335.5.
              _gauge(
                top: 606 - 575,
                kind: EnvironmentGaugeKind.humidity,
                content: soilGaugeContent(sensor!.soil, plantName),
              ),
              _gauge(
                top: 697 - 575,
                kind: EnvironmentGaugeKind.light,
                content: lightGaugeContent(sensor!.light, plantName),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gauge({
    required double top,
    required EnvironmentGaugeKind kind,
    required SensorGaugeContent content,
  }) => Positioned(
    left: 33.8,
    width: 335.5,
    top: top,
    child: EnvironmentGauge(
      key: ValueKey('home-gauge-${kind.name}'),
      kind: kind,
      description: content.description,
      currentRatio: content.currentRatio,
      comfortRatio: content.comfortRatio,
      currentLabel: content.currentLabel,
      maxLabel: content.maxLabel,
      alert: content.alert,
      animateFill: true,
    ),
  );
}

/// 홈 재조회가 서버에 닿지 못했을 때 뜨는 연결 끊김 모달(4955:3086).
///
/// 상자·제목·부제 자리는 확인 모달(ConfirmDialog, 부제 있는 경우)과 같다:
/// (47, 358) 308x158.829, 제목 top 40, 부제 top 68. 아래만 구분선·두 버튼
/// 대신 주황 버튼 하나(4955:3673, 상자 기준 x22 y108 264x40)라 따로 둔다.
class _HomeDisconnectedDialog extends StatelessWidget {
  const _HomeDisconnectedDialog({required this.onRetry});

  /// 모달을 닫아도 되면 true.
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return RetryFeedback(
      onRetry: onRetry,
      onSucceeded: () => Navigator.of(context).pop(),
      builder: (context, phase, retry) => _dialog(phase, retry),
    );
  }

  Widget _dialog(RetryPhase phase, VoidCallback retry) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: 308,
        height: 158.829,
        child: Stack(
          children: [
            // 4955:3667: 흰 바탕, 반경 30, 0 0 5.366 rgba(0,0,0,.15).
            DecoratedBox(
              decoration: BoxDecoration(
                color: kBackgroundWhite,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Color(0x26000000), blurRadius: 5.366),
                ],
              ),
              child: const SizedBox.expand(),
            ),
            // 4955:3668: Paperlogy Regular 16 검정, 상자 위에서 40.
            const Positioned(
              left: 0,
              right: 0,
              top: 40,
              height: 23,
              child: Center(
                child: Text(
                  '리피와 연결이 끊겼어요',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 23 / 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            // 4955:3672: Regular 12 제일연한회색, 상자 위에서 68.
            Positioned(
              left: 0,
              right: 0,
              top: 68,
              height: 14,
              child: Center(
                child: Text(
                  phase == RetryPhase.failed
                      ? kRetryFailedMessage
                      : '인터넷 연결을 확인하고 다시 시도해주세요.',
                  style: kCaptionStyle.copyWith(
                    color: kGrayLightest,
                    height: 1,
                  ),
                ),
              ),
            ),
            // 4955:3673: 오렌지_메인, 반경 50, 0 0 2 rgba(0,0,0,.18),
            // 글자는 Medium 16 진한 텍스트(#444)라 흰 글자 기본값을 바꾼다.
            Positioned(
              left: 22,
              top: 108,
              child: PrimaryButton(
                key: const ValueKey('home-disconnected-retry'),
                label: phase == RetryPhase.busy ? kRetryBusyLabel : '다시 시도',
                width: 264,
                height: 40,
                variant: PrimaryButtonVariant.enabled,
                textStyle: kButtonStyle.copyWith(color: kTextDark),
                onPressed: retry,
              ),
            ),
          ],
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
    final bubble = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kBackgroundWhite,
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
    // 시안은 노드 투명도라 배경만이 아니라 글자·그림자까지 함께 옅어진다.
    // 배경 알파만 낮추면 그림자가 비쳐 회색 말풍선처럼 보였다.
    return opacity == 1 ? bubble : Opacity(opacity: opacity, child: bubble);
  }
}

/// 돌봄 토스트(시안 4534:9220 "햇빛을 줬어요!" / 4534:11479 "물을 줬어요!").
/// 흰 pill(높이 27, radius 26.245, 그림자 0 0 2.5 10%) + 왼쪽 오렌지 원
/// (x11 지름 13.83)·흰 V 표시 + 라벨(x29.83).
class _CareToast extends StatelessWidget {
  const _CareToast({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 27,
      padding: const EdgeInsets.only(left: 11, right: 12),
      decoration: BoxDecoration(
        color: kBackgroundWhite,
        borderRadius: BorderRadius.circular(26.245),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 2.5)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // toast_check.svg는 오렌지 원만 있어 시안 V 표시(4534:11486,
          // toast_check_mark.svg)를 그 위에 얹는다. V는 선 굵기만큼 바깥
          // 여백이 있는 SVG라 원 기준 (3.178, 4.578)에 7.446×5.250으로 놓는다.
          SizedBox.square(
            dimension: 13.8276,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  'assets/images/toast_check.svg',
                  width: 13.8276,
                  height: 13.8276,
                  fit: BoxFit.fill,
                ),
                Positioned(
                  left: 3.178,
                  top: 4.578,
                  width: 7.44571,
                  height: 5.24973,
                  child: SvgPicture.asset(
                    'assets/images/toast_check_mark.svg',
                    fit: BoxFit.fill,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
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

/// 시안 붓는 프레임(4534:11397) 물뿌리개의 기울기(34.48°)와 확대 배율
/// (113.804 / 83.98). 돌려 감싼 상자 145.79×140.11에서 역산했다.
const double _kWateringPourAngle = 34.48 * math.pi / 180;
const double _kWateringPourScale = 113.804 / 83.98;

/// 홈 캐릭터 자리를 몸통 박스 위로 넓히는 높이. 어떤 머리를 얹어도 다 들어가도록
/// 모든 머리 중 가장 높이 넘치는 값으로 잡아, 방을 옮겨도 자리 크기가 같다.
final double _kCharacterHairRoom = PlantCharacterArt.maxHairOverflow(173.02);

/// 홈 캐릭터의 터치 영역. 위 [_kCharacterHairRoom] 자리에 머리 그림을 감싼
/// 다각형을, 그 아래에 몸통 박스(예전 터치 영역 그대로)를 둔다. 둘 다 아니면
/// 터치가 뒤로 통과한다. [child]는 몸통 박스 자리에 그린다.
class _CharacterHitArea extends StatelessWidget {
  const _CharacterHitArea({required this.hairPath, required this.child});

  /// 몸통 박스 좌표의 머리 터치 영역([PlantCharacterArt.hairHitPath]).
  final Path? hairPath;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hair = hairPath;
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: _kCharacterHairRoom),
          child: Stack(
            children: [
              const Positioned.fill(
                child: Listener(behavior: HitTestBehavior.opaque),
              ),
              child,
            ],
          ),
        ),
        if (hair != null)
          // ClipPath는 다각형 밖 터치를 받지 않는다.
          Positioned.fill(
            child: ClipPath(
              clipper: _PathClipper(
                hair.shift(Offset(0, _kCharacterHairRoom)),
              ),
              child: const Listener(behavior: HitTestBehavior.opaque),
            ),
          ),
      ],
    );
  }
}

class _PathClipper extends CustomClipper<Path> {
  const _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper oldClipper) => oldClipper.path != path;
}

/// 시안 물줄기 본체(Vector 1537) PNG(home_water_stream.png)의 크기. 시안이
/// 내보낸 SVG(viewBox 122.778×241.418)를 3배로 렌더한 것이라, 오버레이
/// 페인터도 이 좌표계를 그대로 쓴다.
const double _kWaterStreamWidth = 122.778;
const double _kWaterStreamHeight = 241.418;

/// 물줄기 박스의 시안 절대좌표. 시안 Vector 1537은 (142.68, 198)에 있고 박스
/// 안에서 경로 앞에 (3.80, 3.80) 여백이 있어 박스는 그만큼 위·왼쪽이다.
/// 예전 (156, 196)은 물줄기가 16pt 오른쪽으로 밀려 주둥이 뒤에서 나왔다.
const double _kWaterStreamLeft = 138.875;
const double _kWaterStreamTop = 194.2;

/// 애니메이션이 꺼져 있을 때 오버레이를 멈춰 그릴 시점.
const double _kWaterStillPour = 0.3;

/// 물줄기 본체 위에 얹어 물이 흘러내리게 하는 오버레이(시안 5038:6698의
/// 흩날림 5055:181과 Ellipse 1022~1034를 움직이게 한 것).
///
/// 시안 물줄기는 주둥이(오른쪽 위)에서 왼쪽으로 휘어 나간 뒤 아래로 떨어진다.
/// 본체 경로의 바깥 가장자리(왼쪽 위 곡선)와 안쪽 가장자리(오른쪽 곡선)를 길이
/// 비율 s(0=주둥이, 1=끝)로 맞대고, 그 사이를 x(0=바깥, 1=안쪽)로 보간한 자리에
/// 흰 선·물방울·반짝점을 둔다. 각자 `(pour*speed + offset) % 1`로 s를 돌려
/// 주둥이에서 나와 곡선을 따라 흘러내린다.
///
/// 예전에는 시안 흩날림 SVG를 통째로 세로로 흘렸다. 곡선을 따라가지 못해
/// 흰 선이 물줄기 위 허공에서 내려왔다(10/31 피드백).
class _WaterFlowPainter extends CustomPainter {
  _WaterFlowPainter({required this.pour});

  /// 붓는 구간(0.2~0.85) 진행도(0~1). 흐름의 시간축.
  final double pour;

  /// 시안 물방울 색. 위쪽은 진하고(#99E2EF), 떨어질수록 옅다(#C0F1FA).
  static const Color _dropDeep = Color(0xFF99E2EF);
  static const Color _dropLight = Color(0xFFC0F1FA);

  /// 본체 그라디언트는 y≈164에서 완전히 투명해진다. 시안 물방울은 그보다
  /// 조금 아래(y≈176)까지 떨어지므로 그 사이에서 지운다.
  static const double _fadeStartY = 140;
  static const double _fadeEndY = 180;

  /// 주둥이에서 막 나온 구간(s). 여기서 서서히 나타나 입구에서 나오게 보인다.
  static const double _emerge = 0.06;

  /// 흰 선 8개(시안 Vector 1538~1545). 길이는 시안처럼 25~45px.
  static const List<_FlowStreak> _streaks = [
    _FlowStreak(x: 0.30, speed: 2.2, offset: 0.00, length: 0.16),
    _FlowStreak(x: 0.55, speed: 2.5, offset: 0.40, length: 0.12),
    _FlowStreak(x: 0.42, speed: 2.0, offset: 0.65, length: 0.18),
    _FlowStreak(x: 0.70, speed: 2.4, offset: 0.20, length: 0.13),
    _FlowStreak(x: 0.20, speed: 2.6, offset: 0.85, length: 0.11),
    _FlowStreak(x: 0.62, speed: 2.1, offset: 0.55, length: 0.16),
    _FlowStreak(x: 0.36, speed: 2.3, offset: 0.30, length: 0.13),
    _FlowStreak(x: 0.80, speed: 2.5, offset: 0.75, length: 0.11),
  ];

  /// 눈물방울 12개(시안 Vector 1045·1546~1553). 폭은 시안처럼 5~10px. 아래쪽
  /// 끝에서 사라지는 동안을 빼면 한 번에 9개 안팎이 보여 시안 수와 맞는다.
  static const List<_FlowDrop> _drops = [
    _FlowDrop(x: 0.45, speed: 1.8, offset: 0.00, width: 9.5),
    _FlowDrop(x: 0.20, speed: 2.1, offset: 0.17, width: 6.5),
    _FlowDrop(x: 0.70, speed: 1.7, offset: 0.34, width: 8.0),
    _FlowDrop(x: 0.32, speed: 2.3, offset: 0.52, width: 5.5),
    _FlowDrop(x: 0.58, speed: 1.9, offset: 0.70, width: 10.0),
    _FlowDrop(x: 0.82, speed: 2.2, offset: 0.09, width: 6.0),
    _FlowDrop(x: 0.26, speed: 1.6, offset: 0.26, width: 9.0),
    _FlowDrop(x: 0.64, speed: 2.4, offset: 0.44, width: 5.5),
    _FlowDrop(x: 0.12, speed: 2.0, offset: 0.61, width: 7.0),
    _FlowDrop(x: 0.40, speed: 2.2, offset: 0.79, width: 6.5),
    _FlowDrop(x: 0.52, speed: 1.8, offset: 0.13, width: 8.5),
    _FlowDrop(x: 0.75, speed: 2.0, offset: 0.88, width: 6.0),
  ];

  /// 흰 반짝점 10개(시안 Ellipse 1022~1034). x가 0~1 밖이면 가장자리 밖으로
  /// 튄다.
  static const List<_FlowSparkle> _sparkles = [
    _FlowSparkle(x: 0.34, speed: 1.1, offset: 0.04, radius: 1.3),
    _FlowSparkle(x: -0.12, speed: 0.9, offset: 0.21, radius: 1.0),
    _FlowSparkle(x: 0.70, speed: 1.3, offset: 0.37, radius: 1.5),
    _FlowSparkle(x: 1.15, speed: 1.0, offset: 0.50, radius: 1.1),
    _FlowSparkle(x: 0.48, speed: 1.2, offset: 0.63, radius: 0.9),
    _FlowSparkle(x: 0.20, speed: 0.8, offset: 0.76, radius: 1.4),
    _FlowSparkle(x: 0.88, speed: 1.1, offset: 0.12, radius: 1.2),
    _FlowSparkle(x: -0.08, speed: 1.4, offset: 0.45, radius: 0.8),
    _FlowSparkle(x: 0.60, speed: 0.9, offset: 0.88, radius: 1.3),
    _FlowSparkle(x: 1.10, speed: 1.2, offset: 0.29, radius: 1.0),
  ];

  /// 가장자리를 길이 기준으로 고르게 나눈 점 개수.
  static const int _samples = 64;

  /// 바깥 가장자리: 주둥이 위 → 왼쪽으로 휘어 → 왼쪽 아래 끝. 시안 경로의
  /// cubic 두 개를 주둥이 쪽에서부터 이었다.
  static final List<Offset> _outer = _sampleEdge(const [
    [
      Offset(83.4833, 3.8003),
      Offset(74.9936, 4.0148),
      Offset(53.3991, 4.0671),
      Offset(28.1245, 41.2637),
    ],
    [
      Offset(28.1245, 41.2637),
      Offset(-7.1298, 93.1474),
      Offset(4.1098, 212.165),
      Offset(11.7985, 236.987),
    ],
  ]);

  /// 안쪽 가장자리: 주둥이 아래 → 오른쪽 아래 끝.
  static final List<Offset> _inner = _sampleEdge(const [
    [
      Offset(82.502, 24.4589),
      Offset(75.5481, 35.6265),
      Offset(67.0672, 66.4276),
      Offset(70.1246, 94.2637),
    ],
    [
      Offset(70.1246, 94.2637),
      Offset(73.0823, 121.192),
      Offset(106.061, 200.53),
      Offset(118.713, 215.312),
    ],
  ]);

  static List<Offset> _sampleEdge(List<List<Offset>> cubics) {
    const steps = 40;
    final dense = <Offset>[];
    for (final c in cubics) {
      for (var i = dense.isEmpty ? 0 : 1; i <= steps; i++) {
        final t = i / steps;
        final u = 1 - t;
        dense.add(
          c[0] * (u * u * u) +
              c[1] * (3 * u * u * t) +
              c[2] * (3 * u * t * t) +
              c[3] * (t * t * t),
        );
      }
    }
    final lengths = <double>[0];
    for (var i = 1; i < dense.length; i++) {
      lengths.add(lengths.last + (dense[i] - dense[i - 1]).distance);
    }
    final out = <Offset>[];
    var j = 0;
    for (var k = 0; k <= _samples; k++) {
      final target = lengths.last * k / _samples;
      while (j < lengths.length - 2 && lengths[j + 1] < target) {
        j++;
      }
      final segment = lengths[j + 1] - lengths[j];
      final f = segment == 0 ? 0.0 : (target - lengths[j]) / segment;
      out.add(Offset.lerp(dense[j], dense[j + 1], f)!);
    }
    return out;
  }

  static Offset _edgeAt(List<Offset> edge, double s) {
    final p = s.clamp(0.0, 1.0) * _samples;
    final i = p.floor().clamp(0, _samples - 1);
    return Offset.lerp(edge[i], edge[i + 1], p - i)!;
  }

  /// 물줄기 안 (s, x) 자리. x가 0~1 밖이면 가장자리 바깥이다.
  static Offset _at(double s, double x) =>
      Offset.lerp(_edgeAt(_outer, s), _edgeAt(_inner, s), x)!;

  /// 주둥이에서 나타나고, 본체가 투명해지는 아래쪽에서 사라진다.
  static double _alphaAt(double s, Offset p) {
    final emerge = (s / _emerge).clamp(0.0, 1.0);
    final fall =
        ((p.dy - _fadeStartY) / (_fadeEndY - _fadeStartY)).clamp(0.0, 1.0);
    return emerge * (1 - fall);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pour <= 0) return;
    canvas.save();
    canvas.scale(
      size.width / _kWaterStreamWidth,
      size.height / _kWaterStreamHeight,
    );
    _paintStreaks(canvas);
    _paintSparkles(canvas);
    _paintDrops(canvas);
    canvas.restore();
  }

  /// 흰 선은 머리(s)에서 꼬리(s - length)까지 물줄기 곡선을 따라 긋는다.
  /// 꼬리까지 주둥이를 빠져나가도록 머리는 0 ~ 1+length를 돈다.
  void _paintStreaks(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (final streak in _streaks) {
      final head =
          ((pour * streak.speed + streak.offset) % 1.0) * (1 + streak.length);
      final tail = math.max(0.0, head - streak.length);
      final end = math.min(1.0, head);
      if (end <= tail) continue;
      final mid = _at((tail + end) / 2, streak.x);
      final alpha = _alphaAt(end, mid);
      if (alpha <= 0) continue;
      final path = Path();
      const segments = 8;
      for (var i = 0; i <= segments; i++) {
        final p = _at(tail + (end - tail) * i / segments, streak.x);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      // 시안 흰 선은 흰색 50%다.
      paint.color = Colors.white.withValues(alpha: 0.5 * alpha);
      canvas.drawPath(path, paint);
    }
  }

  /// 위가 뾰족하고 아래가 둥근 눈물방울 path(시안 물방울 모양).
  static Path _teardrop(Offset center, double width) {
    final r = width / 2;
    // 전체 높이는 폭의 약 1.8배. 꼭짓점은 중심보다 위, 둥근 배는 아래.
    final apex = center.dy - r * 1.7;
    final belly = center.dy + r * 0.35;
    final bottom = center.dy + r * 1.1;
    return Path()
      ..moveTo(center.dx, apex)
      ..quadraticBezierTo(
        center.dx + r * 0.62,
        center.dy - r * 0.5,
        center.dx + r,
        belly,
      )
      ..quadraticBezierTo(center.dx + r, bottom, center.dx, bottom)
      ..quadraticBezierTo(center.dx - r, bottom, center.dx - r, belly)
      ..quadraticBezierTo(
        center.dx - r * 0.62,
        center.dy - r * 0.5,
        center.dx,
        apex,
      )
      ..close();
  }

  void _paintDrops(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final drop in _drops) {
      final s = (pour * drop.speed + drop.offset) % 1.0;
      final center = _at(s, drop.x);
      final alpha = _alphaAt(s, center);
      if (alpha <= 0) continue;
      final depth = ((center.dy - 40) / 100).clamp(0.0, 1.0);
      // 불투명하게 칠한다. 본체가 반투명이라 알파를 낮추면 뒤 배경색이
      // 배어들어 시안의 또렷한 하늘색 물방울이 탁해진다.
      paint.color = Color.lerp(
        _dropDeep,
        _dropLight,
        depth,
      )!.withValues(alpha: alpha);
      canvas.drawPath(_teardrop(center, drop.width), paint);
    }
  }

  void _paintSparkles(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final sparkle in _sparkles) {
      final s = (pour * sparkle.speed + sparkle.offset) % 1.0;
      final center = _at(s, sparkle.x);
      final alpha = _alphaAt(s, center);
      if (alpha <= 0) continue;
      // 각자 다른 주기로 미세하게 깜빡인다.
      final twinkle =
          0.8 + 0.2 * math.sin((pour * 6 + sparkle.offset * 7) * math.pi);
      paint.color = Colors.white.withValues(
        alpha: (twinkle * alpha).clamp(0.0, 1.0),
      );
      canvas.drawCircle(center, sparkle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_WaterFlowPainter oldDelegate) => oldDelegate.pour != pour;
}

/// 물줄기를 따라 흐르는 흰 선 한 개의 정의.
class _FlowStreak {
  const _FlowStreak({
    required this.x,
    required this.speed,
    required this.offset,
    required this.length,
  });

  /// 물줄기 폭 대비 위치(0=바깥 가장자리, 1=안쪽 가장자리).
  final double x;

  /// 한 번 붓는 동안 주둥이→끝을 도는 횟수.
  final double speed;

  /// 시작 위상(0~1).
  final double offset;

  /// 선 길이(물줄기 길이 대비 s).
  final double length;
}

/// 흐르는 눈물방울 한 개의 정의.
class _FlowDrop {
  const _FlowDrop({
    required this.x,
    required this.speed,
    required this.offset,
    required this.width,
  });

  /// 물줄기 폭 대비 위치(0=바깥 가장자리, 1=안쪽 가장자리).
  final double x;

  /// 한 번 붓는 동안 주둥이→끝을 도는 횟수.
  final double speed;

  /// 시작 위상(0~1). 물방울마다 달라 흩어져 흐른다.
  final double offset;

  /// 눈물방울 폭(본체 좌표계 px).
  final double width;
}

/// 흩뿌려진 작은 흰 반짝점 한 개의 정의.
class _FlowSparkle {
  const _FlowSparkle({
    required this.x,
    required this.speed,
    required this.offset,
    required this.radius,
  });

  /// 물줄기 폭 대비 위치. 0~1 밖이면 가장자리 바깥이다.
  final double x;

  /// 한 번 붓는 동안 주둥이→끝을 도는 횟수(물방울보다 느리다).
  final double speed;

  /// 시작 위상(0~1).
  final double offset;

  /// 반짝점 반지름(본체 좌표계 px).
  final double radius;
}
