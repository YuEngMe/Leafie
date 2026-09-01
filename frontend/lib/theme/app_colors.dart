import 'package:flutter/material.dart';

// 2026-08-29 Figma "디자인방" 컴포넌트 라이브러리 기준(node 2097:7392).
// 팀이 메인 컬러를 초록 계열에서 오렌지 계열로 교체했다.
const Color kOrangeMain = Color(0xFFFFB52A); // 오렌지_메인, 주요 버튼
const Color kOrange = Color(0xFFFFB222); // 오렌지, 포인트
const Color kBrightOrange = Color(0xFFFF8834); // 밝은 오렌지, 입력 라벨
// 성격 태그 칩(2318:3966)의 Figma 변수 `메인컬러_주황`.
const Color kTagOrange = Color(0xFFFF9F6D);
// 성격 타이틀(2318:3964)만 쓰는 raw hex. kTextDark보다 진하다.
const Color kPersonalityTitle = Color(0xFF2E2E2E);
const Color kAppleGreen = Color(0xFFC1E25F); // 애플 그린, 홈 포인트
// 습도·조도 게이지(2435:16798)의 트랙과 선호 범위 시작색.
const Color kGaugeTrack = Color(0xFFE5E5E5);
const Color kGaugeComfortStart = Color(0xFFF2FFCD);
const Color kPaleYellow = Color(0xFFFFECA6); // 연노랑, 강조 배경
// 마이페이지 프로필 카드(2353:690). kPaleYellow 43%를 흰 배경에 합성한 값.
const Color kProfileCardYellow = Color(0xFFFFF7D9);
const Color kTextDark = Color(0xFF444444); // 진한 텍스트
// 진단 기록 제목(2346:2454)과 꺾쇠(2346:2456). 팔레트 토큰이 아니라 노드에
// 직접 박힌 값이다.
const Color kDiagnosisTitle = Color(0xFF1F2E21);
const Color kChevronGray = Color(0xFF7F7F7F);
// 처방전(2346:2450)이 쓰는 값들.
const Color kPrescriptionText = Color(0xFF030303);
const Color kPrescriptionPercent = Color(0xFF5A5A5A);
const Color kPrescriptionBorder = Color(0x80FFDC9C);
const Color kPrescriptionChipBorder = Color(0x99FFDC9C);
const Color kPrescriptionPanel = Color(0x4DFFDC9C);
const Color kCauseOverwater = Color(0xFF47D2B9);
const Color kCauseLowLight = Color(0xFFF6DA5E);
const Color kCausePest = Color(0xFFFA8F8F);
const Color kTextLight = Color(0xFFA1A1A1); // 연한 텍스트
// 홈 말풍선(2346:2367)의 붉은 점. kErrorRed(#F05F5F)와 다른 값이다.
const Color kBubbleDot = Color(0xFFFF5E5E);
// 홈 상태요청 말풍선 문구(2346:2368)와 그래프 수치의 짙은 초록.
const Color kBubbleGreen = Color(0xFF315E2D);
// 하단 네비 미선택 라벨(2346:2519).
const Color kNavLabelInactive = Color(0xFF919191);
// 식물 결과 카드(2318:3765)의 라벨. kTextLight보다 한 단계 어둡다.
const Color kResultLabel = Color(0xFF8D8D8D);
// 온보딩 안내 문구 전용. 팔레트 토큰이 아니라 2315:2514, 2315:2275에 직접
// 박혀 있는 값이라 이름을 따로 둔다.
const Color kOnboardingSubtitle = Color(0xFF757575);
const Color kGrayLightest = Color(0xFFCCCBCB); // 제일연한회색, 비활성 버튼
// 등록 진행바(2307:2015)의 비활성 물결. 비활성 버튼 회색과 다른 값이다.
const Color kProgressInactive = Color(0xFFD9D9D9);
const Color kErrorRed = Color(0xFFF05F5F); // 입력 오류
const Color kBackgroundWhite = Color(0xFFFFFFFF); // 배경_화이트
// 모달·바텀시트 뒤를 덮는 딤(2307:785). rgba(0,0,0,0.45).
const Color kModalBarrier = Color(0x73000000);
const Color kHomeGreen = Color(0xFFBFF4C8);
const Color kHomeYellow = Color(0xFFFFFFB7);
const Color kHomePeach = Color(0xFFFFD2B1);

// 기존 초록 팔레트 이름을 쓰던 화면들이 그대로 컴파일되도록 남긴 별칭.
// 화면을 새 디자인으로 옮길 때마다 위 이름으로 바꾸고 여기서 지운다.
const Color kAppBackground = kBackgroundWhite;
const Color kButtonGreen = kOrangeMain;
const Color kBorderGreen = kGrayLightest;
const Color kLabelGreen = kTextDark;
