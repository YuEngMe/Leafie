import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/register_progress_bar.dart';

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
      appBar: AppBar(
        backgroundColor: kBackgroundWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: kTextLight,
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(appBarTitle, style: kBodyStyle),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: RegisterProgressBar(step: step)),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
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
                  kScreenPadding,
                  0,
                  kScreenPadding,
                  40,
                ),
                child: bottomButton!,
              ),
          ],
        ),
      ),
    );
  }
}
