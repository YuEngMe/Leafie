import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';

/// Figma component set `마이페이지_앱알림` (2353:575)의 on/off 스위치.
///
/// 켜짐 `2353:574`, 꺼짐 `2353:573`. 시안은 켜짐일 때 노브가 왼쪽으로 가 있으나
/// 디자이너 실수로 확인돼(2026-08-31) 통상대로 켜짐을 오른쪽에 둔다.
/// 트랙 크기·색·노브 지름·좌우 여백은 시안 값 그대로다.
class FigmaToggleSwitch extends StatelessWidget {
  const FigmaToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// 트랙 크기(2353:574 Rectangle 34630889).
  static const Size trackSize = Size(48, 24.9231);
  static const double knobRadius = 10.6154;

  /// 트랙 안에서 노브 중심이 놓이는 x. SVG의 cx에서 트랙 원점을 뺀 값이며,
  /// 시안의 좌우가 뒤집혀 있어 켜짐/꺼짐 배정만 바꿔 쓴다.
  static const double knobCenterOn = 35.6154;
  static const double knobCenterOff = 12.4615;

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final knobCenter = value ? knobCenterOn : knobCenterOff;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          // 트랙은 24.9px이지만 터치 영역은 48px을 확보한다.
          height: 48,
          width: trackSize.width,
          child: Center(
            child: SizedBox.fromSize(
              size: trackSize,
              child: Stack(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: value ? kOrangeMain : kTextLight,
                      borderRadius: BorderRadius.circular(trackSize.height / 2),
                    ),
                    child: const SizedBox.expand(),
                  ),
                  Positioned(
                    left: knobCenter - knobRadius,
                    top: trackSize.height / 2 - knobRadius,
                    width: knobRadius * 2,
                    height: knobRadius * 2,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kBackgroundWhite,
                        // SVG feGaussianBlur stdDeviation 2.5 -> blurRadius 5,
                        // alpha 0.2 -> 0x33.
                        boxShadow: [
                          BoxShadow(color: Color(0x33000000), blurRadius: 5),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
