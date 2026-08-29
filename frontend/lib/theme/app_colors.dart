import 'package:flutter/material.dart';

// 2026-08-29 Figma "디자인방" 컴포넌트 라이브러리 기준(node 2097:7392).
// 팀이 메인 컬러를 초록 계열에서 오렌지 계열로 교체했다.
const Color kOrangeMain = Color(0xFFFFB52A); // 오렌지_메인, 주요 버튼
const Color kOrange = Color(0xFFFFB222); // 오렌지, 포인트
const Color kPaleYellow = Color(0xFFFFECA6); // 연노랑, 강조 배경
const Color kTextDark = Color(0xFF444444); // 진한 텍스트
const Color kTextLight = Color(0xFFA1A1A1); // 연한 텍스트
const Color kGrayLightest = Color(0xFFCCCBCB); // 제일연한회색, 비활성 버튼
const Color kBackgroundWhite = Color(0xFFFFFFFF); // 배경_화이트

// 기존 초록 팔레트 이름을 쓰던 화면들이 그대로 컴파일되도록 남긴 별칭.
// 화면을 새 디자인으로 옮길 때마다 위 이름으로 바꾸고 여기서 지운다.
const Color kAppBackground = kBackgroundWhite;
const Color kButtonGreen = kOrangeMain;
const Color kBorderGreen = kGrayLightest;
const Color kLabelGreen = kTextDark;
