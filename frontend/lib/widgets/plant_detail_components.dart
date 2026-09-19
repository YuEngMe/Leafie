import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_glyphs.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 캐릭터 상세 흐름(2564:947, 2568:1714, 2568:1764, 2555:661)이 함께 쓰는
/// 조각들. 시안이 전부 절대 좌표라 Stack + Positioned로 옮긴다.

/// 시안 프레임의 절대 y를 화면 좌표로 옮길 때 빼는 값.
/// 상태바 46 + 앱바 46.
const double _kAppBarBand = 46 + YesoAppBar.height;

/// 하단 잔디 밴드(2564:1051 + 새싹 2568:1085~1087, 2568:1922~1924).
/// 윗선의 잔디 질감과 새싹 두 포기는 좌표로 옮기면 근사치가 되므로 시안
/// 프레임 렌더(y=770..845)를 그대로 잘라 쓴다. 에셋 안에서 초록 밴드는
/// 위에서 36px 아래에 시작하므로, 밴드가 시안 y=806에 오도록 770에 건다.
const double _kGrassAssetTop = 770;
const double _kGrassAssetHeight = 75;

/// 캐릭터 PNG는 캔버스 둘레에 투명 여백이 있다. 새 body PNG(`body_circle.png`
/// 등)는 590x549 안에서 실제 그림이 549x509(가로 93.05%)로, 여백이 거의
/// 없다. 시안 노드 폭을 그대로 `PlantCharacterArt(width:)`에 넣으면 그림이
/// 시안보다 살짝 작게 그려지므로 이 비율로 보정한다.
/// 시안 노드 폭을 넣으면 그림이 그 폭으로 보이는 값을 돌려준다.
double plantArtWidthFor(double figmaWidth) => figmaWidth / 0.897;

/// 상세 흐름 화면 몸통. SafeArea 안에서 시안 y를 그대로 쓰게 해 준다.
class PlantDetailBody extends StatelessWidget {
  const PlantDetailBody({
    super.key,
    required this.children,
    this.showGrass = false,
  });

  static const double appBarBand = _kAppBarBand;

  final List<Widget> children;

  /// 상세 1(2564:947)만 하단 잔디 밴드를 깐다.
  final bool showGrass;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showGrass)
            Positioned(
              left: 0,
              right: 0,
              top: _kGrassAssetTop - _kAppBarBand,
              height: _kGrassAssetHeight,
              child: Image.asset(
                'assets/images/plant_detail_grass.png',
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// 시안 절대 y를 넘기면 앱바 아래 좌표로 앉히는 가로 전체폭 슬롯.
class PlantDetailPositioned extends StatelessWidget {
  const PlantDetailPositioned({
    super.key,
    required this.top,
    required this.height,
    required this.child,
  });

  final double top;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: top - _kAppBarBand,
    height: height,
    child: child,
  );
}

/// 상세 카드 안 메뉴 한 줄(2564:1014 + 꺾쇠 2564:1015).
/// 글자 x=52, 꺾쇠 x=340(잉크 350) 15px 연한 텍스트.
class PlantDetailMenuRow extends StatelessWidget {
  const PlantDetailMenuRow({
    super.key,
    required this.label,
    required this.textTop,
    required this.onTap,
  });

  final String label;

  /// 시안의 글자 top(절대 y).
  final double textTop;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // 글자 높이 19를 세로 가운데 삼아 카드 폭(29~373) 안에서 누를 수 있게 한다.
    const rowHeight = 44.0;
    return Positioned(
      left: 29,
      width: 344,
      top: textTop + 19 / 2 - rowHeight / 2 - _kAppBarBand,
      height: rowHeight,
      child: GestureDetector(
        key: ValueKey('plant_detail_menu_$label'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              left: 52 - 29,
              top: rowHeight / 2 - 19 / 2,
              child: Text(label, style: kBodyStyle),
            ),
            Positioned(
              // 꺾쇠 잉크 오른쪽 끝 350 - 카드 왼쪽 29.
              right: 373 - 350,
              top: 0,
              bottom: 0,
              child: const Center(child: FigmaChevronRight(color: kTextLight)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상세 흐름 하단 고정 버튼(2555:691, 2568:1735). x=34 y=790 334x51.
/// 시안은 바닥까지 33px을 두지만 실기기의 하단 SafeArea가 대신한다.
class PlantDetailBottomAction extends StatelessWidget {
  const PlantDetailBottomAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(34, 0, 34, 0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: PrimaryButton(
          label: label,
          variant: onPressed == null
              ? PrimaryButtonVariant.disabled
              : PrimaryButtonVariant.enabled,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// 성격 한 종류의 표시용 글자. 등록 흐름(2318:3129~3430)과 같은 값이다.
class PlantPersonality {
  const PlantPersonality({
    required this.label,
    required this.tags,
    required this.dialogue,
  });

  final String label;
  final List<String> tags;
  final String dialogue;
}

/// api-spec.md의 PersonalityType 순서. 시안 페이지 도트 6개와 같다.
const List<String> kPlantPersonalityOrder = [
  'OUTGOING',
  'CHIC',
  'CUTE',
  'INTROVERTED',
  'CRUSH',
  'CHUNGCHEONG',
];

const Map<String, PlantPersonality> kPlantPersonalities = {
  'OUTGOING': PlantPersonality(
    label: '활발한 성격',
    tags: ['#긍정적', '#에너지'],
    dialogue: '자 이제 물 줄 시간이야!',
  ),
  'CHIC': PlantPersonality(
    label: '시크한 성격',
    tags: ['#냉소적', '#츤데레'],
    dialogue: '뭘 봐? 물이나 줘.',
  ),
  'CUTE': PlantPersonality(
    label: '귀여운 성격',
    tags: ['#애교', '#사랑둥이'],
    dialogue: '새싹이 물 먹고시포!',
  ),
  'INTROVERTED': PlantPersonality(
    label: '소심한 성격',
    tags: ['#내성적', '#눈치'],
    dialogue: '저..물 좀 주시면..안될까요..?',
  ),
  'CRUSH': PlantPersonality(
    label: '짝사랑 성격',
    tags: ['#미연시', '#적극적'],
    dialogue: '물 줄래, 나랑 사귈래',
  ),
  'CHUNGCHEONG': PlantPersonality(
    label: '충청도 성격',
    tags: ['#느긋한', '#구수한'],
    dialogue: '말라죽겄슈',
  ),
};
