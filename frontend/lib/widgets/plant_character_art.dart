import 'package:flutter/material.dart';

class PlantCharacterArt extends StatelessWidget {
  const PlantCharacterArt({super.key, this.width = 184, this.sprouted = false});

  final double width;
  final bool sprouted;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      sprouted
          ? 'assets/images/leafie_character_sprout.png'
          : 'assets/images/leafie_character.png',
      width: width,
      fit: BoxFit.contain,
      semanticLabel: sprouted ? '새싹이 자란 식물 친구' : '식물 친구 캐릭터',
    );
  }
}
