import 'package:flutter/material.dart';

/// 와프4차의 바뀔 수 있는 숫자를 한 곳에 모은 레이아웃 계약.
abstract final class AppLayout {
  static const Size referenceViewport = Size(402, 874);

  static const double authHorizontalPadding = 34;
  // 2395:31 로고 top 156. 상태바 46과 앱바 높이를 뺀 나머지.
  /// 제목 '로그인' top은 시안에서 58(=874/2-367.5-11.5). 상태바 46을 빼면 12.
  static const double loginTitleTopGap = 12;

  /// 제목 bottom(81)에서 로고 top(162.42)까지.
  static const double loginTitleToLogoGap = 81.42;
  // 2395:31 로고 그룹 폭.
  static const double loginLogoWidth = 118.58;

  /// 심볼 에셋은 117x119라 폭을 그대로 쓰면 시안(110.65)보다 7.5px 커진다.
  /// 110.65 x (117/119) / 118.581 = 0.9174.
  static const double loginLogoMarkWidthFactor = 0.9174;
  // 로고 바닥 317 -> 이메일 382.
  static const double loginLogoToFormGap = 65;

  /// 시안 2353:24는 높이를 명시하지 않지만 비번칸(2353:26)이 51이고 두 칸은
  /// 같은 크기다. 49는 간격 14를 전제로 역산됐던 값이라 함께 바로잡는다.
  static const double loginEmailFieldHeight = 51;
  static const double loginEmailToPasswordGap = 12;
  static const double loginFilledEmailFieldHeight = 51;
  static const double loginFilledEmailToPasswordGap = 12;
  static const double loginPasswordComponentHeight = 75;
  // Paperlogy의 Flutter glyph top inset(2px)을 Figma raster(1px)에 맞춘다.
  static const double loginPasswordLinksTop = 61;
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
  /// 회원가입(2307:933) 첫 라벨 top 145 = 앱바 92 + 53. 재설정(2307:1502)도 같다.
  static const double authFormTopPadding = 53;

  /// 라벨은 입력칸보다 11px 들여쓴다(x34 → x45). 모든 흐름 공통.
  static const double inputLabelIndent = 11;
  // 시안 버튼 하단 33px + 홈 인디케이터 영역. 2395:40, 2395:52 공통.
  /// 시안은 버튼 바닥에서 화면 아래까지 33px을 두지만, 실기기의 하단
  /// SafeArea(34px)가 그 자리를 대신한다. 79는 상태바가 없는 골든만 보고
  /// 넣은 값이라 실기기에서 버튼이 79px 떠 있었다.
  static const double authBottomActionPadding = 0;
  // 라벨+입력칸 그룹(75) 사이 간격. 라벨 피치 110 - 75 = 35.
  static const double authFieldGap = 35;
  static const double authEmailActionWidth = 68;
  static const double authEmailActionGap = 5;
  // 2395:44는 앱바 아래부터 로고까지. 시안 절대 293 - 앱바 밴드 약 102.
  static const double signupCompleteTopGap = 191;
  static const double signupCompleteLogoWidth = 155;
  static const double signupCompleteCopyGap = 42;
  // 2395:44 버튼 바닥 841 -> 프레임 874.
  static const double signupCompleteBottomGap = 0;

  /// 시안(2315:2189)의 입력칸·버튼은 x=34 w=334이다. 47은 시안 대조를
  /// 거치기 전 값이라 좌우가 13px씩 좁았다.
  static const double registrationHorizontalPadding = 34;

  /// 라벨만 입력칸보다 11px 들여쓴다(2315:2248 x=45). 마이페이지 쪽
  /// 화면들과 같은 규칙이다.
  static const double registrationLabelIndent = inputLabelIndent;

  /// 입력칸 바닥에서 다음 라벨까지. 라벨 사이가 110이 되어야 하는데
  /// 라벨+칸 묶음이 79로 렌더돼 시안의 35 대신 31을 준다(2318:2981).
  static const double registrationFieldGap = 31;

  /// 물결이 그려지는 바닥(113.21)에서 헤드라인 top(140)까지.
  static const double registrationHeaderGap = 26.79;

