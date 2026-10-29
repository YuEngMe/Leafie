import 'package:flutter/material.dart';

/// 화면 왼쪽 끝을 오른쪽으로 밀면 뒤로 간다(디자이너 답 13-B).
///
/// iOS 기본 밀어서 뒤로 가기는 PopScope로 뒤로 가기를 막아 둔 화면(나가기 전
/// 저장·확인)과 하단 탭(돌아갈 화면이 없음)에서는 동작하지 않는다. 그런 곳에
/// 감싸서, 밀면 [onSwipe]를 부른다. [onSwipe]가 없으면 `Navigator.maybePop`을
/// 불러 화면의 PopScope가 원래 하던 일(저장 후 닫기, 확인 창)을 그대로 한다.
class EdgeSwipeBack extends StatefulWidget {
  const EdgeSwipeBack({
    super.key,
    required this.child,
    this.onSwipe,
    this.enabled = true,
  });

  /// iOS가 밀어서 뒤로 가기를 받는 왼쪽 끝 폭과 같다.
  static const double edgeWidth = 20;

  /// 이만큼 밀었거나 이 속도(px/s) 이상으로 튕기면 뒤로 간다.
  static const double minDistance = 60;
  static const double minVelocity = 300;

  final Widget child;
  final VoidCallback? onSwipe;
  final bool enabled;

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack> {
  double _dragged = 0;

  void _end(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final swiped =
        _dragged >= EdgeSwipeBack.minDistance ||
        (_dragged > 0 && velocity >= EdgeSwipeBack.minVelocity);
    _dragged = 0;
    if (!swiped) return;
    final onSwipe = widget.onSwipe;
    if (onSwipe != null) {
      onSwipe();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 꺼져 있어도 Stack은 남긴다. 켜고 끌 때 구조가 바뀌면 child가 새로
    // 만들어져 탭 상태(스크롤, 입력)가 사라진다.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        // 탭은 아래 화면(뒤로 꺾쇠 등)으로 그대로 넘긴다.
        if (widget.enabled)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: EdgeSwipeBack.edgeWidth,
            child: GestureDetector(
              key: const ValueKey('edge-swipe-back'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => _dragged = 0,
              onHorizontalDragUpdate: (details) =>
                  _dragged += details.primaryDelta ?? 0,
              onHorizontalDragEnd: _end,
              onHorizontalDragCancel: () => _dragged = 0,
            ),
          ),
      ],
    );
  }
}
