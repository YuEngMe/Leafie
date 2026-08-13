import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/widgets/app_text_field.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

// Figma "04 앱 진입_회원가입"의 소셜 닉네임 설정 화면(2026-08-11 확인).
// 카카오·네이버 등 소셜 로그인은 회원가입 화면이 없어 닉네임을 못 받으므로,
// 최초 로그인 시 이 화면에서 한 번 물어본다.
//
// TODO: 신규 가입자 판단 기준이 아직 미확정(체크리스트 "팀에 확인 필요한 것"
// 참고) — 지금은 이 화면 자체만 만들어두고, main.dart의 signedIn 이벤트에서
// "신규 사용자면 여기로 이동" 연결은 판단 기준이 정해진 뒤에 한다.
class OAuthNicknameScreen extends StatefulWidget {
  const OAuthNicknameScreen({super.key, required this.providerLabel});

  // AppBar 타이틀에 쓰는 제공자 이름(예: '카카오톡', '네이버'). Figma 시안은
  // 제공자별로 "OO 로그인" 타이틀을 쓴다.
  final String providerLabel;

  @override
  State<OAuthNicknameScreen> createState() => _OAuthNicknameScreenState();
}

class _OAuthNicknameScreenState extends State<OAuthNicknameScreen> {
  final _nicknameController = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await _saveNickname(nickname);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.providerLabel} 로그인')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '닉네임을 설정해주세요!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '리피에서 사용할 이름이에요.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              AppTextField(
                label: '닉네임',
                hintText: '닉네임을 입력하세요.',
                controller: _nicknameController,
              ),
              const Spacer(),
              PrimaryButton(
                label: _submitting ? '저장 중...' : '회원가입',
                onPressed: _submitting ? () {} : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// TODO(1-E): dio 붙이면 이 함수 내부만 PATCH /users/me 실제 호출로 교체.
// Supabase user_metadata에 임시로 저장해 흐름은 지금 바로 확인 가능하게 한다.
Future<void> _saveNickname(String nickname) async {
  await Supabase.instance.client.auth.updateUser(
    UserAttributes(data: {'leafie_nickname': nickname}),
  );
}
