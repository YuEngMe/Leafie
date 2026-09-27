import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:yeso_plant/theme/app_layout.dart';

/// 상단 안전 영역을 시안 상태바 높이(46)로 맞춘다.
///
/// 지원 기기는 iPhone 16 Pro 하나다. 이 기기의 상단 안전 영역은 62지만
/// Dynamic Island 밑선은 그보다 위라, 시안처럼 46부터 앱바를 그려도 섬과
/// 겹치지 않는다. 화면마다 좌표를 16씩 고치는 대신 앱 루트에서 한 번만
/// 줄여서, 상태바 46을 전제로 한 모든 화면이 시안 좌표 그대로 앉게 한다.
/// 이미 46보다 얇은 안전 영역은 건드리지 않는다.
class DesignStatusBarInset extends StatelessWidget {
  const DesignStatusBarInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    double clamp(double top) => math.min(top, AppLayout.designStatusBarHeight);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(top: clamp(media.padding.top)),
        viewPadding: media.viewPadding.copyWith(
          top: clamp(media.viewPadding.top),
        ),
      ),
      child: child,
    );
  }
}
