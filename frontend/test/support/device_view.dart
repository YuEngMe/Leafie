import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/theme/app_layout.dart';

/// 지원 기기(iPhone 16 Pro)의 화면 크기와 안전 영역으로 찍는다.
///
/// 상단은 앱 루트의 DesignStatusBarInset이 62를 줄인 뒤의 값(46)이다.
/// 안전 영역을 0으로 두면 안전 영역 안에서 가운데를 잡는 모달이나 하단
/// 버튼이 실기기와 다른 자리에 찍혀, 시안과 어긋나도 골든이 잡지 못한다.
void useDeviceView(WidgetTester tester) {
  const insets = FakeViewPadding(
    top: AppLayout.designStatusBarHeight,
    bottom: 34,
  );
  tester.view.physicalSize = AppLayout.referenceViewport;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  addTearDown(tester.view.reset);
}
