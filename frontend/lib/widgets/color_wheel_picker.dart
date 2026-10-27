import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_appearance_colors.dart';
import 'package:yeso_plant/widgets/svg_drop_shadow.dart';

/// 캐릭터 꾸미기 컬러 휠. 시안 4534:507(등록)과 5038:6460(편집)이 같은
/// 묶음(5038:6392 / 5038:6533)을 쓴다: 지름 443 흰 원판 위 '컬러' 라벨과
/// 주황 호, 원판 둘레를 도는 60px 색 원 10개, 꼭대기에 고정된 회색 선택 링,
/// 가운데 아래 주황 체크 배지.
///
/// 꼭대기(링 안)에 온 색이 고른 색이다. 휠을 가로로 밀면 돌고, 손을 떼면
/// 가장 가까운 칸에 멈춘다. 색 원을 누르면 그 색이 꼭대기로 돌아온다.
/// 체크 배지가 확정 버튼이다(시안에 하단 버튼이 없다).
///
/// 위젯 좌표는 시안 화면 좌표에서 [top](576)을 뺀 값이고, 높이는 화면
/// 바닥(874)까지다. 놓는 쪽이 이 위젯의 위를 화면 y=576에 맞춘다.
class ColorWheelPicker extends StatefulWidget {
  const ColorWheelPicker({
    super.key,
    required this.initialIndex,
    required this.onSelected,
    required this.confirmLabel,
    required this.onConfirm,
    this.colors = kPlantAppearanceColors,
  });

  /// 시안 묶음 5038:6392의 화면 y. 원판(Ellipse 1168) 위끝이다.
  static const double top = 576;

  /// 묶음 위끝에서 화면 바닥(874)까지.
  static const double height = 874 - top;

  final List<PlantAppearanceColor> colors;

  /// 처음 꼭대기에 둘 색의 인덱스(0..colors.length-1).
  final int initialIndex;

  /// 꼭대기 색이 바뀌거나 색 원을 눌렀을 때 그 색 인덱스를 넘긴다.
  final ValueChanged<int> onSelected;

  /// 체크 배지의 접근성 이름(등록 '선택 완료', 편집 '적용하기').
  final String confirmLabel;

  /// null이면 체크 배지를 흐리게 그리고 눌러도 아무 일도 하지 않는다.
  final VoidCallback? onConfirm;

  @override
  State<ColorWheelPicker> createState() => _ColorWheelPickerState();
}

// 시안 색 원 자리(화면 좌표, 원 중심). 5038:6395(위 반쪽)는 x=33 y=625
// 335x155 안의 r=30 원 5개이고, 5038:6401(아래 반쪽)은 같은 묶음을 위아래로
// 뒤집어 y=805에 둔 것이다. 꼭대기에서 시계 방향으로 0..9번 칸이며, 시안의
// 색 배치(옐로 꼭대기 → 라이트 그린 → 그린 → 스카이 …)가 팔레트 순서와 같다.
// 정확한 원이 아니라(꼭대기·바닥 반지름 137.5, 옆 칸 약 143.5) 디자이너가
// 손으로 놓은 자리다. 멈춰 있을 때 시안과 같도록 칸 자리를 그대로 쓰고, 칸
// 사이는 회전 중심 기준 각도·반지름을 선형 보간한다.
const List<Offset> _kSlotCenters = [
  Offset(200, 655),
  Offset(288, 679),
  Offset(338, 750),
  Offset(338, 835),
  Offset(288, 906),
  Offset(200, 930),
  Offset(112, 906),
  Offset(63, 835),
  Offset(63, 750),
  Offset(112, 679),
];

// 회전 중심: 꼭대기(655)와 바닥(930) 칸의 가운데.
const Offset _kHub = Offset(_kHubX, 792.5);
const double _kHubX = 200;
const double _kSwatchSize = 60;

// 꼭대기 칸과 옆 칸의 가로 간격(200 → 288). 이만큼 밀면 한 칸 돈다.
const double _kPxPerSlot = 88;

// 손을 뗄 때 이보다 빠르면(px/s) 튕긴 것으로 보고 관성으로 더 돈다.
const double _kFlingMinVelocity = 300;

// 관성으로 더 도는 거리 = 손을 뗀 속도 × 이 시간. 2500px/s면 약 8.5칸.
const double _kGlideSeconds = 0.3;

// 원판 Ellipse 1168: x=-21 y=576 443x439, 흰색, 그림자 stdDeviation 2 · 18%.
const double _kPaletteLeft = -21;
const double _kPaletteWidth = 443;
const double _kPaletteHeight = 439;

// 선택 링 Ellipse 455: x=163 y=618 74x74, #CCCBCB 굵기 4.
const double _kRingSize = 74;

