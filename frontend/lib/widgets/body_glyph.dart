import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';

/// 바디 스위처의 실루엣 아이콘 하나(5038:6460). SVG 에셋이 없어 도형을
/// 코드로 그린다. 시안 규격 ≈ 22×22, 선택 시 kOrangeMain·미선택 시 회색으로
/// 도형 자체를 채운다(테두리가 아니라 면 색).
///
/// 편집 화면(plant_edit_appearance_screen)과 등록 바디선택 화면
/// (plant_register_body_screen)이 같은 실루엣을 쓰므로 공용 위젯으로 뺐다
/// (#87 중복 제거).
class BodyGlyph extends StatelessWidget {
  const BodyGlyph({super.key, required this.id, required this.selected});

  final String id;
  final bool selected;

  static const double _size = 22;
  // 시안 미선택 실루엣 회색(#D9D9D9 계열). 프로젝트 상수 kProgressInactive와 같은 값.
  static const Color _idleColor = kProgressInactive;

  @override
  Widget build(BuildContext context) {
    final color = selected ? kOrangeMain : _idleColor;
    return SizedBox(
      width: _size,
      height: _size,
      child: DecoratedBox(decoration: _decorationFor(id, color)),
    );
  }

  static BoxDecoration _decorationFor(String id, Color color) {
    switch (id) {
      case 'body_square':
        // 네모: 라운드 처리된 사각형.
        return BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        );
      case 'body_thumb':
        // 통통이: 위는 둥근 돔, 아래는 평평(body_thumb.png 실루엣 근사).
        // 위 두 모서리에만 큰 반지름을 줘 반원에 가까운 돔을 만든다.
        return BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_size / 2),
            bottom: Radius.circular(4),
          ),
        );
      case 'body_circle':
      default:
        // 동그라미: 꽉 찬 원.
        return BoxDecoration(color: color, shape: BoxShape.circle);
    }
  }
}
