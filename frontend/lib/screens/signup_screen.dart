import 'package:flutter/material.dart';
import 'package:yeso_plant/widgets/app_text_field.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const AppTextField(label: '이메일'),
              const SizedBox(height: 16),
              const AppTextField(label: '비밀번호', obscureText: true),
              const SizedBox(height: 16),
              const AppTextField(label: '비밀번호 확인', obscureText: true),
              const SizedBox(height: 16),
              const AppTextField(label: '닉네임'),
              const SizedBox(height: 32),
              PrimaryButton(label: '회원가입', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }
}
