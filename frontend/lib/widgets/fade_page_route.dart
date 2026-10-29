import 'package:flutter/widgets.dart';
import 'package:yeso_plant/theme/app_motion.dart';

/// 스택을 통째로 갈아 끼우는 화면 전환(스플래시 → 로그인, 로그인 → 홈,
/// 등록 완료 → 홈 등).
///
/// iOS 기본 slide는 "한 단계 더 들어간다"는 뜻이라 돌아갈 화면이 없는 root
/// 교체와 맞지 않는다. M3 Top level처럼 새 화면이 이전 화면 위로 서서히
/// 나타나고, 이전 화면은 움직이지 않는다.
///
/// 이 화면 위로 일반 [MaterialPageRoute]를 올릴 때 아래 화면이 왼쪽으로
/// 밀리는 iOS parallax는 Flutter의 delegatedTransition이 그대로 붙여 준다.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: AppMotion.pageFade,
        reverseTransitionDuration: AppMotion.pageFade,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) =>
            MediaQuery.disableAnimationsOf(context)
            ? child
            : FadeTransition(
                opacity: animation.drive(
                  CurveTween(curve: AppMotion.pageFadeCurve),
                ),
                child: child,
              ),
      );
}
