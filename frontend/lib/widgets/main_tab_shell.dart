import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/my_page_screen.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

/// Tab pages stay mounted; only detail/profile navigation creates a route.
class MainTabShell extends StatefulWidget {
  const MainTabShell({
    super.key,
    required this.home,
    required this.diaryBuilder,
    required this.calendarBuilder,
  });

  final Widget home;
  final WidgetBuilder diaryBuilder;
  final WidgetBuilder calendarBuilder;

  @override
  State<MainTabShell> createState() => MainTabShellState();
}

/// 홈이 알림을 따라 다른 탭으로 옮길 때 [select]를 부른다.
///
/// 탭 전환은 애니메이션 없이 바로 바꾼다. 하루 수십 번 누르는 동작이라
/// 전환 모션은 매번 느리게만 만든다. 예전 180ms 페이드는 새 탭을 투명(0)에서
/// 다시 그려 전환마다 화면이 번쩍였다. iOS 탭 바도 즉시 바뀐다.
class MainTabShellState extends State<MainTabShell> {
  int _index = 0;
  final _visited = <int>{0};

  void select(FigmaNavIcon tab) {
    if (tab == FigmaNavIcon.my) {
      // Reset underneath the profile route so every back gesture returns home.
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MyPageScreen()));
      setState(() => _index = 0);
      return;
    }
    final next = tab.index;
    if (next == _index) return;
    setState(() {
      _index = next;
      _visited.add(next);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _index == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) select(FigmaNavIcon.home);
    },
    child: Stack(
      fit: StackFit.expand,
      children: [
        IndexedStack(
          index: _index,
          children: [
            widget.home,
            _visited.contains(1)
                ? widget.diaryBuilder(context)
                : const SizedBox.shrink(),
            _visited.contains(2)
                ? widget.calendarBuilder(context)
                : const SizedBox.shrink(),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height:
                AppLayout.homeBottomNavHeight *
                MediaQuery.sizeOf(context).height /
                AppLayout.referenceViewport.height,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: AppLayout.referenceViewport.width,
                // _index 0/1/2 → home/diary/calendar. my 탭은 push 후 _index를
                // 0으로 되돌리므로 바에서는 늘 home이 활성으로 보인다.
                child: AppBottomNav(
                  onTap: select,
                  activeIcon: FigmaNavIcon.values[_index],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
