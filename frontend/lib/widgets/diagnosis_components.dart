import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/inset_shadow_box.dart';
import 'package:yeso_plant/widgets/onboarding_copy.dart';
import 'package:yeso_plant/widgets/svg_drop_shadow.dart';

/// Figma node 4534:19705. 진단 기록이 하나도 없을 때의 안내.
class DiagnosisEmptyState extends StatelessWidget {
  const DiagnosisEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingCopy(
      title: '진단 기록이 없습니다',
      subtitle: '내 식물의 건강을 진단해주세요.',
      textAlign: TextAlign.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      // 시안은 제목 글자 윗변(390)과 부제 글자 윗변(423)이 33 떨어진다.
      // 제목 상자(20px, height 1)가 20이라 간격 14여야 부제가 423에 찍힌다.
      gap: 14,
    );
  }
}

/// Figma node 4534:19850. 진단 기록 목록의 한 줄.
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
            // 4534:19852 꺾쇠: 위로 향한 채운 꺾쇠(#CCCBCB)를 90° 돌린 것.
            // 돌린 뒤 8.29×13 상자가 행 오른쪽 끝에서 18.7 안쪽(x 361)에 온다.
            RotatedBox(
              quarterTurns: 1,
              child: SvgPicture.asset(
                'assets/images/diagnosis_record_chevron.svg',
                width: 13.0038,
                height: 8.29445,
              ),
            ),
            const SizedBox(width: 18.7),
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
    this.plantName = '내 식물',
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

  /// 원인분석 문구에 넣는 식물 이름(애칭).
  final String plantName;

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
            // 4534:19735: inset -3 -3 1 0 rgba(118,94,60,0.25). 안쪽 그림자라
            // 카드 안 오른쪽·아래 가장자리가 어두워진다. BlurStyle.inner는
            // 카드 밖 왼쪽·위로 그려져 시안과 반대였다.
            child: InsetShadowBox(
              color: const Color(0xFFFFDB86),
              borderRadius: BorderRadius.circular(20.733),
              shadows: const [
                BoxShadow(
                  color: Color(0x40765E3C),
                  blurRadius: 1,
                  offset: Offset(-3, -3),
                ),
              ],
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
          // 4534:19786 종이 질감: 종이 모양(357.17×555.7, 모서리 10) 마스크
          // 안에 질감 사진을 곱하기 12%로 덮는다.
          const Positioned(
            left: 10,
            top: 55,
            width: 357.165,
            height: 555.703,
            child: _PaperTexture(),
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
          // 4534:19817 십자 y191 → 카드 기준 93.
          Positioned(
            left: 126,
            top: 93,
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
              style: kTitleStyle.copyWith(
                fontSize: 25 + _kRxFontBump,
                color: kTextDark,
              ),
            ),
          ),
          // 4534:19740 닫기: 십자(Union 17.7, #A1A1A1)를 -46.21° 돌리고
          // -1.9° 기울인 것. 회전 뒤 상자(24.6×25.43)는 x338 y61이라 중심이
          // (350.3, 73.72)다. 누르기 쉽게 32 상자 가운데에 둔다.
          Positioned(
            left: 350.302 - 16,
            top: 73.717 - 16,
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: SizedBox.square(
                dimension: 32,
                child: Center(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationZ(-46.21 * math.pi / 180)
                      ..multiply(Matrix4.skewX(-1.9 * math.pi / 180)),
                    child: SvgPicture.asset(
                      'assets/images/diagnosis_prescription_close.svg',
                      width: 17.6965,
                      height: 17.6912,
                    ),
                  ),
                ),
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
          // 4534:19820~19825 환자 정보표 격자: 가로선 5줄(x201~334, 22 간격)과
          // 라벨·값을 나누는 세로선(x246). #FFB52A 30%, 두께 0.8.
          for (var line = 0; line < 5; line++)
            Positioned(
              left: 201,
              top: 149 + line * 22 - 0.4,
              width: 133,
              height: 0.8,
              child: const ColoredBox(color: _kPatientGridLine),
            ),
          const Positioned(
            left: 246 - 0.4,
            top: 149,
            width: 0.8,
            height: 88,
            child: ColoredBox(color: _kPatientGridLine),
          ),
          for (var index = 0; index < patientRows.take(4).length; index++) ...[
            Positioned(
              left: 209,
              top: 154.86 + index * 21.71,
              width: 42,
              child: Text(
                patientRows[index].$1,
                style: kPrescriptionLabelStyle.copyWith(
                  fontSize: 9 + _kRxFontBump,
                ),
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
                  fontSize: 9 + _kRxFontBump,
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
                      fontSize: 10 + _kRxFontBump,
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
          // 절 제목 시안 top 393.41(카드 기준 295.41). Flutter 글자 상자가
          // 커서 그대로 두면 보이는 글자가 2px 아래라 그만큼 올린다.
          const Positioned(
            left: 31.98,
            top: 293.41,
            child: Text('증상', style: _sectionHeadingStyle),
          ),
          const Positioned(
            left: 137.39,
            top: 293.41,
            child: Text('원인분석', style: _sectionHeadingStyle),
          ),
          for (var index = 0; index < symptoms.take(3).length; index++) ...[
            Positioned(
              left: 30.88,
              top: 328.6 + index * 31.65,
              child: Text(
                '0${index + 1}.',
                style: kPrescriptionBodyStyle.copyWith(
                  fontSize: 13.951 + _kRxFontBump,
                  fontWeight: FontWeight.w700,
                  color: kBrightOrange,
                  // 4534:19768 자간 2%.
                  letterSpacing: 0.279,
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
                  fontSize: 12.393 + _kRxFontBump,
                  fontWeight: FontWeight.w500,
                  color: kTextDark,
                  letterSpacing: 0.2479,
                ),
              ),
            ),
          ],
          // 4534:19765 상자 231x85. 글자를 1 키우고 관리 문장까지 채우면(디자이너
          // 요청: 시안처럼 내용을 채워 달라) 85를 넘쳐, 아래 추천관리 띠(441.84)
          // 와의 간격 30 중 17을 써서 102로 늘린다.
          Positioned(
            left: 126,
            top: 326,
            width: 231,
            height: 102,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x80FFF1D0),
                borderRadius: BorderRadius.circular(9.882),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 8, 9, 7),
                child: Text.rich(
                  _causeSummary(
                    plantName,
                    statusLabel,
                    causes,
                    recommendations,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  // 4534:19770 Paperlogy 5 Medium 11, 줄 높이 130%, 자간 2%.
                  style: kPrescriptionBodyStyle.copyWith(
                    fontSize: 11 + _kRxFontBump,
                    fontWeight: FontWeight.w500,
                    color: kTextDark,
                    height: 1.3,
                    letterSpacing: (11 + _kRxFontBump) * 0.02,
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
            // 시안 445.25에서 위와 같은 이유로 올린다.
            top: 444,
            child: Text('추천관리', style: _sectionHeadingStyle),
          ),
          for (
            var index = 0;
            index < recommendations.take(3).length;
            index++
          ) ...[
            // 4534:19784·19785 구분선은 항목 사이에만 두 줄(y516.76·568.98).
            // 마지막 항목 아래에는 없다.
            if (index < recommendations.take(3).length - 1)
              Positioned(
                left: 21,
                top: 516.76 + index * 52.22,
                width: 336,
                height: 0.88,
                child: const ColoredBox(color: Color(0xFFFFC966)),
              ),
            Positioned(
              left: 26,
              top: 470 + index * 51.05,
              width: 44,
              height: 44,
              child: _CareIcon(index: index),
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
                  fontSize: 12.361 + _kRxFontBump,
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
                  letterSpacing: 0.2472,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 처방전 안 글자를 시안보다 모두 키우는 크기(10/31 피드백: "전부 다 1씩").
/// 시안 수치는 그대로 두고 이 값을 더한다.
const double _kRxFontBump = 1;

// 4534:19782 등 절 제목. 시안 자간 2%(0.2472).
const TextStyle _sectionHeadingStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 12.361 + _kRxFontBump,
  fontWeight: FontWeight.w600,
  color: kBrightOrange,
  letterSpacing: 0.2472,
);

/// 4534:19820 환자 정보표 격자선 #FFB52A 30%.
const Color _kPatientGridLine = Color(0x4DFFB52A);

/// 4534:19786 처방전 종이 질감. 시안은 질감 사진을 종이 모양으로 가려
/// 곱하기(multiply) 12%로 얹는다. 일반 합성으로는 노란 머리띠 위에서 색이
/// 밝아지는 쪽으로 틀어져, 이미지 칠하기에 곱하기 모드를 넘긴다.
///
/// 시안은 사진을 90° 돌려 쓰지만 방향 없는 종이 결이라 돌리지 않는다.
class _PaperTexture extends StatefulWidget {
  const _PaperTexture();

  @override
  State<_PaperTexture> createState() => _PaperTextureState();
}

class _PaperTextureState extends State<_PaperTexture> {
  late final DecorationImagePainter _painter = const DecorationImage(
    image: AssetImage('assets/images/diagnosis_paper_texture.png'),
    fit: BoxFit.cover,
    opacity: 0.12,
  ).createPainter(_onImageChanged);

  /// 이미지가 다 읽히면 다시 칠하도록 바뀔 때마다 올린다.
  int _revision = 0;

  void _onImageChanged() {
    if (mounted) setState(() => _revision++);
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PaperTexturePainter(
          painter: _painter,
          configuration: createLocalImageConfiguration(context),
          revision: _revision,
        ),
      ),
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  _PaperTexturePainter({
    required this.painter,
    required this.configuration,
    required this.revision,
  });

  final DecorationImagePainter painter;
  final ImageConfiguration configuration;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    painter.paint(
      canvas,
      rect,
      Path()
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10))),
      configuration.copyWith(size: size),
      blendMode: BlendMode.multiply,
    );
  }

  @override
  bool shouldRepaint(_PaperTexturePainter oldDelegate) =>
      oldDelegate.revision != revision || oldDelegate.painter != painter;
}

const List<String> _careIconAssets = [
  'assets/images/diagnosis_care_water.svg',
  'assets/images/diagnosis_care_light.svg',
  'assets/images/diagnosis_care_recheck.svg',
];

/// 추천관리 아이콘. 흰 원(r 18)에 흐림 2·25% 그림자가 있다.
///
/// 재확인 아이콘은 원 위의 종이(+집게)에도 흐림 1.375·20% 그림자가 따로
/// 있다. 그림자가 원과 종이 사이에 그려져야 해서 SVG를 원과 종이 두 장으로
/// 나눴다(diagnosis_care_recheck_paper.svg).
class _CareIcon extends StatelessWidget {
  const _CareIcon({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final circle = SvgDropShadow(
      stdDeviation: 2,
      opacity: 0.25,
      child: SvgPicture.asset(_careIconAssets[index]),
    );
    if (index != 2) return circle;
    return Stack(
      children: [
        circle,
        SvgDropShadow(
          stdDeviation: 1.3754,
          opacity: 0.2,
          child: SvgPicture.asset(
            'assets/images/diagnosis_care_recheck_paper.svg',
          ),
        ),
      ],
    );
  }
}

/// 원인분석 문구(시안 4534:19770). 시안은 "오늘 하루 새싹이의 건강상태는
/// **34점**이에요. / **햇빛이 부족**하고, **건습**의 문제가 있어요. / (빈 줄)
/// / 관리 방법" 꼴로 핵심만 Bold 주황으로 강조한다. 서버가 점수를 주지 않아
/// 점수 자리에는 상태 문구(condition_label)를 강조한다. 마지막 관리 문장은
/// 서버가 따로 주지 않아 추천관리 첫 줄을 쓴다.
TextSpan _causeSummary(
  String plantName,
  String statusLabel,
  List<PrescriptionCause> causes,
  List<String> recommendations,
) {
  const strong = TextStyle(fontWeight: FontWeight.w700, color: kBrightOrange);
  return TextSpan(
    children: [
      TextSpan(text: '오늘 하루 $plantName의 건강상태는 '),
      TextSpan(text: statusLabel, style: strong),
      const TextSpan(text: '.\n'),
      if (causes.isEmpty)
        const TextSpan(text: '분석된 원인 정보가 없어요.')
      else ...[
        for (var i = 0; i < causes.length; i++) ...[
          if (i > 0) const TextSpan(text: ', '),
          TextSpan(text: causes[i].label, style: strong),
        ],
        const TextSpan(text: '의 문제가 있어요.'),
      ],
      // 시안은 관리 문장 앞에 빈 줄을 둔다. 상자가 좁아 반 줄만 띄운다.
      if (recommendations.isNotEmpty) ...[
        const TextSpan(text: '\n'),
        const TextSpan(text: '\n', style: TextStyle(fontSize: 6)),
        TextSpan(text: recommendations.first),
      ],
    ],
  );
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

  /// 0~100. 서버가 확률을 주지 않으면(null) null로 둔다. 확률이 없는 원인을
  /// 0%로 보여주지 않는다는 계약(#112)이라 0으로 바꾸지 않는다. 지금 화면은
  /// 원인 이름만 문장으로 보여 준다.
  final int? percent;
  final Color color;
}
