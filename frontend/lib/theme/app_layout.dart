import 'package:flutter/material.dart';

/// 와프4차의 바뀔 수 있는 숫자를 한 곳에 모은 레이아웃 계약.
abstract final class AppLayout {
  static const Size referenceViewport = Size(402, 874);

  /// 시안이 그린 상태바 높이. 실제 iPhone 16 Pro의 상단 안전 영역은 62라
  /// 그대로 두면 모든 화면이 시안보다 16 아래에 앉는다.
  static const double designStatusBarHeight = 46;

  static const double authHorizontalPadding = 34;
  // 2395:31 로고 top 156. 상태바 46과 앱바 높이를 뺀 나머지.
  /// 제목 '로그인' top은 시안에서 58(=874/2-367.5-11.5). 상태바 46을 빼면 12.
  static const double loginTitleTopGap = 12;

  /// 제목 bottom(81)에서 로고 top(169)까지(4534:2499 로고 4792:106 y=169).
  static const double loginTitleToLogoGap = 88;

  /// 4534:2499 로고(4792:106)는 102x130.37이다. 심볼(4792:107)과
  /// 워드마크(4792:132)가 같은 폭 102이고 둘 사이가 7이다. 옛 시안
  /// (2395:31)의 118.58 묶음보다 작아 로고가 16px 넓었다.
  static const double loginLogoWidth = 102;
  static const double loginLogoMarkWidthFactor = 1;
  static const double loginLogoGap = 7;

  /// 로고 바닥 299.36 -> 이메일 382. 로고 높이는 에셋 비율로 정해진다
  /// (102x516/540 + 7 + 102x514/2025 = 130.36).
  static const double loginLogoToFormGap = 82.64;

  /// 빈 이메일칸(4534:2520)은 49이고 비번칸(445)까지 14를 띄운다. 값이
  /// 있는 칸(4534:1423)만 51 + 간격 12다. 두 상태 모두 비번칸은 445에 앉는다.
  static const double loginEmailFieldHeight = 49;
  static const double loginEmailToPasswordGap = 14;
  static const double loginFilledEmailFieldHeight = 51;
  static const double loginFilledEmailToPasswordGap = 12;
  static const double loginPasswordComponentHeight = 75;
  // Paperlogy의 Flutter glyph top inset(2px)을 Figma raster(1px)에 맞춘다.
  static const double loginPasswordLinksTop = 61;
  static const double loginLinkHorizontalInset = 11;
  // 링크 바닥 520 -> 버튼 558.
  static const double loginLinkToButtonGap = 38;

  /// 버튼 바닥 609 -> 구분선 줄 694(4534:2579). 구분선 행은 글자 상자 17
  /// 높이라 줄이 행 top + 8.5에 그려진다. 그래서 행 top은 685.5다.
  static const double loginButtonToDividerGap = 76.5;
  static const double loginDividerLeftInset = 3;
  static const double loginDividerRightInset = 12;
  static const double loginDividerLabelInset = 12;

  /// 구분선 행 바닥 702.5 -> 소셜 735(4534:2538).
  static const double loginDividerToSocialGap = 32.5;

  /// 4534:2499(소셜 2개) 버튼 x 121 / 230.4 -> 간격 60. 묶음 가운데가
  /// 200.5라 오른쪽을 왼쪽보다 1 더 들인다. 버튼 3개 시안(4534:1402)의
  /// 간격 40은 애플을 뺀 지금 구성과 맞지 않는다.
  static const double loginSocialLeftInset = 51;
  static const double loginSocialRightInset = 52;
  static const double loginSocialGap = 60;
  static const double loginSocialButtonSize = 49.41;
  static const double loginBottomGap = 39;
  /// 회원가입(2307:933) 첫 라벨 top 145 = 앱바 92 + 53. 재설정(2307:1502)도 같다.
  static const double authFormTopPadding = 53;

  /// 재설정 완료(4534:2261) 문구 상자 top 388 − 본문 시작(상태바 46 +
  /// authFormTopPadding 53). 시안 headline 상자는 388(높이 48)이고 글자가
  /// 391에 찍힌다. Flutter 두 줄 상자(20px, 줄 24)도 글자 위 여백이 3이라
  /// 상자를 시안 자리에 둔다. 위아래 Spacer로 가운데에 두면 시안보다 32px
  /// 아래였다.
  static const double passwordResetDoneTitleGap = 289;

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
  /// 4534:2454·2325 로고(4889:386)는 로그인과 같은 102x130.37 묶음이고
  /// top 236이다. 앱바 아래(92)부터 잰다. 옛 시안(2395:44)의 폭 155
  /// 워드마크를 쓰던 때는 로고가 47px 아래였다.
  static const double signupCompleteTopGap = 144;

  /// 로고 바닥 366.36 -> 제목 글자 상자 474.5. 시안 headline(4534:2478)
  /// 상자는 472(높이 24)지만 글자는 475에 찍힌다. Flutter 상자를 474.5에
  /// 둬야 글자가 같은 줄에 찍힌다(골든 대조).
  static const double signupCompleteCopyGap = 108.14;

  /// 제목 상자 바닥(494.5, 20px height 1 상자 20) -> 부제 상자 508.5. 부제
  /// 글자가 508에 찍힌다(4534:2479 body).
  static const double signupCompleteTitleToSubtitleGap = 14;
  // 2395:44 버튼 바닥 841 -> 프레임 874.
  static const double signupCompleteBottomGap = 0;

  /// 시안(2315:2189)의 입력칸·버튼은 x=34 w=334이다. 47은 시안 대조를
  /// 거치기 전 값이라 좌우가 13px씩 좁았다.
  static const double registrationHorizontalPadding = 34;

