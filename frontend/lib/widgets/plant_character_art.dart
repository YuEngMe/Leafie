import 'package:flutter/material.dart';

/// 캐릭터 바디 모양. 등록 시 사용자가 고른다. 백엔드 body_id가 아직
/// 없어 지금은 circle 고정으로 그린다.
enum PlantBody { circle, thumb, square }

/// 캐릭터 표정. [none]이면 표정 없는 기본 body PNG를 그대로 그린다(기존 동작).
/// 표정을 지정하면 `expr_*.png`(몸통+얼굴이 함께 그려진 완성 캐릭터)로 그린다.
/// expr 애셋은 모두 787x731로 크기가 같아 서로 교체해도 위치가 틀어지지 않지만
/// body PNG(circle=698x649)와는 여백 비율이 달라 호출부에서 폭/위치 보정이 필요하다.
enum PlantExpression { none, defaultFace, happy, sad, blank }

class PlantCharacterArt extends StatelessWidget {
  const PlantCharacterArt({
    super.key,
    this.width = 184,
    this.body = PlantBody.circle,
    this.expression = PlantExpression.none,
  });

  final double width;
  final PlantBody body;
  final PlantExpression expression;

  static const Map<PlantExpression, String> _expressionAssets = {
    PlantExpression.defaultFace: 'assets/images/expr_default.png',
    PlantExpression.happy: 'assets/images/expr_happy.png',
    PlantExpression.sad: 'assets/images/expr_sad.png',
    PlantExpression.blank: 'assets/images/expr_blank.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset =
        _expressionAssets[expression] ?? 'assets/images/body_${body.name}.png';
    return Image.asset(
      asset,
      width: width,
      fit: BoxFit.contain,
      semanticLabel: '식물 친구 캐릭터',
    );
  }
}
