import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/plant_detail_components.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 시안 2568:1764(컬러 탭) / 2568:1814(헤어 탭) "캐릭터 상세_꾸미기".
///
/// 큰 흰 원(2568:1796, x=-25 y=576 443x443) 위에 스와치 6개를 원호로 놓고,
/// 아래 주황 체크 원(2568:1811, x=182 y=760 38x38)이 적용 버튼을 겸한다.
/// 앱이 쓰던 바텀시트(9개 스와치 Wrap + '적용하기' 버튼)는 이 화면으로 바뀌었다.

/// 2568:1797 스와치 6개. 프레임(x=45 y=630 303x171) 안 원 중심 좌표를
/// 프레임 절대 좌표로 편 값이다. 지름 60, 선택되면 링 포함 74.
class _AppearanceSwatch {
  const _AppearanceSwatch(this.id, this.color, this.centerX, this.centerY);

  /// PATCH /plants/{id}/appearance의 color_id.
  final String id;
  final Color color;

  /// 시안 프레임 절대 좌표(원 중심).
  final double centerX;
  final double centerY;
}

// 2568:1798~1803. 색은 SVG 원본 fill 값 그대로다. 원호 아래 가운데는
// 스와치가 아니라 적용을 겸하는 체크 버튼(2568:1811) 자리라 비워 둔다.
const _kSwatches = [
  _AppearanceSwatch('color_mint_01', Color(0xFFBAEEDC), 45 + 151, 630 + 37),
  _AppearanceSwatch('color_purple_01', Color(0xFFE0B2FF), 45 + 64, 630 + 67),
  _AppearanceSwatch('color_red_01', Color(0xFFFF9B9B), 45 + 238, 630 + 67),
  _AppearanceSwatch('color_orange_01', Color(0xFFFFDC9C), 45 + 30, 630 + 141),
  _AppearanceSwatch('color_pink_01', Color(0xFFFFCADC), 45 + 273, 630 + 141),
];

const double _kSwatchDiameter = 60;
const double _kSwatchSelectedDiameter = 74;

/// 2568:1796. 팔레트 큰 원.
const double _kPaletteLeft = -25;
const double _kPaletteTop = 576;
const double _kPaletteSize = 443;

class PlantEditAppearanceScreen extends StatefulWidget {
  const PlantEditAppearanceScreen({
    super.key,
    required this.plant,
    required this.repository,
  });

  final ManagedPlant plant;
  final PlantManagementRepository repository;

  @override
  State<PlantEditAppearanceScreen> createState() =>
      _PlantEditAppearanceScreenState();
}

class _PlantEditAppearanceScreenState extends State<PlantEditAppearanceScreen> {
  late String _selectedColorId = widget.plant.colorId;
  int _activeTab = 0;
  bool _busy = false;

