import 'package:flutter/material.dart';
import 'package:yeso_plant/widgets/plant_appearance_colors.dart';

/// 캐릭터 바디 모양. 등록 시 사용자가 고른다.
enum PlantBody { circle, thumb, square }

/// 저장/전송용 body_id 문자열('body_circle' 등)을 [PlantBody] enum으로 옮긴다.
/// enum 이름과 'body_' 접미사가 일치하지만, 모르는 값(레거시·누락)에 죽지
/// 않도록 명시적으로 매핑하고 circle로 폴백한다. 역방향은 `'body_${body.name}'`.
PlantBody plantBodyFromId(String? bodyId) => switch (bodyId) {
  'body_thumb' => PlantBody.thumb,
  'body_square' => PlantBody.square,
  _ => PlantBody.circle,
};

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
    this.colorId,
    this.hairId,
  });

  final double width;
  final PlantBody body;
  final PlantExpression expression;

  /// 사용자가 고른 바디 색(`kPlantAppearanceColors`의 id). null이거나
  /// 카탈로그에 없는 레거시 값이면 tint 없이 원본 PNG를 그린다.
  final String? colorId;

  /// 종으로 자동 매핑된 헤어 애셋 id(`hair_*`). null이거나 카탈로그에 없는
  /// 값이면 헤어를 얹지 않고 민머리로 그린다(기존 동작 유지).
  final String? hairId;

  static const Map<PlantExpression, String> _expressionAssets = {
    PlantExpression.defaultFace: 'assets/images/expr_default.png',
    PlantExpression.happy: 'assets/images/expr_happy.png',
    PlantExpression.sad: 'assets/images/expr_sad.png',
    PlantExpression.blank: 'assets/images/expr_blank.png',
  };

  @override
  Widget build(BuildContext context) {
    final bodyArt = _buildBody();
    final spec = hairId == null ? null : _kHairSpecs[hairId];
    if (spec == null) return bodyArt;

    // 헤어를 몸통 위에 얹는다. 몸통이 Stack 크기를 정하고, 헤어는 몸통 상단
    // 중앙에 밑동을 붙인 채 위로 솟는다. 헤어 밑동은 정수리로 `overlap`만큼
    // 파고들고(둥근 크라운에 얹히도록), 나머지는 얼굴 위로 자란다.
    // 표정 애셋은 circle 전용이라 바디와 무관하게 circle 앵커를 쓴다.
    final anchor = expression == PlantExpression.none
        ? _kBodyGeometry[body]!.hairAnchor
        : _kBodyAspect;
    final bodyHeight = width * anchor;
    final hairWidth = width * spec.widthRatio;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        bodyArt,
        Positioned(
          // 헤어 밑동을 몸통 상단(bodyHeight)에서 overlap만큼 아래로 내려 얹는다.
          bottom: bodyHeight - spec.overlap * width,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              'assets/images/$hairId.png',
              width: hairWidth,
              fit: BoxFit.contain,
              semanticLabel: '식물 머리',
            ),
          ),
        ),
      ],
    );
  }

  /// 몸통/표정 이미지(색 틴트 포함).
  ///
  /// 표정 없는 몸통은 바디와 무관하게 같은 크기 박스(circle 기준
  /// `width x width*_kBodyAspect`)에 아래 정렬로 그린다. 바디를 바꿔도 위젯
  /// 크기가 그대로라 주변 레이아웃(인디케이터 등)이 흔들리지 않고, 보이는
  /// 몸통 크기는 [_kBodyGeometry]가 시안 비율에 맞춘다.
  Widget _buildBody() {
    final expressionAsset = _expressionAssets[expression];
    final geometry = _kBodyGeometry[body]!;
    final image = Image.asset(
      expressionAsset ?? 'assets/images/body_${body.name}.png',
      width: expressionAsset == null ? width * geometry.scale : width,
      fit: BoxFit.contain,
      semanticLabel: '식물 친구 캐릭터',
    );

    final target = plantBodyColorFor(colorId);
    // 옐로는 원본 몸통색과 사실상 같다(#F9FAB8 vs #F8F9B4). 필터를 걸면
    // 반올림 오차만 생기니 원본을 그대로 쓴다 — 기준점 겸 최적화.
    final art = target == null || colorId == 'color_yellow'
        ? image
        : PlantBodyTint(target: target, child: image);
    if (expressionAsset != null) return art;

    return SizedBox(
      width: width,
      height: width * _kBodyAspect,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: width * geometry.bottomInset),
          child: art,
        ),
      ),
    );
  }
}

/// 몸통 body PNG(circle 698x649)의 세로/가로 비. 몸통 박스 높이와 표정 애셋의
/// 헤어 앵커 기준으로 쓴다.
const double _kBodyAspect = 649 / 698;

/// 바디별 렌더 보정. body PNG 3장은 export 배율과 투명 여백이 서로 달라
/// (circle 698x649, thumb 762x731, square 750x715) 같은 폭으로 그리면 circle이
/// 가장 작아 보이고 바디를 바꿀 때 크기가 흔들린다. 시안(캐릭터 꾸미기
/// 5028:1662/1665/1666)은 몸통 폭이 circle 170.44 · thumb 164.70 · square 162.50,
/// 중심 x가 같고 바닥이 거의 같다.
/// - [scale]: PNG 렌더 폭 = `width * scale`. 실측 불투명 영역 폭
///   (circle 626/698, thumb 690/762, square 679/750)으로 보이는 몸통 폭을
///   시안 비율에 맞춘 값. circle이 기준이라 1.0.
/// - [bottomInset]: 박스 바닥에서 띄우는 거리(`width` 대비). 보이는 몸통 바닥을
///   시안 높이(circle 489, thumb 489.27, square 487.09)에 맞춘다.
/// - [hairAnchor]: 헤어 밑동 기준 높이(`width` 대비). 바디별 정수리 높이에
///   circle PNG의 상단 여백을 더해 circle과 같은 기준으로 [_HairSpec.overlap]을
///   쓸 수 있게 한다.
class _BodyGeometry {
  const _BodyGeometry(this.scale, this.bottomInset, this.hairAnchor);
  final double scale;
  final double bottomInset;
  final double hairAnchor;
}

