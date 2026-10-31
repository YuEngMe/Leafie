import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yeso_plant/widgets/plant_appearance_colors.dart';
import 'package:yeso_plant/widgets/svg_drop_shadow.dart';

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

/// 서버 expression_id를 얼굴로 옮긴다. 모르는 값은 기본 얼굴.
PlantExpression plantExpressionFromId(String? expressionId) =>
    switch (expressionId) {
      'expression_happy' => PlantExpression.happy,
      'expression_sad' => PlantExpression.sad,
      'expression_neutral' => PlantExpression.blank,
      _ => PlantExpression.defaultFace,
    };

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
    this.faceSwitchDuration = Duration.zero,
    this.shadow,
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

  /// 표정이 바뀔 때 얼굴만 크로스페이드하는 시간. 0이면 바로 바꾼다.
  ///
  /// 캐릭터 전체를 크로스페이드하면 반투명한 몸통 두 벌이 겹쳐 그동안
  /// 캐릭터가 유령처럼 비쳤다(디자이너 지적 2026-10). 몸통·머리는 그대로
  /// 두고 얼굴 PNG만 바꾼다. 얼굴 PNG는 몸통과 캔버스가 같아 자리가 안 튄다.
  final Duration faceSwitchDuration;

  /// 캐릭터 전체(몸통·얼굴·헤어)에 까는 그림자. null이면 없다(홈·알림).
  ///
  /// 몸통 PNG의 흰 glow는 밝은 배경에 묻혀 안 보여서, 시안은 흰 배경
  /// 화면에 캐릭터 그룹 그림자를 따로 줬다. 화면마다 값이 달라
  /// [CharacterShadow] 프리셋으로 넘긴다.
  final CharacterShadow? shadow;

  /// 박스 좌표에서 헤어 그림(시안 레이어 영역, PNG 여백 제외)이 차지하는
  /// 사각형. 헤어가 없으면 null.
  ///
  /// 헤어는 박스 위로 넘쳐 그려지는데(top이 음수), Flutter는 박스 밖을 터치로
  /// 받지 않는다. 헤어를 누르는 영역은 [hairHitPath]다.
  static Rect? hairInkRect({
    required double width,
    required PlantBody body,
    String? hairId,
  }) {
    final hair = hairId == null ? null : _kHairSpecs[hairId];
    if (hair == null) return null;
    final u = width * _kVisibleBodyRatio / _kCircleBodyUnitWidth;
    return hair.inkRectFor(
      body: body,
      u: u,
      centerX: width / 2,
      bodyTop: _bodyTopFor(width, body),
    );
  }

  /// 헤어를 누를 수 있는 영역(박스 좌표). 헤어 그림을 감싼 볼록 다각형이라
  /// 기울어진 잎 옆 빈 모서리는 빠진다. 헤어가 없으면 null.
  static Path? hairHitPath({
    required double width,
    required PlantBody body,
    String? hairId,
  }) {
    final hair = hairId == null ? null : _kHairSpecs[hairId];
    if (hair == null) return null;
    final u = width * _kVisibleBodyRatio / _kCircleBodyUnitWidth;
    return hair.hullPathFor(
      body: body,
      u: u,
      centerX: width / 2,
      bodyTop: _bodyTopFor(width, body),
    );
  }

  /// 모든 헤어·바디 조합에서 헤어가 박스 위로 넘치는 최대 높이. 박스 위에
  /// 헤어 터치 영역을 둘 자리를 캐릭터가 바뀌어도 같은 크기로 잡을 때 쓴다.
  static double maxHairOverflow(double width) {
    var overflow = 0.0;
    for (final hairId in _kHairSpecs.keys) {
      for (final body in PlantBody.values) {
        final rect = hairInkRect(width: width, body: body, hairId: hairId)!;
        overflow = math.max(overflow, -rect.top);
      }
    }
    return overflow;
  }

  /// 박스 위에서 잰 몸통 위쪽 y.
  static double _bodyTopFor(double width, PlantBody body) {
    final u = width * _kVisibleBodyRatio / _kCircleBodyUnitWidth;
    final geometry = _kBodyGeometry[body]!;
    return _bodyBottomFor(width, body) - geometry.bodyHeight * u;
  }

  /// 몸통 바닥(박스 위에서 잰 y). 박스 바닥에서 0.05301 × width 위가 circle
  /// 기준이고, 바디별 시안 바닥 차이(bottomShift unit)만큼 옮긴다.
  static double _bodyBottomFor(double width, PlantBody body) {
    final u = width * _kVisibleBodyRatio / _kCircleBodyUnitWidth;
    final geometry = _kBodyGeometry[body]!;
    return width * _kBoxAspect -
        width * _kBodyBottomInset -
        geometry.bottomShift * u;
  }

  @override
  Widget build(BuildContext context) {
    // 1 Figma unit당 픽셀. circle 몸통(155.23 unit)이 width × 0.897로 보인다.
    final u = width * _kVisibleBodyRatio / _kCircleBodyUnitWidth;
    final geometry = _kBodyGeometry[body]!;
    final boxHeight = width * _kBoxAspect;

    final bodyBottom = _bodyBottomFor(width, body);
    final bodyTop = _bodyTopFor(width, body);
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

    final art = SizedBox(
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
          Positioned.fromRect(rect: canvas, child: _face()),
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
    final shadow = this.shadow;
    if (shadow == null) return art;
    // Figma blur 값은 가우스 sigma의 2배다. unit으로 적어 두었으니 캐릭터
    // 배율(u)을 따라 키운다.
    return SvgDropShadow(
      stdDeviation: shadow.blur / 2 * u,
      opacity: shadow.opacity,
      color: shadow.color,
      child: art,
    );
  }

  Widget _face() {
    final asset = plantFaceAssetFor(body, expression);
    final face = Image.asset(
      asset,
      key: ValueKey(asset),
      fit: BoxFit.fill,
      excludeFromSemantics: true,
    );
    if (faceSwitchDuration == Duration.zero) return face;
    return AnimatedSwitcher(
      duration: faceSwitchDuration,
      // 기본 레이아웃(가운데 정렬 Stack)은 얼굴을 원본 PNG 크기로 그린다.
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: face,
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

/// [PlantCharacterArt.shadow] 값. [blur]는 circle 몸통 155.23 unit 기준
/// Figma blur라 캐릭터를 키우거나 줄여도 같은 비율로 번진다.
class CharacterShadow {
  const CharacterShadow({
    required this.color,
    required this.opacity,
    required this.blur,
  });

  /// 흰 배경 화면(등록 단계·꾸미기 편집·캐릭터 편집, 예: 5038:6608).
  /// 캐릭터 그룹에 #A7A7A7 40% · blur 10 · offset 0. 시안 캐릭터가 거의
  /// 원래 크기(몸통 약 155)라 blur가 곧 unit 값이다.
  static const onWhite = CharacterShadow(
    color: Color(0xFFA7A7A7),
    opacity: 0.4,
    blur: 10,
  );

  /// 내 캐릭터 목록(4534:6665, 그룹 4743:451 등). 검정 20% · blur 5 ·
  /// offset 0. 몸통 53.4pt(4743:195)에서 잰 5pt를 unit으로 옮긴다.
  static const myCharacters = CharacterShadow(
    color: Color(0xFF000000),
    opacity: 0.2,
    blur: 5 * _kCircleBodyUnitWidth / 53.4,
  );

  final Color color;
  final double opacity;
  final double blur;
}

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
/// - [width]/[height]: 시안 헤어 레이어 bbox. 헤어 PNG는 같은 컴포넌트
///   (식물머리 5035:5886)에서 4배로 뽑아 [ink]가 곧 이 레이어 영역이므로
///   비율이 정확히 맞는다(contain 계산은 안전장치로 남긴다).
/// - [overlap]: 헤어 그림 바닥이 몸통 bbox 위쪽보다 아래로 내려온 깊이.
/// - [dx]: 헤어 그림 중심 − 몸통 중심(+면 오른쪽). [dxByBody]가 있으면 우선.
/// - [png]/[ink]: 헤어 PNG 캔버스 크기와 그 안의 시안 레이어 영역(px).
///   PNG는 레이어 렌더 영역을 사방 3 unit 넓혀 뽑았다.
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
    required this.hull,
    this.dxByBody = const {},
  });
  final double width;
  final double height;
  final double overlap;
  final double dx;
  final Size png;
  final Rect ink;

  /// 헤어 그림(알파 > 40)을 감싼 볼록 다각형(PNG px). 손가락 여유로 사방
  /// 12px(≈3 unit) 넓혔다. 헤어 PNG에서 뽑은 값이라 PNG를 바꾸면 다시 뽑는다.
  final List<Offset> hull;
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

  /// 박스 좌표의 [hull] 다각형.
  Path hullPathFor({
    required PlantBody body,
    required double u,
    required double centerX,
    required double bodyTop,
  }) {
    final png = rectFor(body: body, u: u, centerX: centerX, bodyTop: bodyTop);
    final scale = png.width / this.png.width;
    return Path()
      ..addPolygon([for (final p in hull) png.topLeft + p * scale], true);
  }

  /// [rectFor] 안에서 시안 레이어 영역([ink])만 뺀 사각형.
  Rect inkRectFor({
    required PlantBody body,
    required double u,
    required double centerX,
    required double bodyTop,
  }) {
    final png = rectFor(body: body, u: u, centerX: centerX, bodyTop: bodyTop);
    final scale = png.width / this.png.width;
    return Rect.fromLTRB(
      png.left + ink.left * scale,
      png.top + ink.top * scale,
      png.left + ink.right * scale,
      png.top + ink.bottom * scale,
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
    png: Size(765, 463),
    ink: Rect.fromLTRB(16, 12, 749.2, 451),
    hull: [
      Offset(400.5, 442.5),
      Offset(11.5, 95.5),
      Offset(3.9, 71.4),
      Offset(20.4, 55.9),
      Offset(69.4, 35.9),
      Offset(127, 25),
      Offset(360, 7),
      Offset(371, 7),
      Offset(630, 19),
      Offset(706.6, 33.9),
      Offset(739.6, 47.9),
      Offset(759.1, 65.4),
      Offset(753.5, 88.5),
      Offset(437.5, 442.5),
    ],
  ),
  'hair_cherry_tomato': _HairSpec(
    120.81,
    177.99,
    23.99,
    20.79,
    png: Size(530, 736),
    ink: Rect.fromLTRB(12, 12, 495.3, 724),
    hull: [
      Offset(500.1, 122.6),
      Offset(360.1, 442.6),
      Offset(186.1, 723.6),
      Offset(164, 735),
      Offset(146.9, 722.6),
      Offset(9.9, 508.6),
      Offset(0, 479),
      Offset(0, 459),
      Offset(24.9, 328.4),
      Offset(105.9, 121.4),
      Offset(117.4, 110.9),
      Offset(378, 57),
      Offset(443.6, 68.9),
      Offset(492.5, 99.5),
    ],
  ),
  'hair_sunflower': _HairSpec(
    95.00,
    152.00,
    25.00,
    -4.12,
    png: Size(404, 632),
    ink: Rect.fromLTRB(12, 12, 392, 620),
    hull: [
      Offset(24, 416),
      Offset(0, 232),
      Offset(8.9, 147.4),
      Offset(39.9, 85.4),
      Offset(97.5, 29.5),
      Offset(176.4, 0.9),
      Offset(268.6, 9.9),
      Offset(328.6, 39.9),
      Offset(343.1, 53.4),
      Offset(379.1, 112.4),
      Offset(402.1, 180.4),
      Offset(398, 260),
      Offset(375, 442),
      Offset(371.1, 460.6),
      Offset(263.5, 611.5),
      Offset(223.5, 611.5),
      Offset(38.5, 437.5),
    ],
  ),
  'hair_hydrangea': _HairSpec(
    120.00,
    169.96,
    25.96,
    -4.62,
    png: Size(506, 705),
    ink: Rect.fromLTRB(13, 13, 493, 692.8),
    hull: [
      Offset(1, 202),
      Offset(5.9, 174.4),
      Offset(62.9, 77.4),
      Offset(81.4, 58.9),
      Offset(152.4, 23.9),
      Offset(268, 1),
      Offset(331.6, 16.9),
      Offset(391.6, 50.9),
      Offset(444.1, 91.4),
      Offset(480, 164),
      Offset(480, 211),
      Offset(449.1, 466.6),
      Offset(309.5, 681.5),
      Offset(266.5, 680.5),
      Offset(114.5, 497.5),
      Offset(30.9, 371.6),
    ],
    dxByBody: {PlantBody.thumb: -4.01},
  ),
  // 산세베리아(시안은 square 바디).
  'hair_pointed_succulent': _HairSpec(
    145.00,
    181.91,
    17.91,
    4.50,
    png: Size(605, 766),
    ink: Rect.fromLTRB(12, 26, 592, 753.7),
    hull: [
      Offset(256.5, 24.5),
      Offset(506.5, 230.5),
      Offset(516, 249),
      Offset(513, 309),
      Offset(499, 418),
      Offset(472.1, 524.6),
      Offset(438.1, 600.6),
      Offset(402.5, 658.5),
      Offset(345.5, 732.5),
      Offset(328, 739),
      Offset(221, 733),
      Offset(183.5, 700.5),
      Offset(146.5, 656.5),
      Offset(101.9, 590.6),
      Offset(84.9, 558.6),
      Offset(64.9, 505.6),
      Offset(52, 448),
      Offset(44, 388),
      Offset(39, 303),
      Offset(41, 183),
      Offset(52.5, 158.5),
      Offset(215.5, 23.5),
      Offset(240, 17),
    ],
  ),
  'hair_daisy': _HairSpec(
    116.00,
    165.00,
    18.00,
    -9.62,
    png: Size(488, 685),
    ink: Rect.fromLTRB(12, 12, 476, 672),
    hull: [
      Offset(42, 299),
      Offset(37, 217),
      Offset(40.9, 190.4),
      Offset(79.9, 115.4),
      Offset(93.5, 98.5),
      Offset(163.4, 50.9),
      Offset(187, 40),
      Offset(296.6, 38.9),
      Offset(390.5, 90.5),
      Offset(444.5, 152.5),
      Offset(458, 185),
      Offset(448.1, 293.6),
      Offset(331.1, 659.6),
      Offset(283.5, 663.5),
      Offset(124.5, 531.5),
      Offset(76.9, 481.6),
    ],
  ),
  // 에케베리아.
  'hair_rosette_succulent': _HairSpec(
    140.00,
    83.48,
    24.48,
    -0.62,
    png: Size(584, 358),
    ink: Rect.fromLTRB(12, 12, 572, 345.9),
    hull: [
      Offset(50.5, 111.5),
      Offset(118.5, 43.5),
      Offset(124.4, 39.9),
      Offset(205.4, 17.9),
      Offset(280.4, 0.9),
      Offset(292, 0),
      Offset(379.6, 17.9),
      Offset(459.6, 47.9),
      Offset(526.5, 105.5),
      Offset(542.1, 129.4),
      Offset(547, 149),
      Offset(554, 232),
      Offset(543.1, 261.6),
      Offset(518.5, 291.5),
      Offset(495.6, 308.1),
      Offset(465.6, 321.1),
      Offset(368.6, 341.1),
      Offset(322, 348),
      Offset(275, 348),
      Offset(134, 328),
      Offset(105.4, 321.1),
      Offset(72.5, 302.5),
      Offset(48.5, 279.5),
      Offset(33.9, 256.6),
      Offset(27, 223),
      Offset(36, 149),
    ],
  ),
  'hair_monstera': _HairSpec(
    160.00,
    169.25,
    25.25,
    -21.62,
    png: Size(664, 701),
    ink: Rect.fromLTRB(12, 12, 652, 689),
    hull: [
      Offset(152, 451),
      Offset(151, 339),
      Offset(160.9, 237.4),
      Offset(171.9, 191.4),
      Offset(202.5, 132.5),
      Offset(266.5, 74.5),
      Offset(303, 62),
      Offset(342, 63),
      Offset(398.6, 80.9),
      Offset(573.5, 199.5),
      Offset(598.1, 227.4),
      Offset(608.1, 249.4),
      Offset(613, 292),
      Offset(609.1, 316.6),
      Offset(587.1, 371.6),
      Offset(429.1, 672.6),
      Offset(415, 681),
      Offset(385.4, 680.1),
      Offset(172.5, 538.5),
      Offset(159.9, 520.6),
    ],
  ),
  // 선인장: 시안 캐릭터 없음(5035:5886 심볼 폭, overlap·dx 추정).
  'hair_flower_cactus': _HairSpec(
    64.36,
    138.02,
    22,
    0,
    png: Size(282, 577),
    ink: Rect.fromLTRB(12, 12, 269.5, 564.1),
    hull: [
      Offset(87, 556),
      Offset(64, 556),
      Offset(51.9, 545.6),
      Offset(41.9, 507.6),
      Offset(19, 375),
      Offset(7, 290),
      Offset(0, 211),
      Offset(0, 155),
      Offset(4.9, 122.4),
      Offset(21.9, 81.4),
      Offset(46.5, 43.5),
      Offset(63.5, 26.5),
      Offset(102.4, 4.9),
      Offset(127, 0),
      Offset(154, 0),
      Offset(196.6, 13.9),
      Offset(216.5, 27.5),
      Offset(240.5, 52.5),
      Offset(264.1, 92.4),
      Offset(275.1, 123.4),
      Offset(281, 171),
      Offset(281, 206),
      Offset(278, 260),
      Offset(269, 344),
      Offset(255, 435),
      Offset(241.1, 507.6),
      Offset(233.1, 538.6),
      Offset(225.6, 547.1),
      Offset(207, 549),
    ],
  ), // 하월시아(5644:1858): 시안 캐릭터 없음. 넓게 퍼지는 모양이 비슷한 에케베리아의 overlap을 빌린 추정값.
  'hair_haworthia': _HairSpec(
    131.00,
    110.87,
    24.48,
    0.00,
    png: Size(548, 468),
    ink: Rect.fromLTRB(12, 12, 536, 455.5),
    hull: [
      Offset(265.4, 0.9),
      Offset(164.5, 56.5),
      Offset(65.5, 135.5),
      Offset(60.9, 144.4),
      Offset(53, 189),
      Offset(51, 260),
      Offset(59.9, 317.6),
      Offset(74.9, 351.6),
      Offset(94.5, 377.5),
      Offset(119.5, 402.5),
      Offset(143.4, 419.1),
      Offset(178.4, 432.1),
      Offset(267, 444),
      Offset(375.6, 433.1),
      Offset(404.6, 422.1),
      Offset(440.5, 397.5),
      Offset(462.5, 374.5),
      Offset(483.1, 341.6),
      Offset(492.1, 313.6),
      Offset(498, 268),
      Offset(498, 223),
      Offset(490.1, 161.4),
      Offset(486.1, 146.4),
      Offset(478.5, 135.5),
      Offset(379.5, 55.5),
      Offset(287.6, 1.9),
    ],
  ),
  // 스투키(5633:1029): 시안 캐릭터 없음. 곧게 선 모양이 비슷한 산세베리아의 overlap을 빌린 추정값.
  'hair_stuckyi': _HairSpec(
    114.00,
    160.27,
    17.91,
    0.00,
    png: Size(480, 666),
    ink: Rect.fromLTRB(12, 12, 468, 653.1),
    hull: [
      Offset(181.4, 16.9),
      Offset(21.4, 111.9),
      Offset(14.9, 118.4),
      Offset(13, 134),
      Offset(67.9, 640.6),
      Offset(76.5, 652.5),
      Offset(92.4, 662.1),
      Offset(106, 665),
      Offset(334, 662),
      Offset(363.6, 652.1),
      Offset(385.1, 630.6),
      Offset(390, 615),
      Offset(449, 178),
      Offset(388.1, 27.4),
      Offset(378.6, 17.9),
    ],
  ),
  // 극락조(5639:1448): 시안 캐릭터 6516:7407 실측.
  'hair_strelitzia': _HairSpec(
    123.00,
    185.88,
    21.88,
    -0.12,
    png: Size(516, 776),
    ink: Rect.fromLTRB(12, 20, 504, 763.5),
    hull: [
      Offset(342, 8),
      Offset(92.4, 49.9),
      Offset(83.9, 60.4),
      Offset(1, 402),
      Offset(2.9, 412.6),
      Offset(69.5, 520.5),
      Offset(240.5, 735.5),
      Offset(249, 739),
      Offset(269.6, 737.1),
      Offset(276.1, 730.6),
      Offset(450.1, 403.6),
      Offset(512.1, 259.6),
      Offset(514.1, 239.4),
      Offset(349.6, 8.9),
    ],
  ),
  // 괴마옥(5739:2496): 시안 캐릭터 5739:2029 실측.
  'hair_gwaemaok': _HairSpec(
    119.22,
    154.20,
    29.20,
    -1.00,
    png: Size(501, 641),
    ink: Rect.fromLTRB(12, 12, 488.9, 628.8),
    hull: [
      Offset(295, 1),
      Offset(188.4, 20.9),
      Offset(142.4, 32.9),
      Offset(101.5, 62.5),
      Offset(1.9, 173.4),
      Offset(3.9, 217.6),
      Offset(134.9, 566.6),
      Offset(153.5, 592.5),
      Offset(182.4, 613.1),
      Offset(216, 615),
      Offset(338.6, 612.1),
      Offset(367.5, 591.5),
      Offset(384.1, 566.6),
      Offset(500, 188),
      Offset(436.1, 62.4),
      Offset(422.6, 50.9),
    ],
  ),
  // 핑크파이(5754:915): 시안 캐릭터 없음. 선인장처럼 overlap 22·dx 0 추정값.
  'hair_pink_pie': _HairSpec(
    102.28,
    95.54,
    22.00,
    0.00,
    png: Size(446, 416),
    ink: Rect.fromLTRB(16.8, 14.5, 425.9, 396.6),
    hull: [
      Offset(242, 1),
      Offset(191, 6),
      Offset(150.4, 18.9),
      Offset(103.5, 50.5),
      Offset(19.9, 144.4),
      Offset(10.9, 165.4),
      Offset(7, 187),
      Offset(7.9, 202.6),
      Offset(62.9, 298.6),
      Offset(85.5, 329.5),
      Offset(119.5, 363.5),
      Offset(150.5, 385.5),
      Offset(165.4, 394.1),
      Offset(184.4, 400.1),
      Offset(221, 407),
      Offset(246, 408),
      Offset(293.6, 399.1),
      Offset(308.6, 393.1),
      Offset(359.5, 361.5),
      Offset(396.5, 318.5),
      Offset(415.1, 290.6),
      Offset(432.1, 252.6),
      Offset(442, 199),
      Offset(442, 186),
      Offset(430.1, 135.4),
      Offset(418.1, 104.4),
      Offset(380.5, 58.5),
      Offset(326.6, 21.9),
      Offset(291.6, 9.9),
    ],
  ),
};
