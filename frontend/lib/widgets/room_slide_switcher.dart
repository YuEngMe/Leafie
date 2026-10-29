import 'package:flutter/material.dart';

/// 홈에서 < > 로 방을 옮길 때 지금 내용은 [direction] 반대쪽으로 밀려 나가고
/// 새 내용이 [direction] 쪽에서 들어오게 한다(디자이너 답 5-A).
///
/// [child]의 key가 바뀔 때만 움직인다. [direction]이 0이거나 동작 줄이기가
/// 켜져 있으면 이전 내용을 바로 숨긴다. [distance]는 child 폭을 1로 한 이동 거리다.
class RoomSlideSwitcher extends StatelessWidget {
  const RoomSlideSwitcher({
    super.key,
    required this.direction,
    required this.distance,
    required this.child,
  });

  static const Duration duration = Duration(milliseconds: 350);

  final int direction;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animate = direction != 0 && !MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      // 길이는 고정한다. AnimatedSwitcher는 child마다 처음 들어올 때의 길이로
      // 나갈 때도 움직여서, 0으로 들어온 첫 캐릭터는 밀려 나가지 못하고
      // 바로 사라졌다.
      duration: duration,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      // 기본 레이아웃은 가운데 정렬 Stack이라 자기 크기 밖을 잘라 버린다.
      layoutBuilder: (current, previous) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == this.child.key;
        // 움직이지 않을 때는 새 내용만 보이고 이전 내용은 바로 숨긴다.
        if (!animate) return incoming ? child : const SizedBox.shrink();
        // 들어오는 쪽은 0→1, 나가는 쪽은 1→0으로 돌므로 시작점만 반대로 둔다.
        final from = (incoming ? direction : -direction) * distance;
        return SlideTransition(
          position: Tween(
            begin: Offset(from, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
      child: child,
    );
  }
}
