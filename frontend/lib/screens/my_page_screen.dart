import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/change_password_screen.dart';
import 'package:yeso_plant/screens/edit_profile_screen.dart';
import 'package:yeso_plant/screens/sensor_pairing_screen.dart';
import 'package:yeso_plant/screens/withdraw_screen.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/user_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/leafie_toast.dart';
import 'package:yeso_plant/widgets/mypage_cards.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// Figma 마이페이지 리뉴얼(6247:1145, 기본 4534:3044). 로그아웃 확인
/// 모달은 2353:624.
///
/// 시안은 하단 탭 바를 두고 뒤로 꺾쇠가 없다. 그래서 홈 탭 묶음
/// (MainTabShell) 안에서는 [inTab]으로 꺾쇠를 빼고 탭 바는 묶음이 그린다.
/// 독립 화면으로 열 때(예: 다이어리에서 연 캘린더)는 꺾쇠로 돌아간다.
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({
    super.key,
    this.user,
    this.repository,
    this.inTab = false,
    this.onNavTap,
  });

  /// 로그인한 사용자. 비워 두면 현재 세션에서 읽는다. 테스트에서만 넘긴다.
  final User? user;
  final UserRepository? repository;

  /// 하단 탭 묶음 안의 탭이면 true. 뒤로 꺾쇠를 그리지 않는다.
  final bool inTab;

  /// 탭 묶음의 탭 고르기. 내 정보 수정의 탭 바가 이것으로 다른 탭에 간다.
  final ValueChanged<FigmaNavIcon>? onNavTap;

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

  factory _Profile.fromApi(UserProfileData profile) => _Profile(
    nickname: '${profile.nickname}님',
    email: profile.email,
    tenureDays: profile.gardenerDays,
  );

  final String nickname;
  final String email;
  final int tenureDays;
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _notificationsEnabled = false;
  late final UserRepository _repository = widget.repository ?? UserApi();

  /// 세션에서 읽은 프로필. 내 정보 수정에서 돌아오면 닉네임이 바뀐다(2353:290).
  late _Profile _profile = _Profile.of(widget.user ?? _currentUser());

  @override
  void initState() {
    super.initState();
    if (widget.user == null || widget.repository != null) _loadProfile();
  }

  /// Supabase를 초기화하지 않은 위젯 테스트에서도 화면은 떠야 한다.
  static User? _currentUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _repository.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = _Profile.fromApi(profile);
        _notificationsEnabled = profile.pushEnabled;
      });
    } on LeafieApiException {
      // 세션 metadata fallback을 유지한다. 마이페이지 자체는 계속 쓸 수 있다.
    }
  }

  Future<void> _editProfile() async {
    final next = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => EditProfileScreen(
          repository: _repository,
          onNavTap: switch (widget.onNavTap) {
            null => null,
            final select => (tab) {
              // 마이 탭이면 마이페이지로만 돌아가고, 다른 탭이면 돌아간 뒤
              // 그 탭을 고른다.
              Navigator.pop(routeContext);
              if (tab != FigmaNavIcon.my) select(tab);
            },
          },
        ),
      ),
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

  Future<void> _updateNotifications(bool value) async {
    final previous = _notificationsEnabled;
    setState(() => _notificationsEnabled = value);
    // 3562:196 켤 때 "알림이 설정되었어요!", 4534:3094 끌 때 "알림이
    // 해제되었어요!" 토스트(y 744, 종 아이콘).
    showLeafieToast(
      context,
      text: value ? '알림이 설정되었어요!' : '알림이 해제되었어요!',
      top: MediaQuery.paddingOf(context).top + (744 - 46),
      bell: true,
    );
    if (widget.user != null && widget.repository == null) return;
    try {
      final saved = await _repository.updateNotificationSettings(value);
      if (mounted) setState(() => _notificationsEnabled = saved);
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = previous);
      showLeafieToast(context, text: error.message);
    }
  }

  // 시안 4534:3044의 '센서 기기 등록' → 기기연결(5732:849) 흐름.
  void _registerSensor() {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const SensorPairingScreen()),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showConfirmDialog(
      context,
      barrierColor: kModalBarrier,
      dialog: const SignOutConfirmDialog(),
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
      appBar: YesoAppBar(title: '마이페이지', showBack: !widget.inTab),
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
                onRegisterSensor: _registerSensor,
                onWithdraw: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WithdrawScreen(repository: _repository),
                  ),
                ),
                onSignOut: _confirmSignOut,
                notificationsEnabled: _notificationsEnabled,
                onNotificationsChanged: _updateNotifications,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
