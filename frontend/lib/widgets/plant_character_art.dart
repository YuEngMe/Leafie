import 'dart:math' as math;

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

/// 캐릭터 표정. 몸통 위에 겹치는 얼굴 PNG를 고른다.
/// [none]은 표정을 따로 정하지 않은 호출부용으로 기본 얼굴을 그린다.
enum PlantExpression { none, defaultFace, happy, sad, blank }

/// 몸통 PNG 경로. [colorId]('color_red' 등)가 카탈로그에 없거나 null이면
/// 옐로 몸통을 쓴다.
String plantBodyAssetFor(PlantBody body, String? colorId) {
  final known = kPlantAppearanceColors.any((c) => c.id == colorId);
  final color = known ? colorId!.substring('color_'.length) : 'yellow';
  return 'assets/images/character/body_${body.name}_$color.png';
}

/// 얼굴 PNG 경로. 얼굴 PNG는 같은 바디의 몸통 PNG와 캔버스 크기·위치가
/// 같아 몸통 위에 그대로 겹친다.
String plantFaceAssetFor(PlantBody body, PlantExpression expression) {
  final face = switch (expression) {
    PlantExpression.none || PlantExpression.defaultFace => 'default',
    PlantExpression.happy => 'happy',
    PlantExpression.blank => 'neutral',
    PlantExpression.sad => 'sad',
  };
  return 'assets/images/character/face_${body.name}_$face.png';
}

class PlantCharacterArt extends StatelessWidget {
  const PlantCharacterArt({
    super.key,
    this.width = 184,
    this.body = PlantBody.circle,
    this.expression = PlantExpression.none,
    this.colorId,
    this.hairId,
  });

  /// circle 몸통의 보이는 폭이 `width × 0.897`이 되는 기준 폭.
  /// 위젯 박스는 바디와 무관하게 폭 `width`, 높이 `width × 649/698`이다.
  final double width;
  final PlantBody body;
  final PlantExpression expression;

  /// 사용자가 고른 바디 색(`kPlantAppearanceColors`의 id). null이거나
  /// 카탈로그에 없는 레거시 값이면 옐로 몸통을 그린다.
  final String? colorId;

  /// 종으로 자동 매핑된 헤어 애셋 id(`hair_*`). null이거나 카탈로그에 없는
  /// 값이면 헤어를 얹지 않고 민머리로 그린다.
  final String? hairId;

  @override
  Widget build(BuildContext context) {
    // 1 Figma unit당 픽셀. circle 몸통(155.23 unit)이 width × 0.897로 보인다.
    final u = width * _kVisibleBodyRatio / _kCircleBodyUnitWidth;
    final geometry = _kBodyGeometry[body]!;
    final boxHeight = width * _kBoxAspect;

    // 몸통 바닥(박스 위에서 잰 y). 박스 바닥에서 0.05301 × width 위가 circle
    // 기준이고, 바디별 시안 바닥 차이(bottomShift unit)만큼 옮긴다.
    final bodyBottom =
        boxHeight - width * _kBodyBottomInset - geometry.bottomShift * u;
    final bodyTop = bodyBottom - geometry.bodyHeight * u;
    final canvasWidth = geometry.canvasWidth * u;
    final canvasHeight = geometry.canvasHeight * u;
    // PNG 캔버스는 몸통을 사방 그림자 여백만큼 넓힌 것이라 박스 아래로
    // 살짝 넘칠 수 있다(Clip.none).
    final canvas = Rect.fromLTWH(
      (width - canvasWidth) / 2,
      bodyBottom + _kShadowMargin * u - canvasHeight,
      canvasWidth,
      canvasHeight,
    );

    final hair = hairId == null ? null : _kHairSpecs[hairId];

    return SizedBox(
      width: width,
      height: boxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: canvas,
            child: Image.asset(
              plantBodyAssetFor(body, colorId),
              fit: BoxFit.fill,
              semanticLabel: '식물 친구 캐릭터',
            ),
          ),
          Positioned.fromRect(
            rect: canvas,
            child: Image.asset(
              plantFaceAssetFor(body, expression),
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          if (hair != null)
            Positioned.fromRect(
              rect: hair.rectFor(
                body: body,
                u: u,
                centerX: width / 2,
                bodyTop: bodyTop,
              ),
              child: Image.asset(
                'assets/images/$hairId.png',
                fit: BoxFit.fill,
                semanticLabel: '식물 머리',
              ),
            ),
        ],
      ),
    );
  }
}

/// 위젯 박스 세로/가로 비. 옛 circle PNG(698x649) 박스를 그대로 유지해
/// 호출부 레이아웃이 바뀌지 않게 한다.
const double _kBoxAspect = 649 / 698;

/// `width` 계약: circle 몸통의 보이는 폭 = width × 0.897
/// (`plantArtWidthFor(figmaW) = figmaW / 0.897`).
const double _kVisibleBodyRatio = 0.897;

/// circle 몸통 실제 폭(Figma unit).
const double _kCircleBodyUnitWidth = 155.23;

/// 박스 바닥에서 circle 몸통 바닥까지(width 대비). 옛 circle PNG의 아래
/// 여백 37/698과 같다.
const double _kBodyBottomInset = 37 / 698;

/// 몸통·얼굴 PNG 캔버스가 몸통 bbox를 사방으로 넓힌 그림자 여백(unit).
const double _kShadowMargin = 10.745;

