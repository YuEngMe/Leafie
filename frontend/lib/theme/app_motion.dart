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
}
