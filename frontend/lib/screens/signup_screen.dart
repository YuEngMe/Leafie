import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/signup_complete_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/onboarding_fields.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 이메일 형식만 검사 — 실제 서버 확인이 아니라 클라이언트 형식 체크.
final _emailFormatRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// 2315:2416의 03:21. 다 지나면 2395:42처럼 만료 문구로 바뀐다.
const _verificationWindow = Duration(minutes: 3, seconds: 21);

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailcontroller = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _loading = false;
  bool _allowPop = false;

  // Figma "04 앱 진입_회원가입" 기준(2026-08-05 확인): 이메일 형식만 먼저
  // 확인시키고, 실제 계정 생성(signUp)은 비밀번호·닉네임까지 다 받은 뒤
  // 맨 아래 "회원가입" 버튼에서 한 번에 호출한다. "발송" 버튼은 서버를
  // 호출하지 않는다 — 인증 메일은 signUp 호출 시 Supabase가 자동 발송.
  String? _emailFormatError;
  bool _emailChecked = false;
  Timer? _countdown;
  Duration _remaining = _verificationWindow;
  bool get _expired => _remaining <= Duration.zero;

  bool get _emailNotEmpty => _emailcontroller.text.trim().isNotEmpty;
  SignupEmailFieldVariant get _emailVariant {
    if (_emailChecked) return SignupEmailFieldVariant.verificationSent;
    return _emailNotEmpty
        ? SignupEmailFieldVariant.filled
        : SignupEmailFieldVariant.empty;
  }

  SignupPasswordFieldVariant _passwordVariant(
    TextEditingController controller,
    String? error,
  ) {
    if (error != null) return SignupPasswordFieldVariant.error;
    return controller.text.isEmpty
        ? SignupPasswordFieldVariant.empty
        : SignupPasswordFieldVariant.filled;
  }

  SignupNicknameFieldVariant get _nicknameVariant =>
      _nicknameController.text.trim().isEmpty
      ? SignupNicknameFieldVariant.empty
      : SignupNicknameFieldVariant.filled;

  bool get _canSubmit =>
      _emailChecked &&
      !_expired &&
      _passwordController.text.length >= 8 &&
      _passwordController.text == _passwordConfirmController.text &&
      _nicknameController.text.trim().isNotEmpty;

  String? get _passwordError {
    final password = _passwordController.text;
    if (password.isEmpty || password.length >= 8) return null;
    return '최소 8자리 이상 입력해야 합니다.';
  }

  String? get _passwordConfirmError {
    if (_passwordConfirmController.text.isEmpty ||
        _passwordController.text == _passwordConfirmController.text) {
      return null;
    }
    return '비밀번호가 일치하지 않습니다.';
  }

  @override
  void initState() {
    super.initState();
    // 발송 버튼의 활성 여부가 입력값에 달려 있어 컨트롤러를 직접 듣는다.
    _emailcontroller.addListener(() {
      setState(() {
        if (_emailChecked) {
          _emailChecked = false;
          _countdown?.cancel();
        }
      });
    });
    _passwordController.addListener(_refreshForm);
    _passwordConfirmController.addListener(_refreshForm);
    _nicknameController.addListener(_refreshForm);
  }

  void _refreshForm() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _passwordController.removeListener(_refreshForm);
    _passwordConfirmController.removeListener(_refreshForm);
    _nicknameController.removeListener(_refreshForm);
    _emailcontroller.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _checkEmailFormat() {
    final email = _emailcontroller.text.trim();
    setState(() {
      _emailFormatError = _emailFormatRegex.hasMatch(email)
          ? null
          : '이메일 형식이 올바르지 않습니다.';
      _emailChecked = _emailFormatError == null;
    });
    if (_emailChecked) _startCountdown();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _remaining = _verificationWindow;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _remaining -= const Duration(seconds: 1));
      if (_expired) timer.cancel();
    });
  }

  String get _countdownText {
    final left = _expired ? Duration.zero : _remaining;
    final m = left.inMinutes.toString().padLeft(2, '0');
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierColor: kModalBarrier,
      builder: (_) => const SignupAbortDialog(),
    );
    if (shouldExit != true || !mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _showTermsAndSignup() async {
    final agreed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: kModalBarrier,
      builder: (_) => const TermsAgreementSheet(),
    );
    if (agreed == true && mounted) await _signup();
  }

  Future<void> _signup() async {
    if (!_emailChecked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일을 먼저 확인해주세요.')));
      return;
    }
    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호는 최소 8자리 이상이어야 합니다.')));
      return;
    }
    if (_passwordController.text != _passwordConfirmController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailcontroller.text.trim(),
        password: _passwordController.text,
        data: {'leafie_nickname': _nicknameController.text},
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SignupCompleteScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: kBackgroundWhite,
        appBar: const YesoAppBar(title: '회원가입'),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.authHorizontalPadding,
                AppLayout.authFormTopPadding,
                AppLayout.authHorizontalPadding,
                AppLayout.authBottomActionPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight -
                      AppLayout.authFormTopPadding -
                      AppLayout.authBottomActionPadding,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SignupEmailField(
                        controller: _emailcontroller,
                        variant: _emailVariant,
                        errorText: _emailFormatError,
                        onSend: _checkEmailFormat,
                        countdownText: _countdownText,
                        // 2395:42: 시간이 다 되면 문구만 바뀌고 재발송은 열려 있다.
                        message: _expired ? '시간이 만료 되었습니다.' : null,
                      ),
                      const SizedBox(height: AppLayout.authFieldGap),
                      SignupPasswordField(
                        controller: _passwordController,
                        variant: _passwordVariant(
                          _passwordController,
                          _passwordError,
                        ),
                        errorText: _passwordError,
                      ),
                      const SizedBox(height: AppLayout.authFieldGap),
                      SignupPasswordField(
                        label: '비밀번호 확인',
                        controller: _passwordConfirmController,
                        variant: _passwordVariant(
                          _passwordConfirmController,
                          _passwordConfirmError,
                        ),
                        errorText: _passwordConfirmError,
                      ),
                      const SizedBox(height: AppLayout.authFieldGap),
                      SignupNicknameField(
                        controller: _nicknameController,
                        variant: _nicknameVariant,
                      ),
                      const Spacer(),
                      PrimaryButton(
                        label: _loading ? '가입 중...' : '시작하기',
                        variant: _loading || !_canSubmit
                            ? PrimaryButtonVariant.disabled
                            : PrimaryButtonVariant.enabled,
                        onPressed: _loading || !_canSubmit
                            ? null
                            : _showTermsAndSignup,
                        height: AppLayout.onboardingControlHeight,
                        textStyle: kLoginButtonStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
