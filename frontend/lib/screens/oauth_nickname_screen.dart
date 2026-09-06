import 'package:flutter/material.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/user_api.dart';
import 'package:yeso_plant/screens/home_screen.dart';
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
// main.dart가 GET /users/me의 profile_completed를 확인해 신규 사용자만 보낸다.
class OAuthNicknameScreen extends StatefulWidget {
  const OAuthNicknameScreen({
    super.key,
    required this.providerLabel,
    this.repository,
  });

  // AppBar 타이틀에 쓰는 제공자 이름(예: '카카오톡', '네이버'). Figma 시안은
  // 제공자별로 "OO 로그인" 타이틀을 쓴다.
  final String providerLabel;
  final UserRepository? repository;

  @override
  State<OAuthNicknameScreen> createState() => _OAuthNicknameScreenState();
}

class _OAuthNicknameScreenState extends State<OAuthNicknameScreen> {
  final _nicknameController = TextEditingController();
  bool _submitting = false;
  bool _allowPop = false;
  late final UserRepository _repository = widget.repository ?? UserApi();

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
      await _repository.updateNickname(nickname);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
            // 2395:38은 입력칸·버튼이 좌우 34로 대칭이다. 타이틀 top 140
            // (2307:751) = 앱바 92 + 48.
            padding: const EdgeInsets.fromLTRB(
              AppLayout.authHorizontalPadding,
              48,
              AppLayout.authHorizontalPadding,
              AppLayout.signupCompleteBottomGap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 문구는 라벨처럼 입력칸보다 11px 들여쓴다(2307:751 x45).
                // 타이틀 140 → 부제 175라 21px 글자 아래 14를 띄운다.
                const Padding(
                  padding: EdgeInsets.only(left: AppLayout.inputLabelIndent),
                  child: OnboardingCopy(
                    title: '닉네임을 설정해주세요!',
                    subtitle: '당신을 뭐라고 부르면 좋을까요?',
                    gap: 14,
                  ),
                ),
                // 부제 bottom 189 → 라벨 top 237 (2307:744).
                const SizedBox(height: 48),
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
