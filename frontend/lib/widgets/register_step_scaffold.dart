import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/register_progress_bar.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

// 캐릭터 등록 단계 화면의 공통 뼈대(Figma node 1841:443, 1841:485).
// 뒤로가기와 중앙 타이틀, 진행바, 큰 제목과 부제까지가 모든 단계에서 같고
// 그 아래 본문과 하단 버튼만 화면마다 다르다.
class RegisterStepScaffold extends StatelessWidget {
  const RegisterStepScaffold({
    super.key,
    required this.appBarTitle,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottomButton,
  });

  final String appBarTitle;
  final int step;
  final String title;
  final String subtitle;
  final Widget child;

  /// 하단에 고정할 버튼. 식물찾기처럼 버튼이 없는 단계는 비워 둔다.
  final Widget? bottomButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: YesoAppBar(title: appBarTitle),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: RegisterProgressBar(step: step)),
            const SizedBox(height: AppLayout.registrationHeaderGap),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppLayout.registrationHorizontalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: kTitleStyle),
                  const SizedBox(height: 14),
                  Text(subtitle, style: kSmallStyle),
                ],
              ),
            ),
            Expanded(child: child),
            if (bottomButton != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.registrationHorizontalPadding,
                  0,
                  AppLayout.registrationHorizontalPadding,
                  AppLayout.bottomPadding,
                ),
                child: bottomButton!,
              ),
          ],
        ),
      ),
    );
  }
}
