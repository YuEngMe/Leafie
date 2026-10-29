import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/my_page_screen.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/edge_swipe_back.dart';

/// Tab pages stay mounted; only detail navigation creates a route.
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
        // 다이어리·캘린더·마이 탭은 화면 이동이 아니라 돌아갈 화면이 없다. 왼쪽
        // 끝을 밀면 위 뒤로 가기처럼 홈 탭으로 돌아간다(디자이너 답 13-B).
        EdgeSwipeBack(
          enabled: _index != 0,
          onSwipe: () => select(FigmaNavIcon.home),
          child: IndexedStack(
            index: _index,
            children: [
              widget.home,
              _visited.contains(1)
                  ? widget.diaryBuilder(context)
                  : const SizedBox.shrink(),
              _visited.contains(2)
                  ? widget.calendarBuilder(context)
                  : const SizedBox.shrink(),
              // 리뉴얼 시안(4534:3044)은 마이페이지에도 탭 바를 둔다. 그래서
              // 화면을 따로 올리지 않고 넷째 탭으로 둔다.
              _visited.contains(3)
                  ? MyPageScreen(inTab: true, onNavTap: select)
                  : const SizedBox.shrink(),
            ],
          ),
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
                // _index 0/1/2/3 → home/diary/calendar/my.
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
