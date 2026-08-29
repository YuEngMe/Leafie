import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';

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

// 하단 고정 버튼 여백(가이드: 왼쪽 정렬 여백 47, 버튼 Y 720).
const double kScreenPadding = 47;
const double kButtonRadius = 50;
