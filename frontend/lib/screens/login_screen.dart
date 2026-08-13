import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/password_reset_screen.dart';
import 'package:yeso_plant/screens/signup_screen.dart';
import 'package:yeso_plant/widgets/app_text_field.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/social_login_button.dart';
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

  void _showNotReadyYet(String provider) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$provider 로그인은 준비 중이에요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 상단 제목
                const Text(
                  '로그인',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 40),

                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 40),

                AppTextField(label: '이메일', controller: _emailController),
                const SizedBox(height: 16),
                AppTextField(
                  label: '비밀번호',
                  obscureText: true,
                  controller: _passwordController,
                  errorText: _passwordError,
                ),
                const SizedBox(height: 12),

                // 회원가입 / 비밀번호 재설정 (양쪽 끝 정렬)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      ),
                      child: const Text('회원가입'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PasswordResetScreen(),
                        ),
                      ),
                      child: const Text('비밀번호 재설정'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                PrimaryButton(
                  label: _loading ? '로그인 중...' : '로그인',
                  onPressed: _loading ? () {} : _login,
                ),
                const SizedBox(height: 40),

                // 간편로그인 구분선
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade400)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '간편로그인',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade400)),
                  ],
                ),
                const SizedBox(height: 24),

                // 간편로그인 버튼들 (네이버·카카오·애플)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SocialLoginButton(
                      label: '네이버',
                      onTap: () => _signInWithOAuth(
                        const OAuthProvider('custom:naver'),
                        scopes: 'openid profile',
                      ),
                    ),
                    SocialLoginButton(
                      label: '카카오',
                      onTap: () => _signInWithOAuth(OAuthProvider.kakao),
                    ),
                    SocialLoginButton(
                      label: '애플',
                      onTap: () => _showNotReadyYet('애플'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
