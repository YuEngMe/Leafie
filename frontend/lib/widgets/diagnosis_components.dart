import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_glyphs.dart';
import 'package:yeso_plant/widgets/onboarding_copy.dart';

/// Figma node 2346:2466. 진단 기록이 하나도 없을 때의 안내.
class DiagnosisEmptyState extends StatelessWidget {
  const DiagnosisEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingCopy(
      title: '진단 기록이 없습니다',
      subtitle: '내 식물의 건강을 진단해주세요.',
      textAlign: TextAlign.center,
      crossAxisAlignment: CrossAxisAlignment.center,
    );
  }
}

/// Figma node 2346:2459. 진단 기록 목록의 한 줄.
class DiagnosisRecordTile extends StatelessWidget {
  const DiagnosisRecordTile({
    super.key,
    required this.thumbnail,
    required this.title,
    required this.dateLabel,
    required this.onTap,
  });

  static const double height = 58.196;

  final ImageProvider thumbnail;
  final String title;

  /// "2026. 3. 7 수"처럼 완성된 문구를 그대로 받는다.
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: kBackgroundWhite,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 4)],
        ),
        child: Row(
          children: [
            const SizedBox(width: 7.5),
            ClipOval(
              child: SizedBox.square(
                dimension: 49.29,
                child: Image(image: thumbnail, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 38.5),
            Text(title, style: kBodyStyle.copyWith(color: kDiagnosisTitle)),
            const SizedBox(width: 10),
            Text(dateLabel, style: kCaptionStyle),
            const Spacer(),
            const FigmaChevronRight(color: kChevronGray),
            const SizedBox(width: 9),
          ],
        ),
      ),
    );
  }
}

/// Figma node 2346:2450의 처방전 카드.
///
/// 회색 배경판 위에 흰 카드가 얹히고, 환자 정보·사진·증상·원인 분석·추천
/// 관리가 한 장에 들어간다.
///
// TODO(design): 시안의 장식 세 가지가 아직 비어 있다. 카드 상단 빨간 탭
// (#FF676A), '처방전' 옆 적십자(#F14B4D), 추천 관리 첫 두 원 안의 민트
// 물방울과 노란 원. 앞 두 개는 Figma가 SVG 에셋으로만 내려줘 색을 화면에서
// 실측했고, 원 안 글리프는 FigmaMoistureIcon의 도형을 재사용하면 된다.
class PrescriptionCard extends StatelessWidget {
  const PrescriptionCard({
    super.key,
    required this.photo,
    required this.statusLabel,
    required this.patientRows,
    required this.symptoms,
    required this.causes,
    required this.recommendations,
    required this.onClose,
  });

  static const Size cardSize = Size(378.656, 622);

  final ImageProvider photo;

  /// "조금 관리가 필요해요" 같은 상태 한 줄.
  final String statusLabel;

  /// 환자성명·식물명·생년월일·진단일 네 쌍.
  final List<(String, String)> patientRows;
  final List<String> symptoms;
  final List<PrescriptionCause> causes;
  final List<String> recommendations;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: cardSize,
      child: Stack(
        children: [
          // 뒤 회색판(2346:2379).
          Positioned(
            left: 0,
            top: 45.832,
            width: cardSize.width,
            height: 576.168,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kProgressInactive,
                borderRadius: BorderRadius.circular(20.733),
              ),
            ),
          ),
          // 흰 카드(2346:2380).
          Positioned(
            left: 10.234,
            top: 55.263,
            width: 357.165,
            height: 555.703,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kBackgroundWhite,
                borderRadius: BorderRadius.circular(12.277),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 4.465,
                    offset: Offset(0, 4.465),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 77,
            top: 97,
            height: 32,
            child: Text(
              '처방전',
              style: kTitleStyle.copyWith(
                fontSize: 27.189,
                color: Colors.black,
              ),
            ),
          ),
          Positioned(
            left: 337,
            top: 73.358,
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.square(
                dimension: 24.604,
                child: Icon(Icons.close, size: 20, color: kChevronGray),
              ),
            ),
          ),
          // 환자 정보 네 줄(2346:2396 이하).
          for (var index = 0; index < patientRows.length; index++)
            Positioned(
              left: 43.718,
              top: 160.18 + index * 22.679,
              child: Row(
                children: [
                  SizedBox(
                    width: 59.645,
                    child: Text(
                      patientRows[index].$1,
                      style: kPrescriptionLabelStyle,
                    ),
                  ),
                  Text(
                    patientRows[index].$2,
                    style: kPrescriptionLabelStyle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          // 사진은 카드 우측 상단에 놓인다. get_metadata의 y=240은 회전 전
          // bounding box라 렌더 실측값(y=98)을 쓴다.
          Positioned(
            left: 192.398,
            top: 98,
            width: 150.19,
            height: 142.488,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3.514),
              child: Image(image: photo, fit: BoxFit.cover),
            ),
          ),
          // 상태 배지는 사진 바로 아래 줄이다.
          Positioned(
            left: 209.796,
            top: 249,
            height: 14,
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 8.025,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kAppleGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 5.192),
                Text(
                  statusLabel,
                  style: kPrescriptionBodyStyle.copyWith(fontSize: 12.281),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 44.006,
            top: 278.363,
            child: Text('증상', style: kPrescriptionHeadingStyle),
          ),
          const Positioned(
            left: 121.847,
            top: 278.363,
            child: Text('원인 분석', style: kPrescriptionHeadingStyle),
          ),
          const Positioned(
            left: 44.006,
            top: 418.568,
            child: Text('추천 관리', style: kPrescriptionHeadingStyle),
          ),
          for (var index = 0; index < symptoms.length; index++)
            Positioned(
              left: 37.866,
              top: 300.878 + index * 33.02,
              width: 77.013,
              height: 27.903,
              child: _SymptomChip(
                label: symptoms[index],
                // 첫 칩만 흰 배경이 채워져 있다.
                filled: index == 0,
              ),
            ),
          Positioned(
            left: 121.784,
            top: 300.878,
            width: 219.007,
            height: 97.223,
            child: _CausePanel(causes: causes),
          ),
          Positioned(
            left: 38.889,
            top: 441.083,
            width: 301.901,
            height: 118.714,
            child: _RecommendationPanel(items: recommendations),
          ),
        ],
      ),
    );
  }
}

