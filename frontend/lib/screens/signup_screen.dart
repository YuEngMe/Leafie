import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/signup_complete_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/app_text_field.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 이메일 형식만 검사 — 실제 서버 확인이 아니라 클라이언트 형식 체크.
final _emailFormatRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

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

  // Figma "04 앱 진입_회원가입" 기준(2026-08-05 확인): 이메일 형식만 먼저
  // 확인시키고, 실제 계정 생성(signUp)은 비밀번호·닉네임까지 다 받은 뒤
  // 맨 아래 "회원가입" 버튼에서 한 번에 호출한다. "발송" 버튼은 서버를
  // 호출하지 않는다 — 인증 메일은 signUp 호출 시 Supabase가 자동 발송.
  String? _emailFormatError;
  bool _emailChecked = false;

  void _checkEmailFormat() {
    final email = _emailcontroller.text.trim();
    setState(() {
      _emailFormatError = _emailFormatRegex.hasMatch(email)
          ? null
          : '이메일 형식이 올바르지 않습니다.';
      _emailChecked = _emailFormatError == null;
    });
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
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이메일',
                style: const TextStyle(
                  color: kLabelGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailcontroller,
                      enabled: !_emailChecked,
                      onChanged: (_) {
                        if (_emailChecked) {
                          setState(() => _emailChecked = false);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '이메일을 입력하세요.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kBorderGreen),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _emailChecked ? null : _checkEmailFormat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kButtonGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_emailChecked ? '확인 완료' : '발송'),
                  ),
                ],
              ),
              if (_emailFormatError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _emailFormatError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              AppTextField(
                label: '비밀번호',
                hintText: '최소 8자리 이상 입력해주세요.',
                obscureText: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: '비밀번호 확인',
                obscureText: true,
                controller: _passwordConfirmController,
              ),
              const SizedBox(height: 16),
              AppTextField(label: '닉네임', controller: _nicknameController),
              const SizedBox(height: 32),
              PrimaryButton(
                label: _loading ? '가입 중...' : '회원가입',
                onPressed: _loading ? () {} : _signup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