// '컬러' 라벨 5038:6413: 12 Regular #FFA13E, 글자 상자 x 189..211 y 594..608.
const double _kLabelCenterY = 601;

// 주황 호 5038:6414: x=143.5 y=583.34 115.001x10.2969.
const double _kArcLeft = 143.5;
const double _kArcTop = 583.34;
const double _kArcWidth = 115.001;
const double _kArcHeight = 10.2969;

// 아래 흰 그라데이션 5038:6458: 화면 바닥에서 87, 폭 407 가운데.
const double _kFadeHeight = 87;
const double _kFadeWidth = 407;

// 체크 배지 5038:6407: 원 38x38이 x=181 y=777. SVG는 그림자까지 46x46.
const double _kCheckLeft = 181 - 4;
const double _kCheckTop = 777 - 4;
const double _kCheckSize = 46;

typedef _Polar = ({double angle, double radius});

// 칸 자리를 회전 중심 기준 (시계 방향 각도, 반지름)으로 바꿔 둔다.
final List<_Polar> _kSlotPolars = [
  for (final c in _kSlotCenters)
    (angle: _clockwiseAngle(c - _kHub), radius: (c - _kHub).distance),
];

double _clockwiseAngle(Offset d) {
  final a = math.atan2(d.dx, -d.dy);
  return a < 0 ? a + 2 * math.pi : a;
}

