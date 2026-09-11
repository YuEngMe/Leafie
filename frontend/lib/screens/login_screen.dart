import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/password_reset_screen.dart';
import 'package:yeso_plant/screens/signup_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/brand_logo.dart';
import 'package:yeso_plant/widgets/login_credentials_form.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/social_login_section.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef OAuthSignInLauncher =
    Future<bool> Function(
      OAuthProvider provider, {
      String? redirectTo,
      String? scopes,
      LaunchMode authScreenLaunchMode,
    });

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.oauthSignIn});

  final OAuthSignInLauncher? oauthSignIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _passwordError;

  LoginEmailFieldVariant get _emailVariant => _emailController.text.isEmpty
      ? LoginEmailFieldVariant.empty
      : LoginEmailFieldVariant.filled;

  LoginPasswordFieldVariant get _passwordVariant => _passwordError == null
      ? LoginPasswordFieldVariant.standard
      : LoginPasswordFieldVariant.error;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_refreshForm);
    _passwordController.addListener(_refreshForm);
  }

  void _refreshForm() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.removeListener(_refreshForm);
    _passwordController.removeListener(_refreshForm);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _passwordError = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인 성공')));
      }
    } on AuthException catch (e) {
      // Figma "03 앱 진입_로그인"(2026-08-09 확인): 로그인 실패는 비밀번호
      // 입력칸 아래 인라인 에러로 표시한다. 서버 메시지가 있으면 그대로 쓰고,
      // 없을 때만 Figma 기본 문구("비밀번호가 옳지 않습니다.")로 대체한다.
      if (mounted) {
        setState(
          () => _passwordError = e.message.isNotEmpty
              ? e.message
              : '비밀번호가 옳지 않습니다.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 딥링크 콜백 URL — android/ios에 등록해둔 yesoplant://login-callback 스킴과 일치해야 함.
  static const _oauthRedirectUrl = 'yesoplant://login-callback';

  Future<void> _signInWithOAuth(
    OAuthProvider provider, {
    String? scopes,
  }) async {
    try {
      final launched = widget.oauthSignIn == null
          ? await Supabase.instance.client.auth.signInWithOAuth(
              provider,
              redirectTo: _oauthRedirectUrl,
              scopes: scopes,
              authScreenLaunchMode: LaunchMode.externalApplication,
            )
          : await widget.oauthSignIn!(
              provider,
              redirectTo: _oauthRedirectUrl,
              scopes: scopes,
              authScreenLaunchMode: LaunchMode.externalApplication,
            );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 화면을 열지 못했어요. 다시 시도해주세요.')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.authHorizontalPadding,
          ),
          child: Column(
            children: [
              const SizedBox(height: AppLayout.loginTitleTopGap),
              Text('로그인', style: kBodyStyle),
              const SizedBox(height: AppLayout.loginTitleToLogoGap),
              const BrandLogo(
                width: AppLayout.loginLogoWidth,
                markWidthFactor: AppLayout.loginLogoMarkWidthFactor,
              ),
              const SizedBox(height: AppLayout.loginLogoToFormGap),

              LoginCredentialsForm(
                emailController: _emailController,
                passwordController: _passwordController,
                emailVariant: _emailVariant,
                passwordVariant: _passwordVariant,
                passwordError: _passwordError,
                onSignup: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                onForgotPassword: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PasswordResetScreen(),
                  ),
                ),
              ),
              const SizedBox(height: AppLayout.loginLinkToButtonGap),

              PrimaryButton(
                label: _loading ? '로그인 중...' : '로그인',
                variant: _loading
                    ? PrimaryButtonVariant.disabled
                    : PrimaryButtonVariant.enabled,
                onPressed: _loading ? null : _login,
                textStyle: kLoginButtonStyle,
                height: AppLayout.onboardingControlHeight,
              ),
              const SizedBox(height: AppLayout.loginButtonToDividerGap),

              SocialLoginSection(
                onNaver: () => _signInWithOAuth(
                  const OAuthProvider('custom:naver'),
                  scopes: 'openid profile',
                ),
                onKakao: () => _signInWithOAuth(OAuthProvider.kakao),
              ),
              const SizedBox(height: AppLayout.loginBottomGap),
            ],
          ),
        ),
      ),
    );
  }
}
