import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_layout.dart';

/// 디자이너가 내보낸 아이콘 PNG를 그대로 쓰는 위젯들.
///
/// 형태가 곧 자산인 로고나, 곡선·겹침이 있어 좌표로 옮기면 근사치가 되는
/// 아이콘은 직접 그리지 않는다. 단색 도형에 색만 바꿔 쓰는 아이콘은
/// figma_glyphs.dart에 CustomPainter로 남겨 두었다.
class _AssetIcon extends StatelessWidget {
  const _AssetIcon({required this.asset, required this.size});

  final String asset;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(asset, width: size.width, height: size.height);
  }
}

/// Figma node 3345:996 `Polygon 4 (Stroke)`. 앱바 뒤로가기 꺾쇠.
///
/// 디자이너가 2026-09-05에 교체했다. 끝이 둥글고 꼭짓점이 살짝 뭉툭해
/// 좌표로 옮기면 근사치가 되므로 에셋으로 둔다.
class FigmaBackChevron extends StatelessWidget {
  const FigmaBackChevron({super.key});

  static const Size figmaSize = Size(11.4824, 18.0019);

  @override
  Widget build(BuildContext context) => const _AssetIcon(
    asset: 'assets/images/icon_back_chevron.svg',
    size: figmaSize,
  );
}

/// Figma node 2346:2536. 홈 조도·습도 카드의 물방울 아이콘.
class FigmaMoistureIcon extends StatelessWidget {
  const FigmaMoistureIcon({super.key});

  static const Size figmaSize = Size(34.97, 33.35);

  @override
  Widget build(BuildContext context) => const _AssetIcon(
    asset: 'assets/images/icon_moisture.svg',
    size: figmaSize,
  );
}

/// Figma node 2318:3742. 식물 검색의 사진 촬영 버튼.
class FigmaCameraIcon extends StatelessWidget {
  const FigmaCameraIcon({super.key});

  static const Size figmaSize = Size(27, 22.22);

  @override
  Widget build(BuildContext context) =>
      const _AssetIcon(asset: 'assets/images/icon_camera.svg', size: figmaSize);
}

/// Figma node 2318:3726. 식물 검색 돋보기.
class FigmaSearchIcon extends StatelessWidget {
  const FigmaSearchIcon({super.key});

  static const Size figmaSize = Size(24.91, 24.91);

  @override
  Widget build(BuildContext context) =>
      const _AssetIcon(asset: 'assets/images/icon_search.svg', size: figmaSize);
}

/// Figma node 2353:41 / 2353:39. 소셜 로그인 버튼.
class FigmaSocialButton extends StatelessWidget {
  const FigmaSocialButton.naver({super.key, required this.onTap})
    : _asset = 'assets/images/social_naver.svg',
      _label = '네이버로 로그인';

  const FigmaSocialButton.kakao({super.key, required this.onTap})
    : _asset = 'assets/images/social_kakao.svg',
      _label = '카카오톡으로 로그인';

  final String _asset;
  final String _label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: _label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SvgPicture.asset(
          _asset,
          width: AppLayout.loginSocialButtonSize,
          height: AppLayout.loginSocialButtonSize,
        ),
      ),
    );
  }
}