  /// 라벨만 입력칸보다 11px 들여쓴다(2315:2248 x=45). 마이페이지 쪽
  /// 화면들과 같은 규칙이다.
  static const double registrationLabelIndent = inputLabelIndent;

  /// 입력칸 바닥에서 다음 라벨까지(4534:85: 칸 바닥 289 → 라벨 324).
  /// 라벨+칸 묶음이 라벨 상자 23 + 간격 1 + 칸 51 = 75로 렌더돼 시안
  /// 값 35를 그대로 쓰면 라벨 사이가 110이 된다.
  static const double registrationFieldGap = 35;

  /// 물결이 그려지는 바닥(113.21)에서 헤드라인 상자 top(139)까지. 시안
  /// 상자는 140이고 글자는 144에 찍힌다. Flutter 20px 제목은 글자가 상자 top
  /// 5 아래라 상자를 1 올린다.
  static const double registrationHeaderGap = 25.79;

  /// 앱바 아래(92)에서 물결이 그려지기 시작하는 91.79까지. 0.21px 차이는
  /// 반올림 범위라 붙여 둔다.
  static const double registrationProgressTopGap = 0;

  /// 시안 4534:954 캐릭터(5038:6564 동글표정)는 몸통 155.23x142.99,
  /// top 289 → 몸통 바닥 431.99. 옛 시안(2315:2244 175x150)으로 그려
  /// 몸통이 12px 위에 있었다. 폭은 circle 몸통이 155.23으로 보이는 값.
  static const double registrationNameCharacterWidth = 155.23 / 0.897;

  /// 부제 글자 상자 바닥(Flutter 195.2)에서 캐릭터 박스 top(280.26)까지.
  /// 박스 top = 몸통 바닥 431.99 − 폭 × 612/698(박스 위→몸통 바닥).
  static const double registrationNameCharacterTopGap = 85.06;

  /// 캐릭터 박스 바닥(441.17)에서 애칭 라벨 상자 top(493)까지. 라벨+칸
  /// 묶음은 라벨 상자 top 493 → 칸 top 517로 그려진다(4534:986).
  static const double registrationNameFieldsGap = 51.83;
  // 성격 화면 요소는 PageView의 Stack(top=0)을 기준으로 놓인다. 그 top=0의
  // 절대 y는 상태바 46 + 앱바 46 + 진행바 21.425 + 간격 12 = 125.425다.
  // 아래 상수는 시안의 절대 y에서 이 125.425를 뺀 값이다. 헤드라인·태그는
  // 4534:195 그대로(152 / 190), 캐릭터·말풍선·점은 디자이너가 고친
  // 6049:2564(충청도 성격, 메모 6049:2648)를 따른다(244 / 581 / 691).
  // 시안 헤드라인 상자 152·글자 156. Flutter 20px 제목은 글자가 상자 top
  // 5 아래라 1 올린 151(125.425 + 26)에 둔다.
  static const double personalityTitleTop = 26;
  static const double personalityTagsTop = 65; // 시안 190
  // 시안 6049:2633: 몸통(circle 기준) 폭 156, 바닥 y=550.22(이전 139·488.85
  // 에서 1.12배). 헤어는 박스 위로 솟으므로 박스 위치를 헤어 꼭대기가 아닌
  // 몸통 바닥에 맞춘다. 폭 = 156 / 0.897(circle PNG 불투명 영역 비율).
  // 박스 top = 몸통 바닥 − 폭 × 612/698(박스 위→몸통 바닥) − 125.425.
  static const double personalityCharacterWidth = 156 / 0.897;
  static const double personalityCharacterTop =
      550.22 - personalityCharacterWidth * 612 / 698 - 125.425;
  // 말풍선 6049:2604: 위로 꼬리가 난 Union(253x47.05)의 top이 581이고,
  // SVG는 그림자 여백(사방 4.126)을 포함해 위가 576.87다.
  static const double personalityBubbleTop = 576.87 - 125.425;
  // 대사(6049:2607) 글자 가운데 608.55 → Flutter 글자 상자 top 597.05.
  static const double personalityBubbleTextTop = 597.05 - 125.425;
  static const double personalityDotsTop = 691 - 125.425; // 6049:2595
  static const double appearanceCharacterWidth = 232;
  static const double appearanceCharacterTop = 64;
  static const double appearancePaletteTop = 399;
  static const double appearanceTabTopOffset = -26;
  static const double appearanceSwatchesTopOffset = 17;
  // 시안 4534:812 (앱바 없음, 본문 시작 y=46 기준). 몸통(square) 폭 156 →
  // 모든 바디가 같은 크기로 보이도록 circle 기준 폭 182.4(= 163.6 / 0.897)로
  // 그린다. 아래 top 값은 제목 글자 상자 top(186)에서 잰 상대값이다.
  // 제목: 시안 글자 상자 188(높이 24)에 보이는 글자 꼭대기가 192인데,
  // Flutter 상자는 글자 위 여백이 6이라 상자를 186에 둬야 192에 찍힌다.
  static const double completionTopGap = 140; // 제목 상자 y=186
  static const double completionGlowTop = 65; // 광원 원 y=251
  static const double completionGlowSize = 408;
  static const double completionCharacterWidth = 182.4;
  // 몸통 바닥 y=596.9 → 박스 위 = 596.9 + 9.7 − 169.6 − 186.
  static const double completionCharacterTop = 251;
  static const double completionStageHeight = 473; // 광원 원 바닥 y=659
  static const double homeTopBarHeight = 68;
  static const double homeHumidityCardHeight = 54;

  /// 시안 3628:2411. 아이콘이 들어오며 88 -> 79로 낮아졌다.
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
