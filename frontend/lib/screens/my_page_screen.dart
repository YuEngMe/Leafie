import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/change_password_screen.dart';
import 'package:yeso_plant/screens/edit_profile_screen.dart';
import 'package:yeso_plant/screens/withdraw_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/mypage_cards.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// Figma "마이페이지_앱 진입"(2319:2). 알림 토글 켬은 2353:577,
/// 로그아웃 확인 모달은 2353:624.
///
/// 시안에 하단 네비게이션 바가 없다. 홈에서 밀어 올리는 화면이라
/// 뒤로가기로 빠져나온다.
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({
    super.key,
    this.nickname = '김윤지님',
    this.email = 'akdrotorl@naver.com',
    this.tenureDays = 128,
  });

  final String nickname;
  final String email;

  /// 가입일로부터 지난 날짜. 서버가 가입일을 주면 계산해 넘긴다.
  final int tenureDays;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  // TODO(1-E): dio 붙이면 GET /users/me의 notification_enabled로 초기화하고
  // 변경 시 PATCH /users/me를 호출한다. 시안 기본값은 꺼짐(2319:2).
  bool _notificationsEnabled = false;

  /// 내 정보 수정에서 돌아오면 이 값이 바뀐다(2353:290).
  late String _nickname = widget.nickname;

  Future<void> _editProfile() async {
    final next = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(nickname: _nickname)),
    );
    if (next == null || !mounted) return;
    setState(() => _nickname = next);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: kModalBarrier,
      builder: (_) => const SignOutConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;

    // main.dart의 onAuthStateChange가 signedOut을 받아 로그인 화면으로
    // 스택을 걷어낸다. 여기서 Navigator를 직접 건드리지 않는다.
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '마이페이지'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.myPageHorizontalPadding,
            0,
            AppLayout.myPageHorizontalPadding,
            AppLayout.myPageBottomGap,
          ),
          child: Column(
            children: [
              const SizedBox(height: AppLayout.myPageTopGap),
              ProfileSummaryCard(
                nickname: _nickname,
                email: widget.email,
                tenureLabel: '식집사가 된 지 ${widget.tenureDays}일째',
              ),
              const SizedBox(height: AppLayout.myPageCardGap),
              ProfileMenuCard(
                onEditProfile: _editProfile,
                onChangePassword: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangePasswordScreen(email: widget.email),
                  ),
                ),
                onWithdraw: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WithdrawScreen()),
                ),
                notificationsEnabled: _notificationsEnabled,
                onNotificationsChanged: (value) =>
                    setState(() => _notificationsEnabled = value),
              ),
              // 카드와 버튼 사이는 시안에서 338px이지만, 고정하면 작은 화면에서
              // 넘친다. 버튼을 아래에 붙이고 여백으로 위치를 맞춘다.
              const Spacer(),
              // 버튼만 카드보다 좌우 5px씩 좁다(2319:23).
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.myPageButtonInset,
                ),
                child: PrimaryButton(
                  label: '로그아웃',
                  variant: PrimaryButtonVariant.enabled,
                  textStyle: kLoginButtonStyle,
                  onPressed: _confirmSignOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
