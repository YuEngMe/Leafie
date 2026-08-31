import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

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
          Text(
            message,
            style: kSmallStyle.copyWith(
              fontSize: 14.758,
              color: kBubbleGreen,
              height: 1,
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
  });

  /// 막대 높이와 컴포넌트 높이(2435:16764).
  static const double barHeight = 11;
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
          Positioned(
            right: 0,
            top: 51,
            child: Text(
              maxLabel,
              style: kCaptionStyle.copyWith(color: kBubbleGreen, height: 1),
            ),
          ),
          // 마커는 현재값 끝에 매달린다. 폭 71.6의 절반만큼 왼쪽으로 당긴다.
          Positioned(
            left: 0,
            right: 0,
            top: 50.954,
            height: 24.261,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: currentRatio,
              child: Align(
                alignment: Alignment.centerRight,
                child: Transform.translate(
                  offset: const Offset(35.8, 0),
                  child: _GaugeMarker(label: currentLabel),
                ),
              ),
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

class _GaugeMarker extends StatelessWidget {
  const _GaugeMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 71.604,
      height: 24.261,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kBackgroundWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 3)],
      ),
      child: Text(
        label,
        style: kCaptionStyle.copyWith(
          fontSize: 7.412,
          color: kBubbleGreen,
          height: 1,
        ),
      ),
    );
  }
}