const Map<PlantBody, _BodyGeometry> _kBodyGeometry = {
  PlantBody.circle: _BodyGeometry(1.0, 0, _kBodyAspect),
  PlantBody.thumb: _BodyGeometry(0.9571, 0.0051, 0.9271),
  PlantBody.square: _BodyGeometry(0.9445, 0.0178, 0.9269),
};

/// 헤어별 크기·오프셋 보정. 헤어 심볼 크기가 제각각(시안 5035:5886)이라
/// 몸통 대비 상대값으로 정렬한다.
/// - [widthRatio]: 헤어 렌더 폭 = `width * widthRatio`(몸통 폭 대비).
/// - [overlap]: 헤어 밑동이 정수리로 파고드는 깊이(`width` 대비). 값이 클수록
///   몸통 위로 얕게 얹히고, 작을수록 위로 높이 솟는다.
///
/// 근거: 시안 완성본(5028:4737)의 캐릭터별 전체 높이에서 "몸통 위로 솟는
/// 정도"를 헤어 종횡비(실측 PNG)와 함께 환산했다. 세로로 긴 하월시아/토마토는
/// 높이 솟고, 납작한 에케베리아(rosette)는 정수리에 얕게 얹힌다. 완벽 픽셀
/// 정합이 아니라 시안 비율 근사이며 golden으로 확인한다(#90 재조정 여지).
class _HairSpec {
  const _HairSpec(this.widthRatio, this.overlap);
  final double widthRatio;
  final double overlap;
}

const Map<String, _HairSpec> _kHairSpecs = {
  'hair_sprout': _HairSpec(0.96, 0.10), // 바질/기본: 잎 두 장 넓게, 낮고 넓게
  'hair_cherry_tomato': _HairSpec(0.60, 0.06),
  'hair_sunflower': _HairSpec(0.52, 0.05),
  'hair_hydrangea': _HairSpec(0.62, 0.06),
  'hair_monstera': _HairSpec(0.84, 0.08),
  'hair_rosette_succulent': _HairSpec(0.72, 0.14), // 에케베리아: 납작, 정수리에 얕게
  'hair_daisy': _HairSpec(0.60, 0.06),
  'hair_flower_cactus': _HairSpec(0.58, 0.10),
  'hair_pointed_succulent': _HairSpec(0.68, 0.05), // 하월시아: 길쭉, 가장 높이 솟음
};

/// 캐릭터 PNG(몸통+얼굴 한 장)에서 몸통만 [target] 색으로 물들인다.
///
/// PNG에 몸통 마스크가 없어 단순 `srcATop`는 쓸 수 없다(눈·입·볼까지
/// 물든다). 대신 두 레이어를 겹친다.
///
/// 1. 몸통 레이어 — 밝기를 목표색으로 환산하는 행렬.
///    `out_i = luma(src) * (target_i / bodyLuma)`
///    몸통은 목표색으로 정확히 옮겨가고, 거의 검은 눈은 luma≈0이라
///    그대로 검게 남는다. 대신 빨간 입은 회갈색으로 바래므로 —
/// 2. 입 레이어 — 원본을 "붉은 정도"를 알파로 삼아 위에 얹어 되살린다.
///    붉은 정도 = R - (G+B)/2. 몸통(#F8F9B4)은 0.13, 입(#DC5756)은 0.52라
///    선형 알파 행렬만으로 둘을 가를 수 있다. 볼터치도 같이 살아난다.
///
/// 계수 [_k]/[_bias]는 "몸통 알파≈0, 입 알파≥1"을 만족하는 하한
/// (k ≥ 1/(0.524-0.132) ≈ 2.55)에서 고른 값이다. k를 더 키우면 몸통이
/// 원본 노랑 쪽으로 되돌아가 목표색이 흐려진다(실측 확인).
class PlantBodyTint extends StatelessWidget {
  const PlantBodyTint({super.key, required this.target, required this.child});

  final Color target;
  final Widget child;

  /// 원본 캐릭터 PNG의 몸통색 #F8F9B4.
  static const double _baseLuma =
      0.299 * (0xF8 / 255) + 0.587 * (0xF9 / 255) + 0.114 * (0xB4 / 255);

  static const double _k = 2.6;
  static const double _bias = 0.345;

  static const List<double> _mouthMatrix = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    _k, -0.5 * _k, -0.5 * _k, 0, -_bias,
  ];

  @override
  Widget build(BuildContext context) {
    final argb = target.toARGB32();
    final kr = (((argb >> 16) & 0xFF) / 255) / _baseLuma;
    final kg = (((argb >> 8) & 0xFF) / 255) / _baseLuma;
    final kb = ((argb & 0xFF) / 255) / _baseLuma;

    final bodyMatrix = <double>[
      0.299 * kr, 0.587 * kr, 0.114 * kr, 0, 0, //
      0.299 * kg, 0.587 * kg, 0.114 * kg, 0, 0,
      0.299 * kb, 0.587 * kb, 0.114 * kb, 0, 0,
      0, 0, 0, 1, 0,
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.matrix(bodyMatrix),
          child: child,
        ),
        Positioned.fill(
          child: Center(
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(_mouthMatrix),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
