import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

/// Figma 3628:2412의 기본 variant 3628:2411. 홈·다이어리·캘린더가 함께 쓴다.
///
/// 시안은 알약 배경도 글자 라벨도 없이 아이콘 넷만 놓는다. 아이콘 중심
/// 간격이 101 / 101.5 / 96.5로 고르지 않아 균등 배치 대신 시안 x를 쓴다.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, this.onTap, this.activeIcon});

  /// 눌린 탭을 알려준다. 아직 화면이 없는 탭은 호출부가 무시하면 된다.
  final ValueChanged<FigmaNavIcon>? onTap;

  /// 지금 선택된 탭. 이 아이콘만 진하게(opacity 1) 그리고 나머지는 흐리게
  /// (opacity 0.5) 그려 바에서 활성 탭을 알린다. null이면 넷 다 진하게 둔다
  /// — 라우트로 잠깐 뜨는 캘린더·다이어리 바는 활성 표시 대상이 아니다.
  final FigmaNavIcon? activeIcon;

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
      ),
      child: Stack(
        children: [
          for (final entry in iconOffsets.entries)
            _NavItem(
              icon: entry.key,
              left: entry.value.dx,
              top: entry.value.dy,
              // activeIcon이 null이면 강조를 끄고 넷 다 진하게(active=true).
              active: activeIcon == null || entry.key == activeIcon,
              onTap: onTap == null ? null : () => onTap!(entry.key),
            ),
        ],
      ),
    );
  }
}

/// 아이콘 하나. 활성이면 opacity 1, 비활성이면 0.5로 그리고, 탭하면 눌린
/// 피드백으로 scale 1.0 → 1.15 → 1.0을 200ms 동안 한 번 튕긴다.
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.left,
    required this.top,
    required this.active,
    this.onTap,
  });

  final FigmaNavIcon icon;
  final double left;
  final double top;
  final bool active;
  final VoidCallback? onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  // 1.0 → 1.15 → 1.0. 눌린 순간 살짝 커졌다 제자리로 돌아온다.
  late final Animation<double> _scale = _bounce.drive(
    TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]),
  );

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _handleTap() {
    // 접근성: 모션을 끈 사용자에게는 튕김을 생략한다.
    if (!MediaQuery.disableAnimationsOf(context)) {
      _bounce.forward(from: 0);
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    // 아이콘이 29~37px이라 그대로 두면 탭 영역이 손가락보다 작다.
    // 시안 좌표는 유지한 채 눌리는 범위만 48로 넓힌다.
    const minTarget = 48.0;
    final padX = (minTarget - widget.icon.figmaSize.width) / 2;
    final padY = (minTarget - widget.icon.figmaSize.height) / 2;
    // 정보 전달이라 opacity 강조는 모션을 꺼도 유지하되, 그때는 즉시 반영한다.
    final opacityDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Positioned(
      left: widget.left - padX,
      top: widget.top - padY,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padX, vertical: padY),
          // Transform.scale은 레이아웃을 밀지 않아 시안 좌표를 지킨다.
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedOpacity(
              opacity: widget.active ? 1.0 : 0.5,
              duration: opacityDuration,
              child: FigmaBottomNavIcon(widget.icon),
            ),
          ),
        ),
      ),
    );
  }
}