  Future<void> _apply() async {
    if (_selectedColorId == widget.plant.colorId) {
      Navigator.of(context).pop(widget.plant);
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await widget.repository.updateAppearance(
        widget.plant.id,
        colorId: _selectedColorId,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '캐릭터 꾸미기'),
      body: PlantDetailBody(
        children: [
          // 헤드라인 2568:1874. top 140, 21/w600 진한 텍스트.
          const PlantDetailPositioned(
            top: 140,
            height: 25,
            child: Center(child: Text('식물을 꾸며주세요!', style: kTitleStyle)),
          ),
          // 캐릭터 미리보기 2568:1785. x=103 y=287 196x168.
          PlantDetailPositioned(
            top: 287,
            height: 168,
            child: Center(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: PlantCharacterArt(width: plantArtWidthFor(196)),
              ),
            ),
          ),
          // 팔레트 큰 원 2568:1796.
          Positioned(
            left: _kPaletteLeft,
            top: _kPaletteTop - PlantDetailBody.appBarBand,
            width: _kPaletteSize,
            height: _kPaletteSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kBackgroundWhite,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8E8E8)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),
          // 탭 2568:1806/1807. 글자 x=159/211 y=595, 12px.
          // 밑줄 인디케이터 2568:1808. x=141 y=584 112x8.
          Positioned(
            left: 141 - 1.5,
            top: 584 - 1.5 - PlantDetailBody.appBarBand,
            width: 115.001,
            height: 11.001,
            child: CustomPaint(
              painter: _TabIndicatorPainter(activeTab: _activeTab),
            ),
          ),
          _tabLabel(left: 159, label: '컬러', index: 0),
          _tabLabel(left: 211, label: '헤어', index: 1),
          if (_activeTab == 0)
            for (final swatch in _kSwatches) _swatch(swatch)
          else
            // 헤어 탭(2568:1857~1861)은 아이템 PNG 5종이 필요한데 에셋이
            // 아직 없다.
            // TODO(design): 헤어 아이템 PNG와 PATCH의 hair_id 값이 정해지면
            // 컬러 탭과 같은 원호에 얹는다.
            PlantDetailPositioned(
              top: 700,
              height: 20,
              child: Center(child: Text('헤어 꾸미기는 준비 중이에요', style: kSmallStyle)),
            ),
          // 체크 원 2568:1811. 프레임 x=182 y=760 38x38이지만 SVG는 그림자
          // 때문에 46x46으로 그려진다(원 지름 38, 중심이 프레임 중심).
          Positioned(
            left: 182 - 4,
            top: 760 - 4 - PlantDetailBody.appBarBand,
            width: 46,
            height: 46,
            child: GestureDetector(
              key: const ValueKey('appearance_confirm'),
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : _apply,
              child: Semantics(
                button: true,
                label: '적용하기',
                child: SvgPicture.asset(
                  'assets/images/plants_appearance_check.svg',
                  width: 46,
                  height: 46,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabLabel({
    required double left,
    required String label,
    required int index,
  }) {
    return Positioned(
      left: left,
      top: 595 - PlantDetailBody.appBarBand,
      width: 22,
      height: 14,
      child: GestureDetector(
        key: ValueKey('appearance_tab_$label'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _activeTab = index),
        child: Center(
          child: Text(
            label,
            style: kCaptionStyle.copyWith(
              // 2568:1806 활성은 #FFA13E, 비활성은 연한 텍스트.
              color: _activeTab == index ? kOrangeAccent : kTextLight,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _swatch(_AppearanceSwatch swatch) {
    final selected = _selectedColorId == swatch.id;
    final diameter = selected ? _kSwatchSelectedDiameter : _kSwatchDiameter;
    return Positioned(
      left: swatch.centerX - diameter / 2,
      top: swatch.centerY - diameter / 2 - PlantDetailBody.appBarBand,
      width: diameter,
      height: diameter,
      child: GestureDetector(
        key: ValueKey('appearance_${swatch.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedColorId = swatch.id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: swatch.color,
            shape: BoxShape.circle,
            // 2568:1799 선택 링은 검정 15%, 굵기 4.
            border: selected
                ? Border.all(color: const Color(0x26000000), width: 4)
                : null,
          ),
        ),
      ),
    );
  }
}

/// 2568:1808. 탭 밑줄은 직선이 아니라 위로 볼록한 곡선 두 겹이다.
/// 회색 전체(Vector 1209) 위에 활성 반쪽만 오렌지(Vector 1210)로 덮는다.
/// SVG는 왼쪽 반쪽만 칠해진 한 장뿐이라, 헤어 탭에서는 좌우를 뒤집어야
/// 해서 같은 곡선을 직접 그린다.
class _TabIndicatorPainter extends CustomPainter {
  const _TabIndicatorPainter({required this.activeTab});

  final int activeTab;

  /// SVG viewBox 115.001 x 11.001 기준 좌표.
  static const double _vbWidth = 115.001;
  static const double _vbHeight = 11.001;

  /// d="M1.5 9.5 C ... 57.5 1.5 ... 113.5 9.5" 를 2차 곡선 둘로 옮긴다.
  /// halfOnly면 왼쪽 반쪽(활성 표시)만 그린다.
  Path _curve({required bool halfOnly}) {
    final path = Path()..moveTo(1.5, 9.5);
    path.quadraticBezierTo(20.9, 1.45, 57.5, 1.5);
    if (!halfOnly) path.quadraticBezierTo(94.2, 1.55, 113.5, 9.5);
    return path;
  }

  Paint _stroke(Color color) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..color = color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _vbWidth, size.height / _vbHeight);
    canvas.drawPath(_curve(halfOnly: false), _stroke(kProgressInactive));
    // 헤어 탭은 오른쪽 반쪽이 활성이라 곡선을 좌우로 뒤집어 덮는다.
    if (activeTab != 0) {
      canvas.translate(_vbWidth, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(_curve(halfOnly: true), _stroke(kOrangeMain));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TabIndicatorPainter oldDelegate) =>
      oldDelegate.activeTab != activeTab;
}
