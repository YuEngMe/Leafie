import 'package:flutter/material.dart';

/// 캐릭터 바디 색 팔레트. 등록(plant_register_appearance_screen)과
/// 편집(plant_edit_appearance_screen) 두 화면이 같은 목록을 공유한다.
///
/// color_id는 임의 문자열이라 프론트에서 정하며, PATCH /plants/{id}/appearance
/// 의 color_id로 그대로 전달된다(서버 스키마 변경 없음).
///
/// 색 10개는 디자이너 확정 hex(2026-09-20). id는 실제 색과 맞는 이름으로 짓는다
/// — 이전 placeholder 시절 id(color_orange_01 등)는 색과 무관해 혼란을 줬다.
typedef PlantAppearanceColor = ({String id, String label, Color color});

const List<PlantAppearanceColor> kPlantAppearanceColors = [
  (id: 'color_lemon_01', label: '레몬', color: Color(0xFFFEF4A4)),
  (id: 'color_lime_01', label: '라임', color: Color(0xFFE0FFA2)),
  (id: 'color_mint_01', label: '민트', color: Color(0xFFB3FEA8)),
  (id: 'color_sky_01', label: '스카이', color: Color(0xFFA6E8F6)),
  (id: 'color_blue_01', label: '블루', color: Color(0xFFAAC7F6)),
  (id: 'color_purple_01', label: '퍼플', color: Color(0xFFCCAEFF)),
  (id: 'color_pink_01', label: '핑크', color: Color(0xFFFBBBE2)),
  (id: 'color_ivory_01', label: '아이보리', color: Color(0xFFFFFCE8)),
  (id: 'color_red_01', label: '레드', color: Color(0xFFFF7878)),
  (id: 'color_yellow_01', label: '옐로우', color: Color(0xFFFFD870)),
];
