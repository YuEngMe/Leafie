import 'package:flutter/material.dart';

/// 와프4차의 바뀔 수 있는 숫자를 한 곳에 모은 레이아웃 계약.
abstract final class AppLayout {
  static const Size referenceViewport = Size(402, 874);

  static const double authHorizontalPadding = 34;
  // 2395:31 로고 top 156. 상태바 46과 앱바 높이를 뺀 나머지.
  static const double loginTitleTopGap = 17;
  static const double loginTitleToLogoGap = 65;
  // 2395:31 로고 그룹 폭.
  static const double loginLogoWidth = 118.58;
  static const double loginLogoMarkWidthFactor = 0.98;
  // 로고 바닥 317 -> 이메일 382.
  static const double loginLogoToFormGap = 65;
  static const double loginEmailFieldHeight = 49;
  static const double loginEmailToPasswordGap = 14;
  static const double loginFilledEmailFieldHeight = 51;
  static const double loginFilledEmailToPasswordGap = 12;
  static const double loginPasswordComponentHeight = 75;
  // Paperlogy의 Flutter glyph top inset(2px)을 Figma raster(1px)에 맞춘다.
  static const double loginPasswordLinksTop = 60;
  static const double loginLinkHorizontalInset = 11;
  // 링크 바닥 520 -> 버튼 558.
  static const double loginLinkToButtonGap = 38;
  // 버튼 바닥 609 -> 구분선 694.
  static const double loginButtonToDividerGap = 85;
  static const double loginDividerLeftInset = 3;
  static const double loginDividerRightInset = 12;
  static const double loginDividerLabelInset = 12;
  // 구분선 694 -> 소셜 735.
  static const double loginDividerToSocialGap = 41;
  static const double loginSocialLeftInset = 51;
  static const double loginSocialRightInset = 55;
  // 2395:31 소셜 버튼 x 85 / 174.4 -> 간격 40. 애플은 팀 결정으로 뺐다.
  static const double loginSocialGap = 40;
  static const double loginSocialButtonSize = 49.41;
  static const double loginBottomGap = 39;
  // 2395:40 첫 라벨 잉크 y=148(상태바 46 제외 102).
  static const double authFormTopPadding = 42;
  // 시안 버튼 하단 33px + 홈 인디케이터 영역. 2395:40, 2395:52 공통.
  static const double authBottomActionPadding = 79;
  // 라벨+입력칸 그룹(75) 사이 간격. 라벨 피치 110 - 75 = 35.
  static const double authFieldGap = 35;
  static const double authEmailActionWidth = 68;
  static const double authEmailActionGap = 5;
  // 2395:44는 앱바 아래부터 로고까지. 시안 절대 293 - 앱바 밴드 약 102.
  static const double signupCompleteTopGap = 191;
  static const double signupCompleteLogoWidth = 155;
  static const double signupCompleteCopyGap = 42;
  // 2395:44 버튼 바닥 841 -> 프레임 874.
  static const double signupCompleteBottomGap = 33;
  static const double registrationHorizontalPadding = 47;
  static const double registrationHeaderGap = 16;
  static const double registrationNameCharacterTopGap = 38;
  static const double registrationNameCharacterWidth = 234;
  static const double registrationNameFieldsGap = 16;
  static const double personalityTagsTop = 38;
  static const double personalityCharacterWidth = 250;
  static const double personalityCharacterTop = 104;
  static const double personalityBubbleTop = 348;
  static const double personalityDotsTop = 430;
  static const double appearanceCharacterWidth = 232;
  static const double appearanceCharacterTop = 64;
  static const double appearancePaletteTop = 399;
  static const double appearanceTabTopOffset = -26;
  static const double appearanceSwatchesTopOffset = 17;
  static const double appearanceHairMessageTopOffset = 72;
  static const double completionArtSize = 360;
  static const double completionCharacterWidth = 230;
  static const double completionTopGap = 112;
  static const double completionTitleToArtGap = 0;
  static const double homeTopBarHeight = 68;
  static const double homeHumidityCardHeight = 54;
  static const double homeBottomNavHeight = 88;
  static const double bottomPadding = 39;
  static const double onboardingControlHeight = 51;
  static const double controlHeight = 52;
  static const double controlRadius = 50;
  static const double appBarHeight = 56;
  static const double progressWidth = 243;
  static const double progressHeight = 22;
  static const double characterWidth = 184;

  // 마이페이지(2319:2). 카드 폭 344라 좌우 여백은 (402-344)/2 = 29.
  static const double myPageHorizontalPadding = 29;

  /// 앱바 아래에서 프로필 카드 top(119)까지. 상태바 46 + 앱바 56 = 102.
  static const double myPageTopGap = 17;

  /// 프로필 카드 바닥(196.762)에서 메뉴 카드 top(211)까지.
  static const double myPageCardGap = 14.238;

  /// 로그아웃 버튼 바닥(841)에서 화면 아래(874)까지 33px. 여기에 시안의
  /// 상태바 46px을 더한다 — SafeArea가 상태바를 먹으면 Spacer가 그만큼
  /// 남은 공간을 늘려 버튼을 아래로 밀기 때문이다.
  static const double myPageBottomGap = 33 + 46;
}
