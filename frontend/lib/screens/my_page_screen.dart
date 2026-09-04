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
  const MyPageScreen({super.key, this.user});

  /// 로그인한 사용자. 비워 두면 현재 세션에서 읽는다. 테스트에서만 넘긴다.
  final User? user;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

/// 화면에 띄울 프로필. 세션이 없거나 값이 비어 있어도 화면은 떠야 한다.
class _Profile {
  const _Profile({
    required this.nickname,
    required this.email,
    required this.tenureDays,
  });

  /// 회원가입·소셜 닉네임 화면이 user_metadata에 넣어 둔 값을 읽는다.
  factory _Profile.of(User? user) {
    final nickname = user?.userMetadata?['leafie_nickname'] as String?;
    final createdAt = DateTime.tryParse(user?.createdAt ?? '');
    return _Profile(
      // 시안(2319:56)은 이름 뒤에 '님'이 붙은 채로 그려져 있다.
      nickname: (nickname == null || nickname.isEmpty) ? '식집사님' : '$nickname님',
      email: user?.email ?? '',
      tenureDays: createdAt == null
          ? 0
          : DateTime.now().difference(createdAt).inDays,
    );
  }

  final String nickname;
  final String email;
  final int tenureDays;
}

class _MyPageScreenState extends State<MyPageScreen> {
  // TODO(1-E): dio 붙이면 GET /users/me의 notification_enabled로 초기화하고
  // 변경 시 PATCH /users/me를 호출한다. 시안 기본값은 꺼짐(2319:2).
  bool _notificationsEnabled = false;

  /// 세션에서 읽은 프로필. 내 정보 수정에서 돌아오면 닉네임이 바뀐다(2353:290).
  late _Profile _profile = _Profile.of(widget.user ?? _currentUser());

  /// Supabase를 초기화하지 않은 위젯 테스트에서도 화면은 떠야 한다.
  static User? _currentUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _editProfile() async {
    final next = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (next == null || !mounted) return;
    setState(
      () => _profile = _Profile(
        nickname: '$next님',
        email: _profile.email,
        tenureDays: _profile.tenureDays,
      ),
    );
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
                nickname: _profile.nickname,
                email: _profile.email,
                tenureLabel: '식집사가 된 지 ${_profile.tenureDays}일째',
              ),
              const SizedBox(height: AppLayout.myPageCardGap),
              ProfileMenuCard(
                onEditProfile: _editProfile,
                onChangePassword: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangePasswordScreen(email: _profile.email),
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
