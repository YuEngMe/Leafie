import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_glyphs.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// Figma "회원 탈퇴"(2570:1994)와 완료 화면(2570:11895).
///
/// 안내 세 줄을 읽고 동의해야만 탈퇴 버튼이 열린다.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  /// 시안 2570:2038·2046·2049.
  static const List<String> notices = [
    '탈퇴 후에는 데이터 복구가 불가능합니다.',
    '다이어리, 프로필 등 모든 정보가 삭제 됩니다.',
    '계정을 삭제하면 캐릭터의 모든 정보가 삭제됩니다.',
  ];

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  bool _agreed = false;
  bool _submitting = false;

  Future<void> _withdraw() async {
    setState(() => _submitting = true);
    try {
      // TODO(1-E): dio 붙이면 DELETE /users/me를 먼저 부르고, 성공하면
      // 세션을 정리한다. 지금은 로그아웃까지만 한다.
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WithdrawCompleteScreen()),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _agreed && !_submitting;
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '회원 탈퇴'),
      body: SafeArea(
        child: Stack(
          children: [
            // 시안이 각 요소를 절대 위치로 잡아 좌표를 그대로 옮긴다.
            const Positioned(
              left: 45,
              top: AppLayout.withdrawTopGap,
              child: Text('리피 탈퇴 전 확인하세요', style: kTitleStyle),
            ),
            Positioned(
              left: 45,
              top: 83,
              child: Text(
                '정말 탈퇴하시나요? 너무 아쉬워요..',
                style: kSmallStyle.copyWith(
                  height: 1,
                  color: kOnboardingSubtitle,
                ),
              ),
            ),
            const Positioned(
              left: 45,
              top: 149,
              width: 312,
              child: _NoticeBox(),
            ),
            Positioned(
              left: 45,
              top: 265,
              child: _ConsentRow(
                checked: _agreed,
                onTap: () => setState(() => _agreed = !_agreed),
              ),
            ),
            // 2570:2108. 폭 354라 좌우 24에서 시작한다.
            const Positioned(
              left: 24,
              top: 354,
              width: 354,
              child: Divider(height: 1, thickness: 1, color: kGaugeTrack),
            ),
            Positioned(
              left: AppLayout.myPageSubHorizontalPadding,
              right: AppLayout.myPageSubHorizontalPadding,
              top: 374,
              child: PrimaryButton(
                label: _submitting ? '탈퇴 중...' : '탈퇴하기',
                variant: canSubmit
                    ? PrimaryButtonVariant.enabled
                    : PrimaryButtonVariant.disabled,
                textStyle: kLoginButtonStyle,
                onPressed: canSubmit ? _withdraw : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 안내 세 줄을 담은 상자. 시안(2570:2052)은 테두리 대신 안쪽 그림자를 쓴다.
class _NoticeBox extends StatelessWidget {
  const _NoticeBox();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kBackgroundWhite,
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(1, 14, 13, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, notice) in WithdrawScreen.notices.indexed) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 시안은 글머리 기호를 16px 문자로 찍는다.
                  const SizedBox(
                    width: 20,
                    child: Text(
                      '·',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 16,
                        height: 23 / 16,
                        color: kOnboardingSubtitle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      notice,
                      style: kSmallStyle.copyWith(
                        height: 23 / 14,
                        color: kOnboardingSubtitle,
                      ),
                    ),
                  ),
                ],
              ),
              // 줄 사이만 5px. 마지막 줄 뒤에는 붙이지 않는다.
              if (index < WithdrawScreen.notices.length - 1)
                const SizedBox(height: 5),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FigmaConsentCheckbox(checked: checked),
          // 체크박스 x=45, 글자 x=73이라 사이가 5px이다.
          const SizedBox(width: 5),
          Text(
            '안내 사항을 모두 확인하였으며, 이에 동의합니다.',
            style: kSmallStyle.copyWith(height: 1, color: kOnboardingSubtitle),
          ),
        ],
      ),
    );
  }
}

/// Figma node 2570:11895. 탈퇴가 끝났음을 알리는 화면.
class WithdrawCompleteScreen extends StatelessWidget {
  const WithdrawCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              top: 341,
              child: Text(
                '탈퇴가\n완료되었습니다',
                textAlign: TextAlign.center,
                style: kTitleStyle,
              ),
            ),
            Positioned(
              left: AppLayout.myPageSubHorizontalPadding,
              right: AppLayout.myPageSubHorizontalPadding,
              top: 744,
              child: PrimaryButton(
                label: '확인',
                variant: PrimaryButtonVariant.enabled,
                textStyle: kLoginButtonStyle,
                // 세션은 이미 끊겼다. 첫 화면(로그인)까지 스택을 걷어낸다.
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