class _ColorWheelPickerState extends State<ColorWheelPicker>
    with SingleTickerProviderStateMixin {
  // 꼭대기에 온 색의 연속 인덱스. 3.0이면 colors[3]이 꼭대기에 있다.
  // 한 바퀴를 넘어도 % count로 실제 색을 찾으므로 양방향 무한 회전이다.
  late final AnimationController _rotation = AnimationController.unbounded(
    vsync: this,
    value: widget.initialIndex.toDouble(),
  );

  // 마지막으로 알린(또는 처음) 꼭대기 색 인덱스.
  late int _topIndex = widget.initialIndex;

  int get _count => widget.colors.length;

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  int _wrap(int i) => i % _count;

  void _notifyIfMoved() {
    final index = _wrap(_rotation.value.round());
    if (index == _topIndex) return;
    _topIndex = index;
    HapticFeedback.selectionClick();
    widget.onSelected(index);
  }

  Future<void> _settle(
    double target, {
    Duration duration = const Duration(milliseconds: 220),
  }) async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _rotation.value = target;
    } else {
      await _rotation.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onDragStart(DragStartDetails _) => _rotation.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    // 오른쪽으로 밀면 꼭대기 색이 오른쪽(시계 방향) 칸으로 가고, 왼쪽 칸의
    // 색이 꼭대기로 온다.
    _rotation.value -= details.delta.dx / _kPxPerSlot;
    _notifyIfMoved();
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    final v = details.velocity.pixelsPerSecond.dx;
    final current = _rotation.value;
    if (v.abs() <= _kFlingMinVelocity) {
      await _settle(current.roundToDouble());
      if (mounted) _notifyIfMoved();
      return;
    }
    // 관성(디자이너 요청 2026-10): 손을 뗀 속도로 [_kGlideSeconds]만큼 더
    // 돈 자리에서 가장 가까운 칸에 멈춘다. 전에는 아무리 세게 밀어도 한
    // 칸만 넘어갔다. 약하게 튕겨도 민 방향으로 최소 한 칸은 넘긴다.
    // 한 번에 최대 한 바퀴까지만 돈다.
    final slotsPerSecond = -v / _kPxPerSlot;
    final projected = (current + slotsPerSecond * _kGlideSeconds)
        .clamp(current - _count, current + _count)
        .roundToDouble();
    final target = slotsPerSecond > 0
        ? math.max(projected, current.ceilToDouble())
        : math.min(projected, current.floorToDouble());
    final distance = (target - current).abs();
    // 도는 동안 지나가는 칸마다 알린다(햅틱이 칸마다 울린다).
    _rotation.addListener(_notifyIfMoved);
    try {
      await _settle(
        target,
        duration: Duration(
          milliseconds: (220 + distance * 70).clamp(220, 900).round(),
        ),
      );
    } finally {
      _rotation.removeListener(_notifyIfMoved);
    }
    if (mounted) _notifyIfMoved();
  }

  void _onTapSwatch(int index) {
    final current = _rotation.value;
    // 가까운 쪽으로 돈다(최대 반 바퀴).
    var delta = (index - current) % _count;
    if (delta > _count / 2) delta -= _count;
    _topIndex = index;
    HapticFeedback.selectionClick();
    // 이미 꼭대기에 있던 색을 눌러도 고른 것으로 알린다(등록 화면은 처음에
    // 아무것도 고르지 않은 상태라 꼭대기 색을 누르는 것도 선택이다).
    widget.onSelected(index);
    _settle((current + delta).roundToDouble());
  }

  Offset _swatchCenter(double slot) {
    final k = slot.floor();
    final t = slot - k;
    final a = _kSlotPolars[k % _count];
    final b = _kSlotPolars[(k + 1) % _count];
    var bAngle = b.angle;
    if (bAngle < a.angle) bAngle += 2 * math.pi;
    final angle = a.angle + (bAngle - a.angle) * t;
    final radius = a.radius + (b.radius - a.radius) * t;
    return _kHub + Offset(radius * math.sin(angle), -radius * math.cos(angle));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 시안 402 폭 기준 x를 화면 폭 가운데에 맞춘다.
        final dx = (constraints.maxWidth - 402) / 2;
        const dy = -ColorWheelPicker.top;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // 손가락이 닿은 곳부터 따라 돌게 해 끌기 시작 문턱만큼 튀지 않게 한다.
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: dx + _kPaletteLeft,
                top: 0,
                width: _kPaletteWidth,
                height: _kPaletteHeight,
                child: const DecoratedBox(
                  decoration: ShapeDecoration(
                    color: kBackgroundWhite,
                    shape: OvalBorder(),
                    shadows: [
                      // stdDeviation 2 → blurRadius 4(다른 SVG 그림자 환산과 같은 규칙).
                      BoxShadow(color: Color(0x2E000000), blurRadius: 4),
                    ],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _rotation,
                builder: (context, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < _count; i++)
                      _buildSwatch(i, Offset(dx, dy)),
                  ],
                ),
              ),
              Positioned(
                left: dx + _kHubX - _kRingSize / 2,
                top: dy + _kSlotCenters[0].dy - _kRingSize / 2,
                width: _kRingSize,
                height: _kRingSize,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kGrayLightest, width: 4),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: dx + _kHubX - 40,
                width: 80,
                top: dy + _kLabelCenterY - 15,
                height: 30,
                child: const Center(
                  child: Text(
                    '컬러',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: kOrangeAccent,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: dx + _kArcLeft,
                top: dy + _kArcTop,
                width: _kArcWidth,
                height: _kArcHeight,
                child: SvgPicture.asset(
                  'assets/images/appearance_color_tab_arc.svg',
                  width: _kArcWidth,
                  height: _kArcHeight,
                ),
              ),
              Positioned(
                left: (constraints.maxWidth - _kFadeWidth) / 2 - 0.5,
                width: _kFadeWidth,
                bottom: 0,
                height: _kFadeHeight,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // 시안 linear-gradient(-0.67deg, 흰 15.47% → 투명 97.53%).
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: [0.15472, 0.97528],
                        colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: dx + _kCheckLeft,
                top: dy + _kCheckTop,
                width: _kCheckSize,
                height: _kCheckSize,
                child: GestureDetector(
                  key: const ValueKey('appearance_confirm'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onConfirm,
                  child: Semantics(
                    button: true,
                    enabled: widget.onConfirm != null,
                    label: widget.confirmLabel,
                    child: Opacity(
                      // 시안에 꺼진 체크 배지가 없다. 아직 색을 고르지 않아
                      // 확정할 수 없을 때(등록 화면 첫 진입)만 흐리게 둔다.
                      opacity: widget.onConfirm == null ? 0.4 : 1,
                      child: SvgDropShadow(
                        stdDeviation: 2,
                        opacity: 0.2,
                        child: SvgPicture.asset(
                          'assets/images/plants_appearance_check.svg',
                          width: _kCheckSize,
                          height: _kCheckSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwatch(int index, Offset origin) {
    final option = widget.colors[index];
    final slot = (index - _rotation.value) % _count;
    final center = _swatchCenter(slot) + origin;
    return Positioned(
      left: center.dx - _kSwatchSize / 2,
      top: center.dy - _kSwatchSize / 2,
      width: _kSwatchSize,
      height: _kSwatchSize,
      child: Semantics(
        label: option.label,
        button: true,
        selected: index == _wrap(_rotation.value.round()),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onTapSwatch(index),
          child: DecoratedBox(
            // 테스트가 이 이름으로 색 원을 찾는다(appearance_color_<id>).
            key: ValueKey('appearance_${option.id}'),
            decoration: BoxDecoration(
              color: option.color,
              shape: BoxShape.circle,
              // 색 원 둘레의 옅은 그림자. 시안 SVG 내보내기(5038:6395)에는
              // 효과가 빠져 있어, 시안 PNG의 가장자리 밝기(1·2·3px 바깥
              // 231·243·250)를 원판 그림자(18%)와 비교해 25%로 맞췄다.
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
