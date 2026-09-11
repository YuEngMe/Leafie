import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_glyphs.dart';
import 'package:yeso_plant/widgets/figma_toggle_switch.dart';

/// Figma component set `마이페이지_시용자 정보` (2353:712)의 두 카드.
///
/// 둘 다 폭 344, radius 20, 같은 그림자를 쓴다.
const double _cardWidth = 344;
const double _cardRadius = 20;
const List<BoxShadow> _cardShadow = [
  BoxShadow(color: Color(0x33000000), blurRadius: 5),
];

/// Figma node 2353:710. 닉네임·가입일·이메일을 담은 프로필 요약 카드.
class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({
    super.key,
    required this.nickname,
    required this.email,
    required this.tenureLabel,
  });

  static const double height = 77.762;

  final String nickname;
  final String email;

  /// "식집사가 된 지 128일째"처럼 완성된 문구를 그대로 받는다.
  final String tenureLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _cardWidth,
      height: height,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              // Figma는 kPaleYellow를 43% 투명도로 깔지만, 그 합성 결과를
              // 불투명색으로 굳혀 뒤 배경색에 카드가 물들지 않게 한다.
              color: kProfileCardYellow,
              borderRadius: BorderRadius.circular(_cardRadius),
              boxShadow: _cardShadow,
            ),
            child: const SizedBox.expand(),
          ),
          // 2353:691 x=23 y=14.238.
          Positioned(
            left: 23,
            top: 14.238,
            child: Text(
              nickname,
              style: kTitleStyle.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          // 2353:693 x=102 y=23.
          Positioned(
            left: 102,
            top: 23,
            child: Text(tenureLabel, style: kCaptionStyle),
          ),
          // 2353:692 x=23 y=47.096.
          Positioned(
            left: 23,
            top: 47.096,
            child: Text(email, style: kCaptionStyle.copyWith(color: kTextDark)),
          ),
        ],
      ),
    );
  }
}

/// Figma node 2353:711. 프로필 관리 메뉴 카드.
///
/// 앞의 세 행은 꺾쇠로 다음 화면을 열고, 마지막 앱 알림 행만 토글을 단다.
class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({
    super.key,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onWithdraw,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
  });

  static const double height = 241;

  /// 첫 행 텍스트 baseline(2353:697 y=53.762)과 행 간격(49px).
  static const double _firstRowTop = 53.762;
  static const double _rowGap = 49;
  static const double _rowTextHeight = 19;

  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onWithdraw;
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _cardWidth,
      height: height,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: kBackgroundWhite,
              borderRadius: BorderRadius.circular(_cardRadius),
              boxShadow: _cardShadow,
            ),
            child: const SizedBox.expand(),
          ),
          // 2353:705 x=23 y=16.
          const Positioned(
            left: 23,
            top: 16,
            child: Text('프로필 관리', style: kCaptionStyle),
          ),
          _MenuRow(top: _firstRowTop, label: '내 정보 수정', onTap: onEditProfile),
          _MenuRow(
            top: _firstRowTop + _rowGap,
            label: '비밀번호 변경',
            onTap: onChangePassword,
          ),
          _MenuRow(
            top: _firstRowTop + _rowGap * 2,
            label: '회원 탈퇴',
            onTap: onWithdraw,
          ),
          // 마지막 행은 꺾쇠 대신 토글이라 별도로 그린다.
          Positioned(
            left: 23,
            top: _firstRowTop + _rowGap * 3,
            height: _rowTextHeight,
            child: const Text('앱 알림', style: kBodyStyle),
          ),
          // 2353:706 x=281 y=198.762, 토글 높이 24.923.
          Positioned(
            left: 281,
            top: 198.762 - (48 - FigmaToggleSwitch.trackSize.height) / 2,
            child: FigmaToggleSwitch(
              value: notificationsEnabled,
              onChanged: onNotificationsChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.top, required this.label, required this.onTap});

  final double top;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      // 텍스트 19px 행을 세로 중심에 두고 위아래로 터치 영역을 넓힌다.
      // Row가 자식을 가운데 정렬하며 글자를 2px 끌어올려 그만큼 되돌린다.
      top: top - (48 - ProfileMenuCard._rowTextHeight) / 2 + 2,
      height: 48,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(left: 23, right: 23),
          child: Row(
            children: [
              Expanded(child: Text(label, style: kBodyStyle)),
              // Figma는 꺾쇠를 폰트 글리프로 그렸지만, 같은 모양의 벡터가
              // 이미 있어 색만 맞춰 재사용한다(2353:698 #A1A1A1, 10x15).
              const FigmaChevronRight(color: kTextLight),
            ],
          ),
        ),
      ),
    );
  }
}
