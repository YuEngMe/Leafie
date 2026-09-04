import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/screens/my_page_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

/// 등록한 식물. dio가 붙기 전까지는 등록 화면이 user_metadata에 넣어 둔
/// 값을 읽는다(plant_register_complete_screen.dart).
class HomePlant {
  const HomePlant({
    required this.name,
    required this.startedOn,
    required this.personalityType,
  });

  /// 세션에 저장된 등록 결과를 읽는다. 아직 등록 전이면 null.
  static HomePlant? of(User? user) {
    final raw = user?.userMetadata?['leafie_plant'];
    if (raw is! Map) return null;
    final name = raw['name'];
    if (name is! String || name.isEmpty) return null;
    return HomePlant(
      name: name,
      startedOn: DateTime.tryParse(raw['started_on'] as String? ?? ''),
      personalityType:
          (raw['character'] as Map?)?['personality_type'] as String?,
    );
  }

  final String name;
  final DateTime? startedOn;
  final String? personalityType;

  /// 등록한 날이 1일차다(2026-08-04 팀 확인).
  int get dayCount =>
      startedOn == null ? 1 : DateTime.now().difference(startedOn!).inDays + 1;

  /// 성격마다 말투가 다르다. 서버가 대사를 주기 전까지 쓰는 기본 묶음.
  List<String> get moodLines => switch (personalityType) {
    'CHIC' => const ['흠', '별로야', '나쁘지 않네'],
    'CUTE' => const ['히히', '헤헤', '보고 싶었어!'],
    'CRUSH' => const ['가보자고', '오늘도 화이팅', '내가 최고야!'],
    'INTROVERTED' => const ['어..', '조금 부끄러워', '와줘서 고마워'],
    'CHUNGCHEONG' => const ['음~', '천천히 하자', '좋은 하루여~'],
    // OUTGOING이 기본값이고, 성격을 못 고른 경우도 여기로 온다.
    _ => const ['히히', '신난다', '좋은 하루야!'],
  };
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.plant, this.signOut});

  /// 비워 두면 현재 세션에서 읽는다. 테스트에서만 직접 넘긴다.
  final HomePlant? plant;
  final Future<void> Function()? signOut;

  /// Supabase를 초기화하지 않은 위젯 테스트에서도 화면은 떠야 한다.
  static User? _currentUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _requestSignOut(BuildContext context) async {
    try {
      await (signOut ?? Supabase.instance.client.auth.signOut)();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그아웃에 실패했어요. 다시 시도해주세요.')));
    }
  }

  void _startPlantRegistration(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlantRegisterNameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final plant = this.plant ?? HomePlant.of(_currentUser());
    // 아직 등록하지 않았으면 이름 대신 안내를 띄운다.
    final roomName = plant?.name ?? '새싹이';
    final moodLines = plant?.moodLines ?? const ['히히', '신난다', '좋은 하루야!'];

    return Scaffold(
      backgroundColor: kHomeGreen,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _RoomBackgroundPainter()),
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: AppLayout.homeTopBarHeight,
                  child: Row(
                    children: [
                      const SizedBox(width: 38),
                      Text(
                        'D+ ${plant?.dayCount ?? 1}',
                        style: kCaptionStyle.copyWith(color: kTextDark),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_left, color: kTextDark),
                      Text('$roomName 방', style: kItemStyle),
                      const Icon(Icons.chevron_right, color: kTextDark),
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: '알림 및 메뉴',
                        onSelected: (value) {
                          if (value == 'register') {
                            _startPlantRegistration(context);
                          } else if (value == 'sign_out') {
                            _requestSignOut(context);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'register',
                            child: Text('식물 등록하기'),
                          ),
                          PopupMenuItem(value: 'sign_out', child: Text('로그아웃')),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 14,
                          ),
                          child: Text('알림', style: kCaptionStyle),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: const [
                          _SideControl(label: '전체\n보기'),
                          SizedBox(height: 10),
                          _SideControl(label: '유채통'),
                        ],
                      ),
                      const Spacer(),
                      const _SideControl(label: '청진기'),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(28, -14),
                  child: Column(
                    children: [
                      _RoomBubble(label: moodLines[0], width: 103),
                      Transform.translate(
                        offset: Offset(19, -7),
                        child: _RoomBubble(label: moodLines[1], width: 103),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _RoomBubble(label: moodLines[2], width: 114),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // Figma node 2346:2542. 배경은 흰색 30%다.
                      color: const Color(0x4DFFFFFF),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 4),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(35),
                      onTap: () => _startPlantRegistration(context),
                      child: SizedBox(
                        height: AppLayout.homeHumidityCardHeight,
                        child: Row(
                          children: [
                            const SizedBox(width: 11),
                            const FigmaMoistureIcon(),
                            const SizedBox(width: 10.57),
                            Text('조도 습도 체크하기', style: kItemStyle),
                            const Spacer(),
                            const SizedBox(width: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: AppLayout.homeBottomNavHeight,
                  // Figma node 3173:113. 디자이너가 2026-09-05에 아이콘을
                  // 넣으면서 알약 배경과 글자 라벨을 걷어냈다.
                  decoration: const BoxDecoration(
                    color: kBackgroundWhite,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x33000000), blurRadius: 5),
                    ],
                  ),
                  // 아이콘 간격이 101 / 101.5 / 96.5로 고르지 않아 균등
                  // 배치 대신 시안 x를 그대로 쓴다.
                  child: Stack(
                    children: [
                      const _NavItem(
                        icon: FigmaNavIcon.home,
                        left: 35,
                        top: 22,
                      ),
                      const _NavItem(
                        icon: FigmaNavIcon.diary,
                        left: 139,
                        top: 24,
                      ),
                      const _NavItem(
                        icon: FigmaNavIcon.calendar,
                        left: 240,
                        top: 22,
                      ),
                      _NavItem(
                        icon: FigmaNavIcon.my,
                        left: 338,
                        top: 25,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyPageScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomBubble extends StatelessWidget {
  const _RoomBubble({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      // Figma node 2346:2375.
      height: 38,
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
        style: kSmallStyle.copyWith(fontSize: 13.353, color: kTextDark),
      ),
    );
  }
}

class _SideControl extends StatelessWidget {
  const _SideControl({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 3)],
      ),
      child: Text(label, style: kCaptionStyle, textAlign: TextAlign.center),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.left,
    required this.top,
    this.onTap,
  });

  final FigmaNavIcon icon;
  final double left;
  final double top;

  /// 아직 화면이 없는 탭은 null로 둔다.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // 아이콘이 29~37px이라 그대로 두면 탭 영역이 손가락보다 작다.
    // 시안 좌표는 유지한 채 눌리는 범위만 48로 넓힌다.
    const minTarget = 48.0;
    final padX = (minTarget - icon.figmaSize.width) / 2;
    final padY = (minTarget - icon.figmaSize.height) / 2;
    return Positioned(
      left: left - padX,
      top: top - padY,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padX, vertical: padY),
          child: FigmaBottomNavIcon(icon),
        ),
      ),
    );
  }
}

class _RoomBackgroundPainter extends CustomPainter {
  const _RoomBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [kHomeGreen, kHomeYellow, kHomePeach],
        stops: [0, 0.58, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final yellowBand = Paint()
      ..color = const Color(0x99FFF7B8)
      ..strokeWidth = 112
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    canvas.drawLine(
      Offset(-80, size.height * 0.31),
      Offset(size.width + 70, size.height * 0.04),
      yellowBand,
    );

    final greenBand = Paint()
      ..color = const Color(0x85A9EEA9)
      ..strokeWidth = 138
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38);
    canvas.drawLine(
      Offset(-70, size.height * 0.5),
      Offset(size.width + 70, size.height * 0.2),
      greenBand,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
