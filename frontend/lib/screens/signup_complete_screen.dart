import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

// Figma "04 앱 진입_회원가입"의 완료 상태 화면 (2026-08-05 확인).
class SignupCompleteScreen extends StatelessWidget {
  const SignupCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: kBorderGreen,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('로고'),
              ),
              const SizedBox(height: 32),
              const Text(
                '회원가입이 완료되었습니다.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '사진, 물주기, 분갈이, 기분 기록을 모아\n식물 상태 변화를 볼 수 있어요.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              PrimaryButton(
                label: '시작하기',
                // 로그인 화면까지 스택을 걷어내고 돌아간다 — 여기서 이메일 인증을
                // 실제로 완료했는지는 로그인 시도에서 서버가 다시 검증한다.
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
