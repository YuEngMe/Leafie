import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

/// 최신 Figma node 2756:390의 처방전 카드.
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

  /// 빨간 클립 top부터 노란 카드 bottom까지의 실제 영역.
  static const Size cardSize = Size(378.656, 643);

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
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 47.38,
            width: cardSize.width,
            height: 595.621,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFDB86),
                borderRadius: BorderRadius.circular(20.733),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40765E3C),
                    blurRadius: 1,
                    offset: Offset(-3, -3),
                    blurStyle: BlurStyle.inner,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10.234,
            top: 57.13,
            width: 357.165,
            height: 574.465,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kBackgroundWhite,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 4.09,
                    offset: Offset(0, 4.09),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10.328,
            top: 56.86,
            width: 358,
            height: 103.376,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFCEECD),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned(
            left: 115,
            top: 0,
            width: 150.59,
            height: 73.828,
            child: SvgPicture.asset(
              'assets/images/diagnosis_prescription_tab.svg',
            ),
          ),
          Positioned(
            left: 126,
            top: 90.97,
            width: 26,
            height: 25.609,
            child: SvgPicture.asset(
              'assets/images/diagnosis_prescription_cross.svg',
            ),
          ),
          Positioned(
            left: 156,
            top: 90.97,
            height: 30,
            child: Text(
              '처방전',
              style: kTitleStyle.copyWith(fontSize: 25, color: kTextDark),
            ),
          ),
          Positioned(
            left: 326,
            top: 59,
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.square(
                dimension: 32,
                child: Icon(Icons.close, size: 23, color: kChevronGray),
              ),
            ),
          ),
          Positioned(
            left: 39,
            top: 131.29,
            width: 307,
            height: 140.592,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 5),
                ],
              ),
            ),
          ),
          Positioned(
            left: 47,
            top: 139.56,
            width: 136,
            height: 124.051,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3.229),
              child: Image(
                image: photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFE8E8E8),
                  child: Center(
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
          ),
          for (var index = 0; index < patientRows.take(4).length; index++) ...[
            Positioned(
              left: 209,
              top: 154.86 + index * 21.71,
              width: 42,
              child: Text(
                patientRows[index].$1,
                style: kPrescriptionLabelStyle.copyWith(fontSize: 9),
              ),
            ),
            Positioned(
              left: 259,
              top: 154.86 + index * 21.71,
              width: 78,
              child: Text(
                patientRows[index].$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kPrescriptionLabelStyle.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  color: kTextDark,
                ),
              ),
            ),
          ],
          Positioned(
            left: 201,
            top: 248.8,
            width: 138,
            height: 13,
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
                Expanded(
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kPrescriptionBodyStyle.copyWith(
                      fontSize: 10,
                      color: kTextDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 22.1,
            top: 292.01,
            width: 94.431,
            height: 21.567,
            child: ColoredBox(color: Color(0xFFFFF1D0)),
          ),
          const Positioned(
            left: 126.41,
            top: 292.01,
            width: 230.588,
            height: 21.567,
            child: ColoredBox(color: Color(0xFFFFF1D0)),
          ),
          const Positioned(
            left: 31.98,
            top: 295.41,
            child: Text('증상', style: _sectionHeadingStyle),
          ),
          const Positioned(
            left: 137.39,
            top: 295.41,
            child: Text('원인분석', style: _sectionHeadingStyle),
          ),
          for (var index = 0; index < symptoms.take(3).length; index++) ...[
            Positioned(
              left: 30.88,
              top: 328.6 + index * 31.65,
              child: Text(
                '0${index + 1}.',
                style: kPrescriptionBodyStyle.copyWith(
                  fontSize: 13.951,
                  fontWeight: FontWeight.w700,
                  color: kBrightOrange,
                ),
              ),
            ),
            Positioned(
              left: 56.91,
              top: 328.6 + index * 31.65,
              width: 66,
              child: Text(
                symptoms[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kPrescriptionBodyStyle.copyWith(
                  fontSize: 12.393,
                  fontWeight: FontWeight.w500,
                  color: kTextDark,
                ),
              ),
            ),
          ],
          Positioned(
            left: 126,
            top: 326,
            width: 231,
            height: 85,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x80FFF1D0),
                borderRadius: BorderRadius.circular(9.882),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 8, 9, 7),
                child: Text(
                  _causeSummary(statusLabel, causes, recommendations),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: kPrescriptionBodyStyle.copyWith(
                    fontSize: 11,
                    color: kTextDark,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 21,
            top: 441.84,
            width: 336,
            height: 21.567,
            child: ColoredBox(color: Color(0xFFFFF1D0)),
          ),
          const Positioned(
            left: 31.98,
            top: 445.25,
            child: Text('추천관리', style: _sectionHeadingStyle),
          ),
          for (
            var index = 0;
            index < recommendations.take(3).length;
            index++
          ) ...[
            Positioned(
              left: 21,
              top: 516.76 + index * 52.11,
              width: 336,
              height: 0.88,
              child: const ColoredBox(color: Color(0xFFFFC966)),
            ),
            Positioned(
              left: 26,
              top: 470 + index * 51.05,
              width: 44,
              height: 44,
              child: SvgPicture.asset(_careIconAssets[index]),
            ),
            Positioned(
              left: 78.57,
              top: 483.84 + index * 51.0,
              width: 250,
              child: Text(
                recommendations[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kPrescriptionBodyStyle.copyWith(
                  fontSize: 12.361,
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const TextStyle _sectionHeadingStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 12.361,
  fontWeight: FontWeight.w600,
  color: kBrightOrange,
);

const List<String> _careIconAssets = [
  'assets/images/diagnosis_care_water.svg',
  'assets/images/diagnosis_care_light.svg',
  'assets/images/diagnosis_care_recheck.svg',
];

String _causeSummary(
  String statusLabel,
  List<PrescriptionCause> causes,
  List<String> recommendations,
) {
  final causeText = causes.isEmpty
      ? '분석된 원인 정보가 없습니다.'
      : '가능한 원인은 ${causes.map((cause) => cause.label).join(', ')}입니다.';
  final careText = recommendations.isEmpty ? '' : '\n${recommendations.first}';
  return '오늘의 건강상태는 $statusLabel.\n$causeText$careText';
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
