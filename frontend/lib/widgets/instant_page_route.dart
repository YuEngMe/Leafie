import 'package:flutter/widgets.dart';
import 'package:yeso_plant/widgets/edge_swipe_back.dart';

/// 전환 모션 없이 한 번에 뜨고 한 번에 닫히는 화면 전환(알림센터 등).
///
/// iOS 기본 slide는 화면이 옆에서 밀려 들어와, 홈 위에 잠깐 열어 보는
/// 화면에는 느리게 느껴졌다(10/31 피드백: "슬라이드 대신 빡"). 이 전환에는
/// iOS 기본 밀어서 뒤로 가기가 붙지 않아, 왼쪽 끝을 밀면 닫히도록
/// [EdgeSwipeBack]을 씌운다(10/31 피드백: 캐릭터 전체보기에서 안 됨).
class InstantPageRoute<T> extends PageRouteBuilder<T> {
  InstantPageRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => EdgeSwipeBack(child: builder(context)),
      );
}
