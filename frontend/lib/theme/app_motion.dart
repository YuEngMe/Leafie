import 'package:flutter/animation.dart';

/// 앱 공통 모션 값. 새 애니메이션은 여기 값을 쓴다.
///
/// Flutter 기본 커브(Curves.easeOut 등)는 약해서 움직임이 흐릿하다. 아래 커브는
/// emilkowalski/skills의 animation 기준값을 옮긴 것이다. 시안(Figma)에는 모션
/// 값이 없어 이 값들이 앱의 기준이다.
abstract final class AppMotion {
  /// 들어오고 나가는 UI, 누름 피드백. 빨리 출발해 부드럽게 멈춘다.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// 화면 안에서 자리를 옮기는 물체. 천천히 출발하고 천천히 멈춘다.
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// 투명도·색만 바뀌는 전환. 급하게 튀지 않고 고르게 스며든다(CSS ease).
  static const Curve ease = Cubic(0.25, 0.1, 0.25, 1);

  /// 버튼·아이콘을 눌렀을 때 줄어들었다 돌아오는 시간(권장 100~160ms).
  static const Duration press = Duration(milliseconds: 120);

  /// 누르는 동안 줄어드는 비율(권장 0.95~0.98).
  static const double pressScale = 0.95;

  /// 스택을 갈아 끼우는 화면 전환([FadePageRoute])의 길이. 화면 전환은 M3
  /// 기준을 따르기로 해 M3 duration medium2 값을 쓴다.
  static const Duration pageFade = Duration(milliseconds: 300);

  /// 홈 배경이 시간대·조도에 따라 바뀔 때 새 배경이 서서히 드러나는 시간.
  /// 하늘색이 바뀌는 느낌이라 화면 전환보다 길게 둔다(시안에 값 없음).
  static const Duration periodCrossfade = Duration(milliseconds: 1200);

  /// 위 전환의 커브. M3 emphasized decelerate: 새 화면이 빨리 드러나고 천천히
  /// 자리 잡는다.
  static const Curve pageFadeCurve = Cubic(0.05, 0.7, 0.1, 1);

  /// 화면 위에 떠 있는 카드가 나타나는 시간(M3 short4). 커브는
  /// [pageFadeCurve]를 같이 쓴다.
  static const Duration overlayEnter = Duration(milliseconds: 200);

  /// 위 카드가 사라지는 시간(M3 short2). 나가는 건 들어오는 것보다 짧게 둔다.
  static const Duration overlayExit = Duration(milliseconds: 100);

  /// 위 카드가 사라질 때 커브. M3 emphasized accelerate: 천천히 출발해 빨리
  /// 빠진다.
  static const Curve overlayExitCurve = Cubic(0.3, 0, 0.8, 0.15);

  /// 위 카드가 나타나기 시작할 때 크기. 0에서 키우면 튀어나오듯 보인다.
  static const double overlayEnterScale = 0.95;

  /// '다시 시도'를 누른 뒤 진행 상태를 최소한 보여 주는 시간. 연결이 끊기면
  /// 요청이 곧바로 실패해 진행 상태가 한 프레임에 지나가 눌렸는지 모른다.
  static const Duration retryMinBusy = Duration(milliseconds: 500);

  /// 다시 실패했다는 문구를 원래 문구로 되돌리기 전까지 보여 주는 시간.
  static const Duration retryFailedHold = Duration(seconds: 2);
}
