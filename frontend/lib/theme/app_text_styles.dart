import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';

// Figma 가이드(node 1656:531): 폰트 페이퍼로지, 21(타이틀)/16(본문)/14(작은).
// 컴포넌트 라이브러리는 12(작은 글씨)도 쓰므로 둘 다 둔다.
const String kFontFamily = 'Paperlogy';

const TextStyle kTitleStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 21,
  fontWeight: FontWeight.w600,
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
