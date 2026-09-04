import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/screens/my_page_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.plantName, this.signOut});

  final String? plantName;
  final Future<void> Function()? signOut;

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
    final roomName = plantName ?? '새싹이';

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
                        'D+ 1281',
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
                      _RoomBubble(label: '히히', width: 103),
                      Transform.translate(
                        offset: Offset(19, -7),
                        child: _RoomBubble(label: '신난다', width: 103),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const _RoomBubble(label: '좋은 하루야!', width: 114),
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
