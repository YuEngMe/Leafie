import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/main.dart' show oauthRedirectUrl;
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/onboarding_fields.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 마이페이지 비밀번호 변경(2353:142, 2346:2639, 2346:2681, 2346:2596,
/// 2353:212, 2346:2722)과 완료 화면(2346:2773).
///
/// 로그인 전 비밀번호 재설정(`PasswordResetScreen`)과 다르다. 저쪽은 네
/// 단계를 화면째 갈아끼우지만, 여기는 한 화면에 세 칸을 모두 두고 이메일
/// 인증 상태만 바뀐다.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.email, this.auth});

  /// 로그인한 계정의 이메일.
  final String email;

  /// Supabase를 초기화하지 않는 위젯 테스트에서 갈아끼운다.
  final ChangePasswordAuth? auth;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

/// 비밀번호 변경이 쓰는 인증 동작. 실제 구현은 Supabase를 부르고,
/// 테스트는 같은 모양의 가짜를 넘긴다.
class ChangePasswordAuth {
  const ChangePasswordAuth();

  /// 본인 확인 메일을 보낸다. 메일의 링크를 누르면 딥링크로 앱에 돌아오고
  /// main.dart가 그 세션을 받는다.
  Future<void> sendLink(String email) =>
      Supabase.instance.client.auth.signInWithOtp(
        // 오타로 없는 주소를 넣으면 새 계정이 생기는 대신 실패해야 한다.
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: oauthRedirectUrl,
      );

  Future<void> updatePassword(String password) => Supabase.instance.client.auth
      .updateUser(UserAttributes(password: password));

  /// 링크를 눌러 돌아왔을 때 열리는 세션.
  ///
  /// Supabase를 초기화하지 않은 위젯 테스트에서도 화면은 떠야 하므로
  /// 없으면 빈 스트림을 준다.
  Stream<AuthState> onSignedIn() {
    try {
      return Supabase.instance.client.auth.onAuthStateChange.where(
        (state) => state.event == AuthChangeEvent.signedIn,
      );
    } catch (_) {
      return const Stream.empty();
    }
  }
}

/// 이메일 칸 오른쪽 버튼이 밟는 단계.
enum _Verification {
  /// 아직 안 보냄 — '발송'(2353:142, 2346:2639).
  idle('발송'),

  /// 메일을 보낸 뒤 — '재발송'(2346:2681).
  sent('재발송'),

  /// 링크를 눌러 본인 확인이 끝남 — '완료'(2346:2596).
  verified('완료');

  const _Verification(this.label);

  final String label;
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Verification _step = _Verification.idle;
  String? _emailError;
  String? _confirmError;
  bool _submitting = false;
  bool _sending = false;

  ChangePasswordAuth get _auth => widget.auth ?? const ChangePasswordAuth();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // 본인 계정으로만 보낼 수 있으니 세션 이메일을 미리 채운다.
    _emailController.text = widget.email;
    // 메일의 링크를 누르면 딥링크로 돌아와 새 세션이 열린다. 그게 곧
    // 본인 확인이라 '완료'로 넘긴다.
    _authSub = _auth.onSignedIn().listen((_) {
      if (mounted) setState(() => _step = _Verification.verified);
    });
    for (final c in [
      _emailController,
      _passwordController,
      _confirmController,
    ]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authSub?.cancel();
    for (final c in [
      _emailController,
      _passwordController,
      _confirmController,
    ]) {
      c
        ..removeListener(_refresh)
        ..dispose();
    }
    super.dispose();
  }

  bool get _canSend =>
      _emailController.text.trim().isNotEmpty &&
      !_sending &&
      _step != _Verification.verified;

  bool get _canSubmit =>
      _step == _Verification.verified &&
      _passwordController.text.isNotEmpty &&
      _confirmController.text.isNotEmpty &&
      !_submitting;

  /// 발송/재발송. 메일의 링크를 누르면 딥링크로 돌아와 인증이 끝난다.
  Future<void> _sendLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _sending = true;
      _emailError = null;
    });
    try {
      await _auth.sendLink(email);
      if (mounted) setState(() => _step = _Verification.sent);
    } on AuthException catch (e) {
      if (mounted) setState(() => _emailError = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submit() async {
    if (_passwordController.text != _confirmController.text) {
      setState(() => _confirmError = '비밀번호가 일치하지 않습니다.');
      return;
    }
    setState(() {
      _confirmError = null;
      _submitting = true;
    });
    try {
      await _auth.updatePassword(_passwordController.text);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChangePasswordDoneScreen()),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _confirmError = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '비밀번호 재설정'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.myPageSubHorizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 앱바 아래(92)에서 첫 라벨(145)까지.
              const SizedBox(height: AppLayout.editProfileTopGap),
              SignupEmailField(
                controller: _emailController,
                variant: _emailController.text.isEmpty
                    ? SignupEmailFieldVariant.empty
                    : SignupEmailFieldVariant.filled,
                sendLabel: _step.label,
                labelIndent: AppLayout.editProfileLabelIndent,
                errorText: _emailError,
                onSend: _canSend ? _sendLink : null,
              ),
              // 이메일 칸 바닥(220)에서 다음 라벨(255)까지.
              const SizedBox(height: AppLayout.changePasswordFieldGap),
              SignupPasswordField(
                controller: _passwordController,
                label: '새 비밀번호',
                labelIndent: AppLayout.editProfileLabelIndent,
                variant: _passwordController.text.isEmpty
                    ? SignupPasswordFieldVariant.empty
                    : SignupPasswordFieldVariant.filled,
              ),
              const SizedBox(height: AppLayout.changePasswordFieldGap),
              SignupPasswordField(
                controller: _confirmController,
                label: '비밀번호 확인',
                labelIndent: AppLayout.editProfileLabelIndent,
                variant: _confirmError != null
                    ? SignupPasswordFieldVariant.error
                    : _confirmController.text.isEmpty
                    ? SignupPasswordFieldVariant.empty
                    : SignupPasswordFieldVariant.filled,
                errorText: _confirmError,
              ),
              const Spacer(),
              PrimaryButton(
                label: _submitting ? '변경 중...' : '변경하기',
                variant: _canSubmit
                    ? PrimaryButtonVariant.enabled
                    : PrimaryButtonVariant.disabled,
                textStyle: kLoginButtonStyle,
                onPressed: _canSubmit ? _submit : null,
              ),
              // 버튼 바닥(841)에서 화면 아래(874)까지. 상태바를 걷어낸
              // SafeArea가 Spacer를 늘리므로 46을 더해 둔다.
              const SizedBox(height: AppLayout.myPageBottomGap),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma node 2346:2773. 비밀번호를 바꾼 뒤 뜨는 화면.
class ChangePasswordDoneScreen extends StatelessWidget {
  const ChangePasswordDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              // 시안 2346:2795는 y=387, 상태바를 빼면 341.
              top: 341,
              child: Text(
                '비밀번호 설정이\n완료되었습니다',
                textAlign: TextAlign.center,
                style: kTitleStyle,
              ),
            ),
            Positioned(
              left: AppLayout.myPageSubHorizontalPadding,
              right: AppLayout.myPageSubHorizontalPadding,
              top: 744,
              child: PrimaryButton(
                label: '확인',
                variant: PrimaryButtonVariant.enabled,
                textStyle: kLoginButtonStyle,
                // 마이페이지까지 돌아간다.
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
