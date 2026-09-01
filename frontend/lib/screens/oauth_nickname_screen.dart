import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/onboarding_copy.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/onboarding_fields.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

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
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_refreshForm);
  }

  void _refreshForm() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_refreshForm);
    _nicknameController.dispose();
    super.dispose();
  }

  /// 2395:37. 소셜 가입 도중 뒤로 나가면 회원가입 화면과 같은 모달을 띄운다.
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
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: kBackgroundWhite,
        appBar: YesoAppBar(title: '${widget.providerLabel} 로그인'),
        body: SafeArea(
          child: Padding(
            // 2395:38은 입력칸·버튼이 좌우 34로 대칭이다.
            padding: const EdgeInsets.fromLTRB(
              AppLayout.authHorizontalPadding,
              22,
              AppLayout.authHorizontalPadding,
              AppLayout.signupCompleteBottomGap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OnboardingCopy(
                  title: '닉네임을 설정해주세요!',
                  subtitle: '당신을 뭐라고 부르면 좋을까요?',
                ),
                const SizedBox(height: 46),
                SignupNicknameField(
                  controller: _nicknameController,
                  variant: _nicknameController.text.trim().isEmpty
                      ? SignupNicknameFieldVariant.empty
                      : SignupNicknameFieldVariant.filled,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const Spacer(),
                // 시안의 유일한 제출 경로다. 그동안은 키보드 done에만 걸려 있었다.
                PrimaryButton(
                  label: '다음',
                  variant: _nicknameController.text.trim().isEmpty
                      ? PrimaryButtonVariant.disabled
                      : PrimaryButtonVariant.enabled,
                  height: AppLayout.onboardingControlHeight,
                  textStyle: kLoginButtonStyle,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
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
