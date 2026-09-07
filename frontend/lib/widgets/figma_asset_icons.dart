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

/// Figma section 3436:4296의 홈 전용 아이콘.
///
/// 그림자 필터까지 보존되도록 Figma SVG 원본을 투명 PNG로 렌더링해 사용한다.
enum FigmaHomeIcon {
  notification('assets/images/icon_home_notification.png', Size(28, 31), '알림'),
  mailbox('assets/images/icon_home_mailbox.png', Size(84.0994, 130), '우체통'),
  sun('assets/images/icon_home_sun.png', Size(83.1301, 82.3485), '해'),
  afternoon('assets/images/icon_home_afternoon.png', Size(76, 76), '오후 해'),
  moon('assets/images/icon_home_moon.png', Size(65.0887, 79), '달'),
  environmentCheck(
    'assets/images/icon_home_check.png',
    Size(35, 35),
    '조도 습도 확인',
  );

  const FigmaHomeIcon(this.asset, this.figmaSize, this.label);

  final String asset;
  final Size figmaSize;
  final String label;
}

class FigmaHomeAssetIcon extends StatelessWidget {
  const FigmaHomeAssetIcon(this.icon, {super.key, this.color});

  final FigmaHomeIcon icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: icon.label,
    image: true,
    child: Image.asset(
      icon.asset,
      width: icon.figmaSize.width,
      height: icon.figmaSize.height,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
    ),
  );
}

/// Figma 3436:4357. 홈 전체보기와 진단 전환 컨트롤.
class FigmaHomeViewSwitch extends StatelessWidget {
  const FigmaHomeViewSwitch({
    super.key,
    this.onOverviewTap,
    this.onDiagnosisTap,
  });

  static const Size figmaSize = Size(45, 117);

  final VoidCallback? onOverviewTap;
  final VoidCallback? onDiagnosisTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '전체보기와 진단 전환',
      container: true,
      child: Container(
        width: figmaSize.width,
        height: figmaSize.height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(35),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 7.87,
              top: 9.23,
              child: Image.asset(
                'assets/images/icon_home_view_all.png',
                width: 29.256,
                height: 28.775,
              ),
            ),
            Positioned(
              left: 11.5,
              top: 65,
              child: Image.asset(
                'assets/images/icon_home_view_diagnosis.png',
                width: 22,
                height: 32,
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: 45,
              height: 58.5,
              child: Semantics(
                label: '전체보기',
                button: true,
                child: GestureDetector(
                  key: const ValueKey('home-overview-switch'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onOverviewTap,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 58.5,
              width: 45,
              height: 58.5,
              child: Semantics(
                label: '진단',
                button: true,
                child: GestureDetector(
                  key: const ValueKey('home-diagnosis-switch'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onDiagnosisTap,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma 컴포넌트 3628:2411의 하단 네비게이션 아이콘 넷.
///
/// 디자이너가 2026-09-05에 넣었다. 시안은 알약 배경도 라벨도 없이 아이콘만
/// 놓는다. 셋은 내보낸 SVG 그대로이고, 다이어리(3173:87)만 도형 조합이라
/// 오렌지 사각형 다섯 개를 골라 다시 묶었다.
enum FigmaNavIcon {
  home('assets/images/icon_nav_home.svg', Size(37, 35), '홈'),
  diary('assets/images/icon_nav_diary.svg', Size(31, 33), '기록'),
  calendar('assets/images/icon_nav_calendar.svg', Size(32, 35), '달력'),
  my('assets/images/icon_nav_my.svg', Size(29, 32), '마이');

  const FigmaNavIcon(this.asset, this.figmaSize, this.label);

  final String asset;
  final Size figmaSize;

  /// 시안에는 글자가 없지만 화면 읽기 프로그램에는 이름이 필요하다.
  final String label;
}

/// 네비게이션 아이콘 하나. 시안(3628:2411)은 선택 상태를 따로 그리지 않아
/// 넷이 같은 오렌지다.
class FigmaBottomNavIcon extends StatelessWidget {
  const FigmaBottomNavIcon(this.icon, {super.key});

  final FigmaNavIcon icon;

  @override
  Widget build(BuildContext context) => Semantics(
    label: icon.label,
    button: true,
    container: true,
    child: _AssetIcon(asset: icon.asset, size: icon.figmaSize),
  );
}

/// Figma node 3345:996 `Polygon 4 (Stroke)`. 앱바 뒤로가기 꺾쇠.
///
/// 디자이너가 2026-09-05에 교체했다. 끝이 둥글고 꼭짓점이 살짝 뭉툭해
/// 좌표로 옮기면 근사치가 되므로 에셋으로 둔다.
class FigmaBackChevron extends StatelessWidget {
  const FigmaBackChevron({super.key, this.color});

  static const Size figmaSize = Size(11.4824, 18.0019);
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/icon_back_chevron.svg',
    width: figmaSize.width,
    height: figmaSize.height,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
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
