import 'package:flutter/material.dart';

/// 와프4차의 바뀔 수 있는 숫자를 한 곳에 모은 레이아웃 계약.
abstract final class AppLayout {
  static const Size referenceViewport = Size(402, 874);

  static const double authHorizontalPadding = 34;
  static const double loginTitleTopGap = 0;
  static const double loginTitleToLogoGap = 65;
  static const double loginLogoWidth = 122;
  static const double loginLogoMarkWidthFactor = 0.98;
  static const double loginLogoToFormGap = 64;
  static const double loginEmailFieldHeight = 49;
  static const double loginEmailToPasswordGap = 14;
  static const double loginFilledEmailFieldHeight = 51;
  static const double loginFilledEmailToPasswordGap = 12;
  static const double loginPasswordComponentHeight = 75;
  // Paperlogy의 Flutter glyph top inset(2px)을 Figma raster(1px)에 맞춘다.
  static const double loginPasswordLinksTop = 60;
  static const double loginLinkHorizontalInset = 11;
  static const double loginLinkToButtonGap = 31;
  static const double loginButtonToDividerGap = 77;
  static const double loginDividerLeftInset = 3;
  static const double loginDividerRightInset = 12;
  static const double loginDividerLabelInset = 12;
  static const double loginDividerToSocialGap = 32;
  static const double loginSocialLeftInset = 51;
  static const double loginSocialRightInset = 55;
  static const double loginBottomGap = 39;
  static const double authFormTopPadding = 38;
  static const double authBottomActionPadding = 96;
  static const double authFieldGap = 28;
  static const double authEmailActionWidth = 68;
  static const double authEmailActionGap = 5;
  static const double signupCompleteTopGap = 210;
  static const double signupCompleteLogoWidth = 150;
  static const double signupCompleteCopyGap = 34;
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
}
