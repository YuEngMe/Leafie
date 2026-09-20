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
  State<MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends State<MainTabShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  final _visited = <int>{0};
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _select(FigmaNavIcon tab) {
    if (tab == FigmaNavIcon.my) {
      // Reset underneath the profile route so every back gesture returns home.
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MyPageScreen()));
      setState(() => _index = 0);
      _fade.value = 1;
      return;
    }
    final next = tab.index;
    if (next == _index) return;
    setState(() {
      _index = next;
      _visited.add(next);
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _index == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _select(FigmaNavIcon.home);
    },
    child: Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: _fade,
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
                // _index 0/1/2 → home/diary/calendar. my 탭은 push 후 _index를
                // 0으로 되돌리므로 바에서는 늘 home이 활성으로 보인다.
                child: AppBottomNav(
                  onTap: _select,
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
