import 'package:flutter/material.dart';

/// 캐릭터 바디 색 팔레트. 등록(plant_register_appearance_screen)과
/// 편집(plant_edit_appearance_screen) 두 화면이 같은 목록을 공유한다.
///
/// color_id는 더 이상 프론트가 자유롭게 정하는 문자열이 아니다. 백엔드가
/// `ColorType` StrEnum으로 검증하므로(backend/app/models/enums.py), 여기 id는
/// 그 enum 값과 1:1로 같아야 한다. 다른 값을 보내면 POST /plants와
/// PATCH /plants/{id}/appearance가 422로 떨어진다.
///
/// 색 목록을 내려주는 조회 엔드포인트는 아직 없다. 그래서 이 카탈로그는
/// 프론트 하드코딩이며, 백엔드 enum이 바뀌면 손으로 동기화해야 한다.
///
/// 순서는 시안 "홈_색상" 표 순서, hex는 디자이너 확정값(2026-09-20),
/// 라벨은 시안 표기를 따른다.
typedef PlantAppearanceColor = ({String id, String label, Color color});

const List<PlantAppearanceColor> kPlantAppearanceColors = [
  (id: 'color_red', label: '레드', color: Color(0xFFFF7878)),
  (id: 'color_orange', label: '오렌지', color: Color(0xFFFFD870)),
  (id: 'color_yellow', label: '옐로', color: Color(0xFFFEF4A4)),
  (id: 'color_light_green', label: '라이트 그린', color: Color(0xFFE0FFA2)),
  (id: 'color_green', label: '그린', color: Color(0xFFB3FEA8)),
  (id: 'color_sky', label: '스카이', color: Color(0xFFA6E8F6)),
  (id: 'color_blue', label: '블루', color: Color(0xFFAAC7F6)),
  (id: 'color_purple', label: '퍼플', color: Color(0xFFCCAEFF)),
  (id: 'color_pink', label: '핑크', color: Color(0xFFFBBBE2)),
  (id: 'color_white', label: '화이트', color: Color(0xFFFFFCE8)),
];
