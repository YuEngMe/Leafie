import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/signup_screen.dart';
import 'package:yeso_plant/widgets/app_text_field.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/social_login_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 40),

                const AppTextField(label: '이메일'),
                const SizedBox(height: 16),
                const AppTextField(label: '비밀번호', obscureText: true),
                const SizedBox(height: 12),

                // 회원가입 / 비밀번호 찾기 (양쪽 끝 정렬)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignupScreen(),
                        ),
                      ),
                      child: const Text('회원가입'),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('비밀번호 찾기'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                PrimaryButton(label: '로그인', onPressed: () {}),
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

                // 간편로그인 버튼들 (네이버·카카오·애플) — 자리만, 연동은 다음 단계
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SocialLoginButton(label: '네이버', onTap: () {}),
                    SocialLoginButton(label: '카카오', onTap: () {}),
                    SocialLoginButton(label: '애플', onTap: () {}),
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
