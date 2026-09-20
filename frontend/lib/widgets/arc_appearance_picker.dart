import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Infinite, snapping arc picker shared by colour and hair catalogues.
///
/// 유한 PageView 대신 양방향 무한 순환으로 동작한다. 실제 아이템은
/// [labels] 개수만큼이지만, PageView의 itemCount를 무한(null)으로 두고
/// `page % labels.length`로 실제 인덱스를 되돌린다. 따라서 마지막 색 다음이
/// 다시 첫 색으로, 첫 색에서 왼쪽으로 밀면 마지막 색으로 계속 이어진다.
///
/// - [initialIndex]는 실제 인덱스(0..labels.length-1). 진입 시 그 색이 중앙에
///   오도록, 큰 기준값(_kBaseCycle * count) 위에 얹어 시작한다.
/// - [onSelected]에는 항상 정규화된 실제 인덱스(0..count-1)만 넘긴다.
/// - [itemBuilder]/Semantics도 정규화된 실제 인덱스로 호출한다.
class ArcAppearancePicker extends StatefulWidget {
  const ArcAppearancePicker({
    super.key,
    required this.labels,
    required this.itemBuilder,
    required this.onSelected,
    this.initialIndex = 0,
    this.arcRadius = 360,
  });
  final List<String> labels;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onSelected;
  final int initialIndex;

  /// 색 원들이 따라 도는 궤도 원의 반지름(px). 디자이너 피드백대로 카루셀
  /// 아치가 뒤 배경 반원의 곡률과 맞아야 자연스럽다 — 배경 원이 클수록(완만)
  /// R을 크게, 작을수록 R을 작게 넘긴다. 기본값 360은 등록 화면의 넓은
  /// 반원(BorderRadius.vertical top 100 + 화면 폭) 기준이고, 편집 화면은
  /// 지름 443 원(반지름 ≈ 221)에 맞춘 값을 넘긴다.
  final double arcRadius;
  @override
  State<ArcAppearancePicker> createState() => _ArcPickerState();
}

class _ArcPickerState extends State<ArcAppearancePicker> {
  // 무한 순환의 중앙 기준. 어느 방향으로 오래 밀어도 페이지 인덱스가
  // 음수/오버플로로 새지 않도록 넉넉한 배수에서 시작한다.
  static const int _kBaseCycle = 1000;

  // 시안 4534-536: 한 화면에 중앙 1개 + 양옆 2~3개가 아치로 담긴다.
  // 값을 낮추면 뷰포트당 아이템이 좁아져 더 많은 원이 작게 보이고,
  // 양옆 원이 화면 밖으로 심하게 잘리지 않는다. 원 궤도 x 보정도 이
  // 간격(뷰포트폭 * fraction)을 기준으로 계산하므로 상수로 공유한다.
  static const double _kViewportFraction = 0.2;

  int get _count => widget.labels.length;
  int get _initialPage => _kBaseCycle * _count + widget.initialIndex;

  late final _controller = PageController(
    initialPage: _initialPage,
    viewportFraction: _kViewportFraction,
  );
  // 현재 선택된 실제 인덱스(0..count-1)만 보관한다.
  late int _index = widget.initialIndex;
  // 컨트롤러가 아직 붙지 않은 초기 프레임에서 아치 곡선을 그리려면 기준이
  // 될 절대 페이지값이 필요하다(_index는 0..count-1이라 절대 위치와 다르다).
  // 초기엔 _initialPage, 이후엔 선택된 절대 페이지를 유지한다.
  late double _pageEstimate = _initialPage.toDouble();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // onPageChanged/onTap이 넘기는 값은 무한 순환의 절대 페이지 인덱스다.
  // 표시·콜백에는 반드시 % count로 정규화한 실제 인덱스를 쓴다.
  void _select(int page) {
    final real = page % _count;
    setState(() {
      _index = real;
      _pageEstimate = page.toDouble();
    });
    HapticFeedback.selectionClick();
    widget.onSelected(real);
  }

  @override
  Widget build(BuildContext context) {
    // 원 궤도 x 보정 기준이 되는 인접 페이지 간 픽셀 간격.
    final pageWidth = MediaQuery.sizeOf(context).width * _kViewportFraction;
    // 인접 페이지(거리 1)의 원호 수평 이동량이 이 간격과 딱 맞도록 한 스텝
    // 각도를 잡는다: R*sin(dθ) = pageWidth → dθ = asin(pageWidth/R). 그러면
    // 바로 옆 원은 PageView 선형 위치와 어긋나지 않고, 멀어질수록만 원 안쪽
    // 으로 당겨져(x 보정 음수) 색 원들이 배경 원의 호를 따라 돈다.
    final anglePerStep = math.asin(
      math.min(0.98, pageWidth / widget.arcRadius),
    );
    return SizedBox(
      height: 130,
      child: PageView.builder(
        controller: _controller,
        // itemCount 무한 → 양방향 순환.
        onPageChanged: _select,
        itemBuilder: (context, index) {
          final real = index % _count;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final page =
                  _controller.hasClients &&
                      _controller.position.hasContentDimensions
                  ? _controller.page ?? _pageEstimate
                  : _pageEstimate;
              // 인접 페이지끼리의 상대 거리는 절대 페이지 값으로 계산해야
              // 무한 순환에서도 자연스럽다(정규화하지 않는다). 부호까지
              // 살려 좌우 x 보정 방향을 맞춘다.
              final signed = index - page;
              final distance = signed.abs();
              // 시안 4534-536: 중앙(distance 0)이 가장 크고, 멀어질수록
              // 작아진다. 거리 1당 약 26%씩 줄이되 0.42까지만 축소해 맨 끝
              // 원도 알아볼 수 있게 남긴다. (중앙 원 지름 72 → 링 포함 78,
              // 양옆 ~53, 그 바깥 ~39.)
              final scale = math.max(0.42, 1 - distance * 0.26);
              // 아치를 실제 원 궤도로: 색 원 중심이 반지름 arcRadius인 원의
              // 호를 따라간다. 중앙(θ=0)은 호의 꼭대기, 좌우로 갈수록 각도가
              // 벌어지며 원을 따라 내려간다.
              //   y(아래로) = R - R*cosθ = R*(1 - cosθ)
              //   x(원호) = R*sinθ  →  PageView 선형 위치(pageWidth*distance)
              //             와의 차이만 보정으로 얹는다.
              // dip은 44px에서 멈춰 아래 체크 원/문구와 겹치지 않게 한다.
              final theta = distance * anglePerStep;
              final dip = math.min(
                44.0,
                widget.arcRadius * (1 - math.cos(theta)),
              );
              final arcX = widget.arcRadius * math.sin(theta);
              final xCorrection =
                  (arcX - pageWidth * distance) * (signed < 0 ? -1 : 1);
              return Transform.translate(
                offset: Offset(xCorrection, dip),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Semantics(
                    label: widget.labels[real],
                    button: true,
                    selected: real == _index,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // 탭한 위젯 자체가 현재 근처의 그 실제 색이므로,
                        // 절대 페이지 index로 그대로 이동하면 최단 거리다.
                        _select(index);
                        if (MediaQuery.disableAnimationsOf(context)) {
                          _controller.jumpToPage(index);
                        } else {
                          _controller.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      child: Transform.scale(
                        scale: scale,
                        // 원 자체 크기는 화면 쪽 itemBuilder가 그리지만,
                        // 기준 박스를 72로 두고 거리별 scale로 축소해
                        // "중앙 크고 양옆 작은" 배치를 위젯에서 담당한다.
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: widget.itemBuilder(context, real),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
