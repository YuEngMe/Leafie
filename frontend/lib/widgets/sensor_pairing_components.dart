import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/services/sensor_ble.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

// 센서 기기 등록 화면(Figma 섹션 "기기연결" 5732:849)의 공통 부품.
// 모든 프레임이 앱바 아래에 제목(top 140)·부제(top 175)·본문(top 237)·
// 하단 버튼(top 790)을 같은 자리에 둔다.

/// 시안 좌표를 앱바 아래(상태바 46 + 앱바 46 = 92) 기준으로 옮긴 값.
const double _kTitleTop = 140 - 92;
const double _kBodyTop = 237;

/// 행·입력칸 그림자(drop-shadow 0 0 2 rgba(0,0,0,0.18)).
const List<BoxShadow> kSensorFieldShadow = [
  BoxShadow(color: Color(0x2E000000), blurRadius: 2),
];

/// 제목 아래 부제(본문 16 Regular, 행간 23). 1 1·11의 "검색 중..."은 회색 14다.
const TextStyle kSensorSubtitleStyle = TextStyle(
  fontFamily: 'Paperlogy',
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 23 / 16,
  color: kTextDark,
);
const TextStyle kSensorHintStyle = TextStyle(
  fontFamily: 'Paperlogy',
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: kOnboardingSubtitle,
);

/// 기기 이름. 라벨의 ID 끝 4자리로 구분한다(시안의 "Leafie 01" 자리).
String sensorDeviceName(String deviceId) =>
    'Leafie ${deviceId.substring(deviceId.length - 4)}';

/// 앱바·제목·부제·본문·하단 버튼의 뼈대.
class SensorStepScaffold extends StatelessWidget {
  const SensorStepScaffold({
    super.key,
    this.appBarTitle = '기기 등록',
    this.title,
    this.subtitle,
    this.subtitleStyle = kSensorSubtitleStyle,
    required this.body,
    this.bottom,
    this.onBack,
  });

  final String appBarTitle;
  final String? title;
  final String? subtitle;
  final TextStyle subtitleStyle;
  final Widget body;
  final Widget? bottom;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      resizeToAvoidBottomInset: true,
      appBar: YesoAppBar(title: appBarTitle),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null) ...[
                      const SizedBox(height: _kTitleTop),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 45),
                        child: Text(title!, style: kTitleStyle),
                      ),
                    ],
                    if (subtitleText != null)
                      Padding(
                        // 제목 top 140 → 부제 top 175. Flutter의 21px 제목 상자가
                        // 30이라 5만 띄운다(RegisterStepScaffold와 같다). 부제는
                        // 기기 이름이 길어져도 한 줄에 들도록 오른쪽을 덜 띄운다.
                        padding: const EdgeInsets.fromLTRB(45, 5, 20, 0),
                        // 부제 상자는 글자 크기와 무관하게 23으로 둬서 본문이
                        // 늘 top 237에서 시작하게 한다(1 1의 14px 부제 포함).
                        child: SizedBox(
                          height: 23,
                          child: Text(subtitleText, style: subtitleStyle),
                        ),
                      ),
                    body,
                  ],
                ),
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// 제목·부제 아래 본문이 시작하는 자리(top 237)까지 띄운다.
/// 부제가 없는 화면은 [hasSubtitle]을 끈다.
class SensorBodyGap extends StatelessWidget {
  const SensorBodyGap({super.key, this.hasSubtitle = true});

  final bool hasSubtitle;

  @override
  Widget build(BuildContext context) {
    // 부제 top 175 + 높이 23 = 198. 제목만 있으면 제목 상자(Flutter 30)
    // 바닥 170.
    return SizedBox(height: _kBodyTop - (hasSubtitle ? 198 : 170));
  }
}

/// 흰 알약 모양 칸(1 1·18·15의 기기·Wi-Fi 행, 334 x 51).
class SensorPillRow extends StatelessWidget {
  const SensorPillRow({
    super.key,
    required this.child,
    this.onTap,
    this.height = 51,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kButtonRadius),
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              color: kBackgroundWhite,
              borderRadius: BorderRadius.circular(kButtonRadius),
              boxShadow: kSensorFieldShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 기기 행(1 1 4534:21031). 점(x22) · 이름(x43) · 오른쪽 작은 글씨.
class SensorDeviceRow extends StatelessWidget {
  const SensorDeviceRow({
    super.key,
    required this.device,
    required this.trailing,
    this.onTap,
  });

  final SensorBleDevice device;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SensorPillRow(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 22, right: 20),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/images/sensor_device_dot.svg',
              width: 7,
              height: 7,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(sensorDeviceName(device.deviceId), style: kBodyStyle),
            ),
            Text(trailing, style: kCaptionStyle),
          ],
        ),
      ),
    );
  }
}

/// 신호 세기 문구(1 1 "신호세기: 강함/약함"). 기준은 실측 전 추정치다.
String sensorSignalLabel(int? rssi) {
  if (rssi == null) return '신호세기: 알 수 없음';
  if (rssi >= -60) return '신호세기: 강함';
  if (rssi >= -75) return '신호세기: 보통';
  return '신호세기: 약함';
}

/// 오렌지 항목 라벨(x45, 항목 16 SemiBold). Flutter 글자 상자는 23으로
/// 시안(19)보다 4 크다.
class SensorFieldLabel extends StatelessWidget {
  const SensorFieldLabel(this.text, {super.key, this.color = kOrangeMain});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 라벨 top 237 → 행 top 261(라벨 상자 23 + 1, 15·6-1).
      padding: const EdgeInsets.only(left: 45, bottom: 1),
      child: Text(text, style: kItemStyle.copyWith(color: color)),
    );
  }
}

