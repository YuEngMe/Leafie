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
    this.scrollable = false,
    this.centerTitle = false,
    this.appBarTitleColor,
  });

  final String appBarTitle;
  final int step;
  final String title;
  final String subtitle;
  final Widget child;

  /// 하단에 고정할 버튼. 식물찾기처럼 버튼이 없는 단계는 비워 둔다.
  final Widget? bottomButton;

  /// 본문에 입력칸이 있는 단계는 키보드가 올라오면 본문 높이가 줄어
  /// 고정 간격 Column이 넘친다. 이때 본문만 스크롤되게 한다. 목록처럼
  /// 스스로 스크롤하는 본문(식물찾기)에는 켜지 않는다.
  final bool scrollable;

  /// 캐릭터 꾸미기 단계(바디 5028:1193, 컬러 4534:507)는 헤드라인을 화면
  /// 가운데에 둔다. 나머지 단계는 왼쪽 정렬이다.
  final bool centerTitle;

  /// 앱바 제목 색. null이면 공용 기본(#444). 캐릭터 꾸미기 단계 시안
  /// (5028:1193, 4534:507)은 제목이 검정이다.
  final Color? appBarTitleColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: YesoAppBar(title: appBarTitle, titleColor: appBarTitleColor),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppLayout.registrationProgressTopGap),
            Center(child: RegisterProgressBar(step: step)),
            const SizedBox(height: AppLayout.registrationHeaderGap),
            Padding(
              // 헤드라인과 부제는 입력칸(34)보다 11px 들여쓴다(2315:2234).
              padding: const EdgeInsets.symmetric(
                horizontal:
                    AppLayout.registrationHorizontalPadding +
                    AppLayout.registrationLabelIndent,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (centerTitle)
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        title,
                        style: kTitleStyle,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Text(title, style: kTitleStyle),
                  // 시안 2318:2981처럼 부제가 없는 화면은 간격도 두지 않는다.
                  if (subtitle.isNotEmpty) ...[
                    // 헤드라인 상자 top 139(시안 140, 글자 자리 보정)에서 부제
                    // top 175까지 36, 헤드라인 글자 상자(20px)가 29라 남는
                    // 7px이 간격이다(2315:2234).
                    const SizedBox(height: 7),
                    // 부제는 #757575(4534:954·1007). kSmallStyle 기본
                    // #A1A1A1보다 진하다. 닉네임 부제와 같은 색이다.
                    Text(
                      subtitle,
                      style: kSmallStyle.copyWith(color: kOnboardingSubtitle),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: scrollable
                  ? SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: child,
                    )
                  : child,
            ),
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
