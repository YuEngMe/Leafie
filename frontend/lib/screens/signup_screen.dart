import 'package:flutter/material.dart';
import 'package:yeso_plant/widgets/app_text_field.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _signup() async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('회원가입 성공! 이메일을 확인해주세요.')));
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
            children: [
              AppTextField(label: '이메일', controller: _emailcontroller),
              const SizedBox(height: 16),
              AppTextField(
                label: '비밀번호',
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
