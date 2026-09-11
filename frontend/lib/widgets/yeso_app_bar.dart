import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

class YesoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const YesoAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
    this.backgroundColor,
    this.backIconColor,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  /// 다이어리처럼 배경이 앱바 뒤까지 이어지는 화면은 투명으로 둔다.
  final Color? backgroundColor;
  final Color? backIconColor;

  /// 시안(2319:2, 3345:996)의 앱바는 상태바 아래 46이다. Material 기본
  /// 56을 쓰면 꺾쇠와 제목이 5px 아래로 내려간다.
  static const double height = 46;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? kBackgroundWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      // 시안 3345:996은 꺾쇠 왼쪽 끝이 x=21.5다. AppBar가 leading을 가운데
      // 정렬하므로 폭을 21.5*2 + 아이콘 폭으로 잡아 왼쪽 여백을 만든다.
      leadingWidth: 21.5 * 2 + FigmaBackChevron.figmaSize.width,
      leading: showBack
          ? IconButton(
              // 시안 3345:996. 디자이너가 2026-09-05에 교체한 꺾쇠라
              // Material 기본 아이콘 대신 에셋을 쓴다.
              icon: FigmaBackChevron(color: backIconColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      title: Text(title, style: kBodyStyle),
      actions: actions,
    );
  }
}
