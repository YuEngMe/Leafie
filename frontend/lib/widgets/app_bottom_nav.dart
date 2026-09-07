import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

/// Figma 컴포넌트 3628:2411의 하단 네비게이션. 홈·다이어리·캘린더가 함께 쓴다.
///
/// 시안은 알약 배경도 글자 라벨도 없이 아이콘 넷만 놓는다. 아이콘 중심
/// 간격이 101 / 101.5 / 96.5로 고르지 않아 균등 배치 대신 시안 x를 쓴다.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, this.onTap});

  /// 눌린 탭을 알려준다. 아직 화면이 없는 탭은 호출부가 무시하면 된다.
  final ValueChanged<FigmaNavIcon>? onTap;

  /// 시안 3628:2139/2123/2130/2144의 좌표. 바 안쪽 기준이다.
  /// 2026-09-07 갱신: 아이콘 네 개가 5px 위로 올라갔다(y 817 → 812).
  static const Map<FigmaNavIcon, Offset> iconOffsets = {
    FigmaNavIcon.home: Offset(35, 17),
    FigmaNavIcon.diary: Offset(139, 19),
    FigmaNavIcon.calendar: Offset(240, 17),
    FigmaNavIcon.my: Offset(338, 20),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppLayout.homeBottomNavHeight,
      decoration: const BoxDecoration(
        color: kBackgroundWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 5)],
      ),
      child: Stack(
        children: [
          for (final entry in iconOffsets.entries)
            _NavItem(
              icon: entry.key,
              left: entry.value.dx,
              top: entry.value.dy,
              onTap: onTap == null ? null : () => onTap!(entry.key),
            ),
        ],
      ),
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
