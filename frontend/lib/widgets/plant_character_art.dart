import 'package:flutter/material.dart';

/// 캐릭터 바디 모양. 등록 시 사용자가 고른다. 백엔드 body_id가 아직
/// 없어 지금은 circle 고정으로 그린다.
enum PlantBody { circle, thumb, square }

class PlantCharacterArt extends StatelessWidget {
  const PlantCharacterArt({
    super.key,
    this.width = 184,
    this.body = PlantBody.circle,
  });

  final double width;
  final PlantBody body;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/body_${body.name}.png',
      width: width,
      fit: BoxFit.contain,
      semanticLabel: '식물 친구 캐릭터',
    );
  }
}
