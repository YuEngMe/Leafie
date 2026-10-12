import 'package:flutter/widgets.dart';

/// iOS '동작 줄이기'를 [MediaQueryData.disableAnimations]로 넘긴다.
///
/// 앱의 애니메이션은 모두 [MediaQuery.disableAnimationsOf]로 멈출지 정한다.
/// 그런데 iOS의 동작 줄이기는 엔진이 `disableAnimations`가 아니라 iOS 전용
/// `AccessibilityFeatures.reduceMotion`으로 올려 보내고, MediaQuery는 그 값을
/// 읽지 않는다. 그래서 설정을 켜도 캐릭터가 계속 뛰었다. 앱 루트에서 두 값을
/// 합쳐, 화면마다 따로 확인하지 않아도 같은 판단이 적용되게 한다.
class PlatformReduceMotion extends StatefulWidget {
  const PlatformReduceMotion({super.key, required this.child});

  final Widget child;

  @override
  State<PlatformReduceMotion> createState() => _PlatformReduceMotionState();
}

class _PlatformReduceMotionState extends State<PlatformReduceMotion>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // MediaQueryData에 reduceMotion이 없어 이 값만 바뀌면 MediaQuery가 다시
  // 알려 주지 않는다. 앱이 떠 있는 동안 설정을 바꿔도 따라가게 직접 듣는다.
  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = View.of(
      context,
    ).platformDispatcher.accessibilityFeatures.reduceMotion;
    // 설정을 바꿔도 아래 화면 상태가 날아가지 않게 트리 모양은 그대로 둔다.
    return MediaQuery(
      data: media.copyWith(
        disableAnimations: media.disableAnimations || reduceMotion,
      ),
      child: widget.child,
    );
  }
}
