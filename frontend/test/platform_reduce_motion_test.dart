import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/widgets/platform_reduce_motion.dart';

void main() {
  bool? disableAnimations;

  Widget app() => PlatformReduceMotion(
    child: Builder(
      builder: (context) {
        disableAnimations = MediaQuery.disableAnimationsOf(context);
        return const SizedBox();
      },
    ),
  );

  testWidgets('iOS 동작 줄이기(reduceMotion)를 켜면 애니메이션을 끈다', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(app());
    expect(disableAnimations, isTrue);
  });

  testWidgets('앱이 떠 있는 동안 설정을 바꿔도 따라간다', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(app());
    expect(disableAnimations, isFalse);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    expect(disableAnimations, isTrue);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    await tester.pump();
    expect(disableAnimations, isFalse);
  });

  testWidgets('Android의 disableAnimations는 그대로 둔다', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(app());
    expect(disableAnimations, isTrue);
  });
}
