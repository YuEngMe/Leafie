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
///
/// 색은 두 가지를 갖는다. 서로 다른 값이니 헷갈리면 안 된다.
/// - [color]: 팔레트 스와치(선택 원)에 칠하는 진한 색.
/// - [bodyColor]: 캐릭터 몸통에 실제로 입히는 연한 색. 시안 "홈_색상" 표의
///   캐릭터 10종을 직접 실측한 값(2026-09-21)이라 스와치보다 훨씬 연하다.
///   `PlantCharacterArt`가 이 값으로 tint 한다.
typedef PlantAppearanceColor = ({
  String id,
  String label,
  Color color,
  Color bodyColor,
});

const List<PlantAppearanceColor> kPlantAppearanceColors = [
  (
    id: 'color_red',
    label: '레드',
    color: Color(0xFFFF7878),
    bodyColor: Color(0xFFFFDBDB),
  ),
  (
    id: 'color_orange',
    label: '오렌지',
    color: Color(0xFFFFD870),
    bodyColor: Color(0xFFFFE5A1),
  ),
  (
    id: 'color_yellow',
    label: '옐로',
    color: Color(0xFFFEF4A4),
    bodyColor: Color(0xFFF9FAB8),
  ),
  (
    id: 'color_light_green',
    label: '라이트 그린',
    color: Color(0xFFE0FFA2),
    bodyColor: Color(0xFFEEFFB2),
  ),
  (
    id: 'color_green',
    label: '그린',
    color: Color(0xFFB3FEA8),
    bodyColor: Color(0xFFCBFACA),
  ),
  (
    id: 'color_sky',
    label: '스카이',
    color: Color(0xFFA6E8F6),
    bodyColor: Color(0xFFC4F2FB),
  ),
  (
    id: 'color_blue',
    label: '블루',
    color: Color(0xFFAAC7F6),
    bodyColor: Color(0xFFBFE6FB),
  ),
  (
    id: 'color_purple',
    label: '퍼플',
    color: Color(0xFFCCAEFF),
    bodyColor: Color(0xFFDDC7FF),
  ),
  (
    id: 'color_pink',
    label: '핑크',
    color: Color(0xFFFBBBE2),
    bodyColor: Color(0xFFFCDCF6),
  ),
  (
    id: 'color_white',
    label: '화이트',
    color: Color(0xFFFFFCE8),
    bodyColor: Color(0xFFFFFCF3),
  ),
];

/// [colorId]에 해당하는 몸통색. 카탈로그에 없는 레거시 id면 null을 준다
/// (호출부는 tint 없이 원본을 그린다).
Color? plantBodyColorFor(String? colorId) {
  if (colorId == null) return null;
  for (final c in kPlantAppearanceColors) {
    if (c.id == colorId) return c.bodyColor;
  }
  return null;
}