  /// 앱바 아래(92)에서 물결이 그려지기 시작하는 91.79까지. 0.21px 차이는
  /// 반올림 범위라 붙여 둔다.
  static const double registrationProgressTopGap = 0;

  /// 부제 바닥(195)에서 캐릭터 top(267)까지.
  static const double registrationNameCharacterTopGap = 72;

  /// 시안 2315:2244는 175x150.
  static const double registrationNameCharacterWidth = 175;

  /// 캐릭터 바닥(417)에서 애칭 라벨(493)까지.
  static const double registrationNameFieldsGap = 76;
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

  /// 시안 3173:113. 아이콘이 들어오며 88 -> 79로 낮아졌다.
  static const double homeBottomNavHeight = 79;

  /// 시안은 버튼 바닥에서 화면 아래까지 33px을 두지만 실기기의 하단
  /// SafeArea(34)가 그 자리를 대신한다. 39는 상태바가 없는 골든만 보고
  /// 넣은 값이라 실기기에서 버튼이 40px 떠 있었다.
  static const double bottomPadding = 0;
  static const double onboardingControlHeight = 51;
  static const double controlHeight = 52;
  static const double controlRadius = 50;
  static const double appBarHeight = 56;

  /// 시안 프레임은 238x15지만 SVG가 inset으로 넘쳐 실제 243x21.425로
  /// 그려진다(2315:2237). 그려지는 크기를 그대로 쓴다.
  static const double progressWidth = 243;
  static const double progressHeight = 21.425;
  static const double characterWidth = 184;

  // 마이페이지(2319:2). 카드 폭 344라 좌우 여백은 (402-344)/2 = 29.
  static const double myPageHorizontalPadding = 29;

  /// 앱바 아래에서 프로필 카드 top(119)까지. 상태바 46 + 앱바 46 = 92.
  static const double myPageTopGap = 27;

  /// 시안(2319:23)의 로그아웃 버튼은 x=34 w=334으로, 카드(29/344)보다
  /// 좌우가 5px씩 좁다.
  static const double myPageButtonInset = 5;

  /// 마이페이지 하위 화면(2316:6397, 2570:1994)은 좌우 34로 공통이다.
  static const double myPageSubHorizontalPadding = 34;

  /// 앱바 아래(92)에서 첫 라벨 top(145)까지.
  static const double editProfileTopGap = 53;

  /// 시안 2316:6397은 라벨(45)만 입력칸(34)보다 11px 들여쓴다.
  static const double editProfileLabelIndent = inputLabelIndent;

  /// 비밀번호 변경(2346:2722). 입력칸 바닥(220)에서 다음 라벨(255)까지.
  static const double changePasswordFieldGap = 35;

  /// 입력칸 바닥(220)에서 변경하기 버튼 top(244)까지.
  static const double editProfileFieldToButtonGap = 24;

  /// 회원 탈퇴(2570:1994). 앱바 아래에서 헤드라인 top(140)까지.
  static const double withdrawTopGap = 48;

  /// 헤드라인 블록 바닥(191)에서 안내 박스 top(241)까지.
  static const double withdrawCopyToNoticeGap = 50;

  /// 안내 박스 top(241)에서 동의 줄 top(357)까지.
  static const double withdrawNoticeToConsentGap = 116;

  /// 구분선 y=446, 탈퇴 버튼 top=466.
  static const double withdrawDividerY = 446;
  static const double withdrawButtonTop = 466;

  /// 프로필 카드 바닥(196.762)에서 메뉴 카드 top(211)까지.
  static const double myPageCardGap = 14.238;

  /// 시안은 버튼 바닥(841)에서 화면 아래(874)까지 33px을 둔다. 실기기의
  /// 하단 SafeArea(홈 인디케이터, 34px)가 그 자리를 그대로 대신하므로
  /// 여백을 따로 주지 않는다. 46을 더하던 예전 값은 상태바가 없는 골든만
  /// 보고 넣은 것이라, 실기기에서 하단을 두 번 깎아 버튼이 80px 떠 있었다.
  static const double myPageBottomGap = 0;
}
