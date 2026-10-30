import 'package:flutter/widgets.dart';

/// 전환 모션 없이 한 번에 뜨고 한 번에 닫히는 화면 전환(알림센터 등).
///
/// iOS 기본 slide는 화면이 옆에서 밀려 들어와, 홈 위에 잠깐 열어 보는
/// 화면에는 느리게 느껴졌다(10/31 피드백: "슬라이드 대신 빡"). 화면이 바로
/// 바뀌므로 왼쪽 끝을 밀어 닫는 iOS 뒤로 가기 제스처는 없다. 앱바 뒤로
/// 가기로 닫는다.
class InstantPageRoute<T> extends PageRouteBuilder<T> {
  InstantPageRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => builder(context),
      );
}
