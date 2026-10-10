import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';

// Figma 가이드(node 1656:531): 폰트 페이퍼로지, 21(타이틀)/16(본문)/14(작은).
// 타이틀은 최신 시안에서 20으로 바뀌었다(아래 kTitleStyle).
// 컴포넌트 라이브러리는 12(작은 글씨)도 쓰므로 둘 다 둔다.
const String kFontFamily = 'Paperlogy';

// 최신 시안(4534:22)의 '타이틀' 텍스트 스타일은 SemiBold 20이다(4534:978,
// 4534:2991, 4534:21064 등 화면 제목 전부). 가이드(1656:531)의 21은 옛 값이다.
// 높이를 두지 않아 Material 3 기본 본문 높이(1.43)를 물려받으므로 Flutter 줄
// 상자는 29, 보이는 글자는 상자 top에서 5 아래다(시안은 상자 24, 글자 4 아래).
const TextStyle kTitleStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 20,
  fontWeight: FontWeight.w600,
  color: kTextDark,
);

// 두 줄 제목(비밀번호 변경 완료 4534:2883, 회원 탈퇴 완료 4534:2906 등)은
// 시안 글자 상자가 48이라 줄 간격이 24다. kTitleStyle은 물려받은 높이 1.43으로
// 한 줄이 29가 되어 둘째 줄이 5px 내려가므로 두 줄 제목에만 높이를 준다.
// 이때 보이는 첫 줄 글자는 상자 top에서 3 아래로 시안 두 줄 상자와 같아,
// 쓰는 쪽에서 top을 시안 상자 y 그대로 둔다.
const TextStyle kTitleTwoLineStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 20,
  fontWeight: FontWeight.w600,
  height: 24 / 20,
  color: kTextDark,
);

// 타이틀보다 큰 21 Medium 글자. 시안이 타이틀 스타일을 쓰지 않고 따로 21을
// 둔 자리다 — 마이페이지 프로필 닉네임(4534:3069)과 기기 서버 등록 실패
// 안내(4534:21309, 줄 높이 30).
const TextStyle kLargeMediumStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 21,
  fontWeight: FontWeight.w500,
  color: kTextDark,
);

const TextStyle kBodyStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 16,
  fontWeight: FontWeight.w500,
  color: kTextDark,
);

// 입력 항목·리스트 항목처럼 본문보다 한 단계 강조되는 자리.
const TextStyle kItemStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: kTextDark,
);

const TextStyle kSmallStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: kTextLight,
);

const TextStyle kCaptionStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: kTextLight,
);

// Figma와 Flutter의 Paperlogy 한글 자간 렌더링 차이를 화면 기준으로 보정한다.
const TextStyle kLoginHintStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  letterSpacing: -0.15,
  color: kTextLight,
);

const TextStyle kLoginEmailValueStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 14,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.18,
  color: kTextDark,
);

const TextStyle kLoginPasswordValueStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.78,
  color: kTextLight,
);

const TextStyle kLoginErrorStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  letterSpacing: -0.1,
  color: kErrorRed,
);

// 로그인 Figma node 2353:3의 화면 전용 텍스트 사양.
const TextStyle kLoginLinkStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 12,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.1,
  color: kTextLight,
);

const TextStyle kButtonStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 16,
  fontWeight: FontWeight.w500,
  color: Colors.white,
);

const TextStyle kLoginButtonStyle = kButtonStyle;

// 짧은 2글자 라벨의 Flutter 자간을 Figma raster 폭에 맞춘다.
const TextStyle kSendButtonStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 16,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.5,
  color: Colors.white,
);

const TextStyle kLoginDividerStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: kTextLight,
);

// 하단 고정 버튼 여백(가이드: 왼쪽 정렬 여백 47, 버튼 Y 720).
const double kScreenPadding = AppLayout.registrationHorizontalPadding;
const double kButtonRadius = AppLayout.controlRadius;

// 처방전(2346:2450)은 기존 21/16/14/12 스케일과 맞지 않는 크기를 여럿 쓴다.
// 노드에 적힌 값을 그대로 두고 호출부에서 fontSize만 바꿔 쓴다.
const TextStyle kPrescriptionBodyStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 11.206,
  fontWeight: FontWeight.w400,
  color: kPrescriptionText,
  height: 1,
);

const TextStyle kPrescriptionHeadingStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 14.35,
  fontWeight: FontWeight.w500,
  color: kPrescriptionText,
  height: 1,
);

const TextStyle kPrescriptionLabelStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 10.675,
  fontWeight: FontWeight.w500,
  color: kTextLight,
  height: 1,
);
