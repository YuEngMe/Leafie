import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/svg_drop_shadow.dart';

/// Figma node 2346:2370. 물주기 같은 돌봄을 요청하는 홈 말풍선.
///
/// 붉은 점과 문구가 흰 pill 안에 나란히 놓인다. 교감 말풍선(2346:2375)과는
/// 점 유무·색·크기가 모두 달라 별개 위젯으로 둔다.
class PlantRequestBubble extends StatelessWidget {
  const PlantRequestBubble({super.key, required this.message});

  static const double height = 41;
  static const double dotSize = 8.1878;

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: kBackgroundWhite,
        borderRadius: BorderRadius.circular(50),
        boxShadow: const [
          BoxShadow(color: Color(0x2E000000), blurRadius: 3.69),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: dotSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kBubbleDot,
              ),
            ),
          ),
          const SizedBox(width: 5),
          // 서버 대사는 성격마다 길이가 달라 화면을 넘으면 말줄임한다.
          Flexible(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kSmallStyle.copyWith(
                fontSize: 14.758,
                color: kBubbleGreen,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma component set 2435:16798의 습도·조도 게이지.
///
/// 회색 트랙 위에 선호 범위 그라디언트를 깔고, 그 위에 현재값을 얹는다.
enum EnvironmentGaugeKind {
  /// 2435:16764. 파랑 계열 현재값.
  humidity(
    label: '현재 습도',
    currentGradient: [Color(0xFF94EFFF), Color(0xFF4DD6CB)],
  ),

  /// 2435:16765. 주황 계열 현재값.
  light(
    label: '현재 조도',
    currentGradient: [Color(0xFFFFCA67), Color(0xFFFF7E23)],
  );

  const EnvironmentGaugeKind({
    required this.label,
    required this.currentGradient,
  });

  final String label;
  final List<Color> currentGradient;
}

class EnvironmentGauge extends StatelessWidget {
  const EnvironmentGauge({
    super.key,
    required this.kind,
    required this.description,
    required this.currentRatio,
    required this.comfortRatio,
    required this.currentLabel,
    required this.maxLabel,
    this.alert = false,
  });

  /// 막대 높이와 컴포넌트 높이(2435:16764).
  static const double barHeight = 11;

  /// 마커 폭(71.6)과 오른쪽 끝 수치("100%")가 차지하는 폭.
  static const double _markerWidth = 71.604;
  static const double _maxLabelWidth = 32;
  static const double height = 75.215;

  final EnvironmentGaugeKind kind;

  /// "새싹이는 40 - 70% 습도를 좋아해요"처럼 완성된 문구를 받는다.
  final String description;

  // TODO(design): 시안은 '현재조도 10%'인데 막대가 17.7%를 채운다. 표시값과
  // 폭이 어긋나 호출부가 준 비율을 그대로 쓴다. 디자이너 확인 필요.
  /// 0~1. 막대에서 현재값과 선호 범위가 차지하는 비율.
  final double currentRatio;
  final double comfortRatio;

  /// 마커 안 문구와 우측 끝 수치.
  final String currentLabel;
  final String maxLabel;

  /// 현재값이 부족하면 마커 글자 앞에 빨간 점을 찍는다.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Text(kind.label, style: kItemStyle),
          ),
          Positioned(
            left: 72.626,
            top: 6,
            child: Text(
              description,
              style: kCaptionStyle.copyWith(
                fontSize: 10,
                color: kTextDark,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 35,
            height: barHeight,
            child: _GaugeBar(
              kind: kind,
              currentRatio: currentRatio,
              comfortRatio: comfortRatio,
            ),
          ),
          // 마커는 현재값 끝에 가운데를 맞춘다. 값이 양 끝에 가까우면 막대
          // 밖으로 나가지 않게 안쪽으로 붙이고, 오른쪽 끝 수치와 겹치면 그
          // 수치는 숨긴다(예: 조도 120%).
          Positioned(
            left: 0,
            right: 0,
            top: 50.954,
            height: 24.261,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final left = (width * currentRatio - _markerWidth / 2).clamp(
                  0.0,
                  width - _markerWidth,
                );
                final hidesMax = left + _markerWidth > width - _maxLabelWidth;
                return Stack(
                  children: [
                    if (!hidesMax)
                      Positioned(
                        right: 0,
                        top: 51 - 50.954,
                        child: Text(
                          maxLabel,
                          style: kCaptionStyle.copyWith(
                            color: kBubbleGreen,
                            height: 1,
                          ),
                        ),
                      ),
                    Positioned(
                      left: left,
                      top: 0,
                      child: _GaugeMarker(label: currentLabel, alert: alert),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeBar extends StatelessWidget {
  const _GaugeBar({
    required this.kind,
    required this.currentRatio,
    required this.comfortRatio,
  });

  final EnvironmentGaugeKind kind;
  final double currentRatio;
  final double comfortRatio;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(50);
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: kGaugeTrack, borderRadius: radius),
          child: const SizedBox.expand(),
        ),
        // 선호 범위: 연한 연두에서 애플그린으로.
        FractionallySizedBox(
          widthFactor: comfortRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                colors: [kGaugeComfortStart, kAppleGreen],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        FractionallySizedBox(
          widthFactor: currentRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(colors: kind.currentGradient),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

/// 시안 4534:7933 / 4534:7947. 위로 꼬리가 난 흰 알약(SVG, 그림자 여백
/// 5.895 포함)에 현재값을 적는다. 알약은 노드 71.6×24.26의 아래쪽 18.94
/// (y 5.32~24.26)이고 꼬리 끝이 노드 위 가운데에 닿는다.
class _GaugeMarker extends StatelessWidget {
  const _GaugeMarker({required this.label, this.alert = false});

  /// SVG 그림자 여백(stdDeviation 2.9475 × 2).
  static const double _shadowInset = 5.895;
  static const double _pillTop = 5.324;

  /// 빨간 점(4534:7952) 지름과 점·글자 사이 간격.
  static const double _dotSize = 5.1145;
  static const double _dotGap = 3.07;

  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: kCaptionStyle.copyWith(
        fontSize: 7.412,
        color: kBubbleGreen,
        height: 1,
      ),
    );
    return SizedBox(
      width: EnvironmentGauge._markerWidth,
      height: 24.261,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -_shadowInset,
            top: -_shadowInset,
            width: EnvironmentGauge._markerWidth + _shadowInset * 2,
            height: 24.261 + _shadowInset * 2,
            child: SvgDropShadow(
              stdDeviation: 2.9475,
              opacity: 0.18,
              child: SvgPicture.asset(
                'assets/images/home_gauge_marker.svg',
                fit: BoxFit.fill,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _pillTop,
            bottom: 0,
            child: Center(
              // 점이 붙어도 글자는 알약 가운데에 둔다(시안 습도·조도 마커
              // 모두 글자 왼쪽 x=13.3). 점 폭만큼 오른쪽에 빈칸을 둬 맞춘다.
              child: alert
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          key: ValueKey('gauge-marker-alert'),
                          dimension: _dotSize,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFF5E5E),
                            ),
                          ),
                        ),
                        const SizedBox(width: _dotGap),
                        text,
                        const SizedBox(width: _dotSize + _dotGap),
                      ],
                    )
                  : text,
            ),
          ),
        ],
      ),
    );
  }
}
