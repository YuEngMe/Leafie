import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_colors.dart';

/// 바디 스위처의 실루엣 아이콘 하나(5028:1240). 시안 벡터를 그대로 내보낸
/// SVG를 선택 시 kOrangeMain·미선택 시 회색으로 칠한다(테두리가 아니라 면 색).
///
/// 세 실루엣은 크기가 조금씩 다르다. 동그라미는 살짝 납작하고(22.84×21.04),
/// 통통이는 아래에 발이 있으며(21.43×20.47), 네모는 가로가 더 길다
/// (22.44×19.66). 예전에는 SVG가 없어 22×22 정원·평평한 돔·정사각으로
/// 근사했다.
///
/// [size]는 22 기준 배율이다. 등록 바디 선택 시안(5028:1240)은 22 그대로,
/// 편집 꾸미기 시안(6049:2649)은 같은 벡터를 1.222배로 키웠다.
///
/// 편집 화면(plant_edit_appearance_screen)과 등록 바디선택 화면
/// (plant_register_body_screen)이 같은 실루엣을 쓰므로 공용 위젯으로 뺐다
/// (#87 중복 제거).
class BodyGlyph extends StatelessWidget {
  const BodyGlyph({
    super.key,
    required this.id,
    required this.selected,
    this.size = 22,
  });

  final String id;
  final bool selected;
  final double size;
  // 시안 미선택 실루엣 회색(#D9D9D9 계열). 프로젝트 상수 kProgressInactive와 같은 값.
  static const Color _idleColor = kProgressInactive;

  @override
  Widget build(BuildContext context) {
    final (asset, design) = switch (id) {
      'body_square' => ('square', const Size(22.4394, 19.6566)),
      'body_thumb' => ('thumb', const Size(21.4324, 20.4654)),
      _ => ('circle', const Size(22.8359, 21.0352)),
    };
    final scale = size / 22;
    return SvgPicture.asset(
      'assets/images/body_glyph_$asset.svg',
      width: design.width * scale,
      height: design.height * scale,
      colorFilter: ColorFilter.mode(
        selected ? kOrangeMain : _idleColor,
        BlendMode.srcIn,
      ),
    );
  }
}