/// 원인 분석 막대 한 줄.
class PrescriptionCause {
  const PrescriptionCause({
    required this.label,
    required this.percent,
    required this.color,
  });

  /// 과습·햇빛 부족·병충해 같은 원인 이름.
  final String label;

  /// 0~100. 막대 폭과 표시 문구 모두 이 값에서 나온다.
  final int percent;
  final Color color;
}

class _CausePanel extends StatelessWidget {
  const _CausePanel({required this.causes});

  static const double _trackWidth = 104.587;

  final List<PrescriptionCause> causes;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.328),
        border: Border.all(color: kPrescriptionBorder, width: 1.116),
      ),
      child: Stack(
        children: [
          for (var index = 0; index < causes.length; index++) ...[
            Positioned(
              left: 18.421,
              top: 10.234 + index * 31.725,
              child: Text(
                causes[index].label,
                style: kPrescriptionBodyStyle.copyWith(
                  fontSize: 11.206,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2241,
                ),
              ),
            ),
            Positioned(
              left: 68.147,
              top: 13.301 + index * 31.725,
              width: _trackWidth,
              height: 7,
              child: _CauseBar(cause: causes[index]),
            ),
            Positioned(
              left: 180.117,
              top: 10.234 + index * 31.725,
              child: Text(
                '${causes[index].percent}%',
                style: kPrescriptionBodyStyle.copyWith(
                  fontSize: 9.338,
                  fontWeight: FontWeight.w600,
                  color: kPrescriptionPercent,
                  letterSpacing: 0.1868,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CauseBar extends StatelessWidget {
  const _CauseBar({required this.cause});

  final PrescriptionCause cause;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18.676);
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: kGaugeTrack, borderRadius: radius),
          child: const SizedBox.expand(),
        ),
        // TODO(design): 시안은 막대 폭이 표시값과 어긋난다(76% 라벨에 85%
        // 폭 등). 목업 오차로 보고 표시값을 기준으로 그린다. 디자이너 확인 후
        // 비선형 스케일이 의도였다면 이 계산을 바꾼다.
        FractionallySizedBox(
          widthFactor: cause.percent / 100,
          child: DecoratedBox(
            decoration: BoxDecoration(color: cause.color, borderRadius: radius),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _SymptomChip extends StatelessWidget {
  const _SymptomChip({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? kBackgroundWhite : null,
        borderRadius: BorderRadius.circular(55.806),
        border: Border.all(color: kPrescriptionChipBorder, width: 1.116),
      ),
      child: Center(
        child: Text(
          label,
          style: kPrescriptionBodyStyle.copyWith(fontSize: 11.998),
        ),
      ),
    );
  }
}

class _RecommendationPanel extends StatelessWidget {
  const _RecommendationPanel({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kPrescriptionPanel,
        borderRadius: BorderRadius.circular(14.328),
      ),
      child: Stack(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Positioned(
              left: 19.339,
              top: 8.174 + index * 36.832,
              child: const SizedBox.square(
                dimension: 30.994,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kBackgroundWhite,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 61.752,
              top: 15.987 + index * 36.832,
              child: Text(
                items[index],
                style: kPrescriptionBodyStyle.copyWith(
                  fontSize: 11.257,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2251,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