/// 11의 안내 상자(312 x 80, 안쪽 그림자). 점 목록을 담는다.
class SensorTipBox extends StatelessWidget {
  const SensorTipBox({super.key, required this.tips});

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 45),
      child: Container(
        padding: const EdgeInsets.fromLTRB(1, 14, 13, 12),
        decoration: BoxDecoration(
          color: kBackgroundWhite,
          border: Border.all(color: const Color(0x14000000)),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 4),
            BoxShadow(color: kBackgroundWhite, spreadRadius: -1, blurRadius: 3),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, tip) in tips.indexed)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 20,
                      child: Text(
                        '•',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 23 / 16,
                          color: kOnboardingSubtitle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        tip,
                        style: kSensorHintStyle.copyWith(height: 23 / 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum SensorStepMark { done, current, pending }

/// 13·14의 진행 목록(322 너비, 반경 13, 연한 회색 테두리, 행 높이 32).
class SensorProgressList extends StatelessWidget {
  const SensorProgressList({super.key, required this.steps});

  final List<(String, SensorStepMark)> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 0, 11, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: kGrayLightest.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            for (final (index, (label, mark)) in steps.indexed) ...[
              if (index > 0)
                SvgPicture.asset(
                  'assets/images/sensor_step_divider.svg',
                  width: 299,
                  height: 1,
                ),
              SizedBox(
                height: index == 0 ? 33 : 31,
                child: Row(
                  children: [
                    SizedBox(
                      width: 23,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _mark(mark),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      label,
                      style: kSmallStyle.copyWith(
                        color: kTextDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mark(SensorStepMark mark) => switch (mark) {
    SensorStepMark.done => Padding(
      padding: const EdgeInsets.only(left: 2),
      child: SvgPicture.asset(
        'assets/images/sensor_step_check.svg',
        width: 13.9995,
        height: 9.87079,
      ),
    ),
    SensorStepMark.current => Padding(
      padding: const EdgeInsets.only(left: 3),
      child: SvgPicture.asset(
        'assets/images/sensor_step_current.svg',
        width: 13,
        height: 13,
      ),
    ),
    SensorStepMark.pending => Padding(
      padding: const EdgeInsets.only(left: 3),
      child: SvgPicture.asset(
        'assets/images/sensor_step_pending.svg',
        width: 13,
        height: 13,
      ),
    ),
  };
}

/// 12의 Wi-Fi 칸 오른쪽 드롭다운 단추(오렌지 원 26 + 흰 꺾쇠).
class SensorDropdownButton extends StatelessWidget {
  const SensorDropdownButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 26,
      child: Stack(
        children: [
          SvgPicture.asset(
            'assets/images/sensor_dropdown_circle.svg',
            width: 26,
            height: 26,
          ),
          // 꺾쇠는 원 안 (5.97, 8.61)에 놓인다(4534:21109).
          Positioned(
            left: 5.97,
            top: 8.61,
            child: SvgPicture.asset(
              'assets/images/sensor_dropdown_chevron.svg',
              width: 13.9995,
              height: 9.87079,
            ),
          ),
        ],
      ),
    );
  }
}

/// 17의 선택 원(흰 원 / 오렌지 원 + 흰 꺾쇠).
class SensorRadio extends StatelessWidget {
  const SensorRadio({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 26,
      child: selected
          ? Stack(
              children: [
                SvgPicture.asset(
                  'assets/images/sensor_radio_on_circle.svg',
                  width: 26,
                  height: 26,
                ),
                // 4910:280: 원 안 (6.97, 9.61), 12 x 8.
                Positioned(
                  left: 5.97,
                  top: 8.61,
                  child: SvgPicture.asset(
                    'assets/images/sensor_radio_on_chevron.svg',
                    width: 14.0001,
                    height: 9.87103,
                  ),
                ),
              ],
            )
          : DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: kSensorFieldShadow,
              ),
              child: SvgPicture.asset(
                'assets/images/sensor_radio_off.svg',
                width: 26,
                height: 26,
              ),
            ),
    );
  }
}

/// 17의 식물 행(374 x 58.2, 반경 50, 그림자 0 0 4). 회색 원(48) 안에 캐릭터.
class SensorPlantRow extends StatelessWidget {
  const SensorPlantRow({
    super.key,
    required this.nickname,
    required this.character,
    required this.selected,
    required this.onTap,
    this.connectedLabel,
  });

  final String nickname;
  final PlantCharacterArt character;
  final bool selected;
  final VoidCallback onTap;
  final String? connectedLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kButtonRadius),
          child: Ink(
            height: 58.196,
            decoration: BoxDecoration(
              color: kBackgroundWhite,
              borderRadius: BorderRadius.circular(kButtonRadius),
              boxShadow: const [
                BoxShadow(color: Color(0x2E000000), blurRadius: 4),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 6),
                SizedBox.square(
                  dimension: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/sensor_avatar_circle.svg',
                        width: 48,
                        height: 48,
                      ),
                      // 4904:170: 몸통 폭 약 22에 바닥이 원 바닥에서 3 위다.
                      Positioned(bottom: 3, child: character),
                    ],
                  ),
                ),
                const SizedBox(width: 33),
                SizedBox(
                  width: 105,
                  child: Text(
                    nickname,
                    style: kBodyStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    connectedLabel ?? '',
                    style: kCaptionStyle.copyWith(color: kTextDark),
                  ),
                ),
                SensorRadio(selected: selected),
                const SizedBox(width: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
