import 'package:flutter/widgets.dart';

/// 화면을 좌우로 밀어 이전·다음 기간(달, 주)으로 넘긴다(10/31 피드백).
///
/// 손가락을 왼쪽으로 밀면 다음, 오른쪽으로 밀면 이전이다. 짧게 스친 건
/// 넘기지 않는다. 화면 왼쪽 끝(20px)에서 시작한 드래그는 위에 얹힌
/// [EdgeSwipeBack]이 먼저 받아 홈으로 돌아가므로 여기와 겹치지 않는다.
/// 세로 스크롤과는 방향이 달라 서로 막지 않는다.
class PeriodSwipe extends StatefulWidget {
  const PeriodSwipe({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  /// 이만큼 밀었거나 이 속도(px/s) 이상으로 튕기면 넘긴다.
  static const double minDistance = 60;
  static const double minVelocity = 300;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  @override
  State<PeriodSwipe> createState() => _PeriodSwipeState();
}

class _PeriodSwipeState extends State<PeriodSwipe> {
  double _dragged = 0;

  void _end(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dragged = _dragged;
    _dragged = 0;
    final toNext =
        dragged <= -PeriodSwipe.minDistance ||
        (dragged < 0 && velocity <= -PeriodSwipe.minVelocity);
    final toPrevious =
        dragged >= PeriodSwipe.minDistance ||
        (dragged > 0 && velocity >= PeriodSwipe.minVelocity);
    if (toNext) {
      widget.onNext();
    } else if (toPrevious) {
      widget.onPrevious();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('period-swipe'),
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) => _dragged = 0,
    onHorizontalDragUpdate: (details) => _dragged += details.primaryDelta ?? 0,
    onHorizontalDragEnd: _end,
    onHorizontalDragCancel: () => _dragged = 0,
    child: widget.child,
  );
}
