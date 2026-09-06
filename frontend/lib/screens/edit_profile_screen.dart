import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/user_api.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// Figma "내 정보 수정"(2316:6397, 2353:376, 2353:440).
///
/// 닉네임 한 칸만 고친다. 저장하면 바뀐 닉네임을 돌려주고 마이페이지가
/// 그 값으로 다시 그린다(2353:290).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.repository});

  final UserRepository? repository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // 시안(2316:6397)은 힌트만 있는 빈 칸이라 기존 값을 채우지 않는다.
  // 버튼이 늘 활성이라 입력을 지켜볼 이유도 없다.
  final _controller = TextEditingController();
  late final UserRepository _repository = widget.repository ?? UserApi();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final next = _controller.text.trim();
    if (next.isEmpty) {
      // 시안(2316:6397)은 빈 칸에서도 버튼이 오렌지라 눌린다. 비우고
      // 누른 경우는 안내로 막는다.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final profile = await _repository.updateNickname(next);
      if (mounted) Navigator.pop(context, profile.nickname);
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
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '내 정보 수정'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.myPageSubHorizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppLayout.editProfileTopGap),
              // 시안(2316:6397)은 마이페이지 쪽 화면들처럼 라벨만 입력칸보다
              // 11px 들여쓴다. 회원가입은 둘이 같은 x다.
              RoundedInputField(
                controller: _controller,
                label: '닉네임',
                labelIndent: AppLayout.editProfileLabelIndent,
                labelGap: 1,
                labelColor: kOrangeMain,
                hintText: '닉네임을 입력하세요.',
                height: AppLayout.onboardingControlHeight,
                centerVertically: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                enabled: !_submitting,
              ),
              const SizedBox(height: AppLayout.editProfileFieldToButtonGap),
              // 시안 2316:6397·2353:376 모두 버튼이 오렌지다. 회원가입과
              // 달리 빈 칸 상태의 비활성 시안이 없다.
              PrimaryButton(
                label: _submitting ? '변경 중...' : '변경하기',
                variant: PrimaryButtonVariant.enabled,
                textStyle: kLoginButtonStyle,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
