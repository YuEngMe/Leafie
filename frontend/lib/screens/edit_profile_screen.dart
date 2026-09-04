import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
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
  const EditProfileScreen({super.key, required this.nickname});

  /// 현재 닉네임. 시안 2316:6397은 빈 칸에서 시작한다.
  final String nickname;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // 시안(2316:6397)은 힌트만 있는 빈 칸이라 기존 값을 채우지 않는다.
  // 버튼이 늘 활성이라 입력을 지켜볼 이유도 없다.
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _controller.text.trim();
    if (next.isEmpty) {
      // 시안(2316:6397)은 빈 칸에서도 버튼이 오렌지라 눌린다. 비우고
      // 누른 경우는 안내로 막는다.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }
    // TODO(1-E): dio 붙이면 PATCH /users/me로 닉네임을 먼저 보낸다.
    Navigator.pop(context, next);
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
              ),
              const SizedBox(height: AppLayout.editProfileFieldToButtonGap),
              // 시안 2316:6397·2353:376 모두 버튼이 오렌지다. 회원가입과
              // 달리 빈 칸 상태의 비활성 시안이 없다.
              PrimaryButton(
                label: '변경하기',
                variant: PrimaryButtonVariant.enabled,
                textStyle: kLoginButtonStyle,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