/// 바디별 PNG 기하(unit). 애셋은 세 바디 모두 같은 배율(4px = 1 unit)로
/// 뽑혔고 바디별 크기 차이는 시안(5028:1662) 의도다.
/// - [canvasWidth]/[canvasHeight]: PNG 캔버스 크기.
/// - [bodyHeight]: 몸통 bbox 높이(헤어 밑동 기준인 정수리 위치 계산용).
/// - [bottomShift]: circle 대비 시안 몸통 바닥 차이. +면 위로.
class _BodyGeometry {
  const _BodyGeometry(
    this.canvasWidth,
    this.canvasHeight,
    this.bodyHeight,
    this.bottomShift,
  );
  final double canvasWidth;
  final double canvasHeight;
  final double bodyHeight;
  final double bottomShift;
}

const Map<PlantBody, _BodyGeometry> _kBodyGeometry = {
  PlantBody.circle: _BodyGeometry(176.72, 164.48, 142.99, 0),
  PlantBody.thumb: _BodyGeometry(171.49, 164.73, 143.24, -0.27),
  PlantBody.square: _BodyGeometry(169.49, 161.83, 140.34, 1.91),
};

/// 헤어별 크기·위치(unit, 몸통 bbox 기준). 헤어 크기는 바디와 무관한 절대
/// 크기다.
/// - [width]/[height]: 시안 헤어 bbox. 헤어 그림(불투명 영역)을 이 상자 안에
///   비율을 지켜 최대로 맞춘다(contain). 저장소 헤어 PNG 일부는 시안 헤어와
///   종횡비가 달라(산세베리아·몬스테라는 더 길쭉) 폭만 맞추면 시안보다
///   훨씬 높이 솟으므로, 시안 bbox를 넘지 않게 한다.
/// - [overlap]: 헤어 그림 바닥이 몸통 bbox 위쪽보다 아래로 내려온 깊이.
/// - [dx]: 헤어 그림 중심 − 몸통 중심(+면 오른쪽). [dxByBody]가 있으면 우선.
/// - [png]/[ink]: 헤어 PNG 캔버스 크기와 그 안의 불투명 bbox(px, PIL 실측).
///   PNG 둘레 투명 여백을 빼고 그림 자체로 위 값을 맞춘다.
///
/// 근거: 시안 "홈에서 뜨는 캐릭터/식물 크기 예시"(5028:4737) 실측.
/// flower_cactus만 시안 캐릭터가 없어 헤어 심볼(5035:5886) 크기에
/// overlap 22·dx 0을 추정값으로 둔다.
class _HairSpec {
  const _HairSpec(
    this.width,
    this.height,
    this.overlap,
    this.dx, {
    required this.png,
    required this.ink,
    this.dxByBody = const {},
  });
  final double width;
  final double height;
  final double overlap;
  final double dx;
  final Size png;
  final Rect ink;
  final Map<PlantBody, double> dxByBody;

  /// 박스 좌표에서 헤어 PNG가 차지할 사각형.
  Rect rectFor({
    required PlantBody body,
    required double u,
    required double centerX,
    required double bodyTop,
  }) {
    final scale = math.min(width / ink.width, height / ink.height) * u;
    final inkCenterX = centerX + (dxByBody[body] ?? dx) * u;
    final inkBottom = bodyTop + overlap * u;
    return Rect.fromLTWH(
      inkCenterX - ink.center.dx * scale,
      inkBottom - ink.bottom * scale,
      png.width * scale,
      png.height * scale,
    );
  }
}

const Map<String, _HairSpec> _kHairSpecs = {
  // 바질/기본.
  'hair_sprout': _HairSpec(
    183.30,
    109.75,
    18.75,
    -0.95,
    png: Size(908, 538),
    ink: Rect.fromLTRB(4, 8, 902, 524),
  ),
  'hair_cherry_tomato': _HairSpec(
    120.81,
    177.99,
    23.99,
    20.79,
    png: Size(606, 854),
    ink: Rect.fromLTRB(0, 68, 573, 853),
  ),
  'hair_sunflower': _HairSpec(
    95.00,
    152.00,
    25.00,
    -4.12,
    png: Size(369, 540),
    ink: Rect.fromLTRB(0, 0, 369, 530),
  ),
  'hair_hydrangea': _HairSpec(
    120.00,
    169.96,
    25.96,
    -4.62,
    png: Size(567, 803),
    ink: Rect.fromLTRB(0, 0, 538, 786),
    dxByBody: {PlantBody.thumb: -4.01},
  ),
  // 산세베리아(시안은 square 바디).
  'hair_pointed_succulent': _HairSpec(
    145.00,
    181.91,
    17.91,
    4.50,
    png: Size(522, 667),
    ink: Rect.fromLTRB(35, 13, 446, 644),
  ),
  'hair_daisy': _HairSpec(
    116.00,
    165.00,
    18.00,
    -9.62,
    png: Size(473, 672),
    ink: Rect.fromLTRB(37, 37, 443, 661),
  ),
  // 에케베리아.
  'hair_rosette_succulent': _HairSpec(
    140.00,
    83.48,
    24.48,
    -0.62,
    png: Size(770, 460),
    ink: Rect.fromLTRB(38, 0, 731, 447),
  ),
  'hair_monstera': _HairSpec(
    160.00,
    169.25,
    25.25,
    -21.62,
    png: Size(630, 667),
    ink: Rect.fromLTRB(148, 60, 581, 652),
  ),
  // 선인장: 시안 캐릭터 없음(5035:5886 심볼 폭, overlap·dx 추정).
  'hair_flower_cactus': _HairSpec(
    64.36,
    138.02,
    22,
    0,
    png: Size(709, 708),
    ink: Rect.fromLTRB(19, 18, 690, 689),
  ),
};
