import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_glyphs.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

/// Figma node 2353:1045의 회원가입 중단 확인 모달.
class SignupAbortDialog extends StatelessWidget {
  const SignupAbortDialog({super.key});

  @override
  Widget build(BuildContext context) =>
      const ConfirmDialog(message: '회원가입을 중단하시겠습니까?');
}

/// Figma node 2353:721의 로그아웃 확인 모달.
class SignOutConfirmDialog extends StatelessWidget {
  const SignOutConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) =>
      const ConfirmDialog(message: '로그아웃 하시겠습니까?');
}

/// Figma node 2346:2532의 캐릭터 삭제 확인 모달.
class CharacterDeleteDialog extends StatelessWidget {
  const CharacterDeleteDialog({super.key, required this.tenureLabel});

  /// "함께한지 130일이에요"처럼 완성된 문구를 그대로 받는다.
  final String tenureLabel;

  @override
  Widget build(BuildContext context) =>
      ConfirmDialog(message: '삭제하시겠습니까?', subtitle: tenureLabel);
}

/// 확인 모달 셋(2353:1045, 2353:721, 2346:2532)이 좌표까지 같아 문구만 바꾼다.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.message,
    this.subtitle,
    this.confirmLabel = '네',
    this.cancelLabel = '아니오',
  });

  final String message;

  /// 캐릭터 삭제(2346:2529)처럼 본문 아래 한 줄이 더 붙는 경우에만 넘긴다.
  final String? subtitle;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      // Figma가 절대 위치로 잡은 모달이라 Stack으로 좌표를 그대로 옮긴다.
      child: SizedBox(
        width: 308,
        height: 158.829,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: kBackgroundWhite,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Color(0x26000000), blurRadius: 5.366),
                ],
              ),
              child: const SizedBox.expand(),
            ),
            // 본문 세로 중심 35.57% x 158.829.
            Positioned(
              left: 0,
              right: 0,
              // 부제가 붙으면 본문 블록이 5px 위로 올라간다(2346:2525).
              top: subtitle == null ? 45 : 40,
              height: 23,
              child: Center(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 23 / 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            if (subtitle case final subtitle?)
              Positioned(
                left: 0,
                right: 0,
                top: 68,
                height: 14,
                child: Center(
                  child: Text(
                    subtitle,
                    style: kCaptionStyle.copyWith(
                      color: kGrayLightest,
                      height: 1,
                    ),
                  ),
                ),
              ),
            // 구분선 2353:1042. 좌우 8.01%, 위 66.89%.
            const Positioned(
              left: 24.7,
              top: 106.2,
              child: FigmaDialogDivider(),
            ),
            // 아래 두 버튼은 구분선이 나눈 좌우 절반을 그대로 채운다.
            Positioned(
              left: 0,
              top: 106.2,
              width: 154,
              bottom: 0,
              child: _AbortDialogAction(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
            Positioned(
              left: 154,
              top: 106.2,
              width: 154,
              bottom: 0,
              child: _AbortDialogAction(
                label: cancelLabel,
                color: kTextLight,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbortDialogAction extends StatelessWidget {
  const _AbortDialogAction({
    required this.label,
    required this.onPressed,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(shape: const RoundedRectangleBorder()),
      child: Text(label, style: kItemStyle.copyWith(color: color)),
    );
  }
}

/// Figma node 2315:2508의 약관 동의 바텀시트.
class TermsAgreementSheet extends StatefulWidget {
  const TermsAgreementSheet({super.key, this.initiallyChecked = false});

  final bool initiallyChecked;

  @override
  State<TermsAgreementSheet> createState() => _TermsAgreementSheetState();
}

class _TermsAgreementSheetState extends State<TermsAgreementSheet> {
  static const _labels = [
    '(필수) 서비스 약관',
    '(필수) 서비스 약관',
    '(필수) 서비스 약관',
    '(필수) 서비스 약관',
  ];

  late final List<bool> _checked = List.filled(
    _labels.length,
    widget.initiallyChecked,
  );

  bool get _allChecked => _checked.every((value) => value);
  bool get _requiredChecked => _allChecked;

  void _toggleAll() {
    final next = !_allChecked;
    setState(() {
      for (var index = 0; index < _checked.length; index++) {
        _checked[index] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 341,
      decoration: const BoxDecoration(
        color: kBackgroundWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 5)],
      ),
      padding: const EdgeInsets.fromLTRB(
        AppLayout.authHorizontalPadding,
        18,
        AppLayout.authHorizontalPadding,
        33,
      ),
      child: Column(
        children: [
          _AgreementPill(checked: _allChecked, onTap: _toggleAll),
          const SizedBox(height: 8),
          for (var index = 0; index < _labels.length; index++)
            _AgreementRow(
              label: _labels[index],
              checked: _checked[index],
              onTap: () => setState(() => _checked[index] = !_checked[index]),
            ),
          const Spacer(),
          PrimaryButton(
            label: '확인',
            variant: _requiredChecked
                ? PrimaryButtonVariant.enabled
                : PrimaryButtonVariant.disabled,
            height: AppLayout.onboardingControlHeight,
            textStyle: kLoginButtonStyle,
            onPressed: _requiredChecked
                ? () => Navigator.of(context).pop(true)
                : null,
          ),
        ],
      ),
    );
  }
}

class _AgreementPill extends StatelessWidget {
  const _AgreementPill({required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        height: 51,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: kBackgroundWhite,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 2)],
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: FigmaCheckedCircle.figmaCircleSize,
              // Figma 컴포넌트에 해제 상태가 없어 회색 테두리 원으로 대체했다.
              child: checked
                  ? const FigmaCheckedCircle()
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kGrayLightest, width: 2),
                      ),
                    ),
            ),
            // 텍스트 좌측 55px - 원 좌측 15px - 원 지름 26px.
            const SizedBox(width: 14),
            const Text('약관 모두 동의', style: kItemStyle),
          ],
        ),
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        // 행 간격 11.43% x 341 = 39px(node 2315:2488 -> 2315:2492).
        height: 39,
        child: Row(
          children: [
            // 체크 좌측 14.5% x 403 - 34px 패딩.
            const SizedBox(width: 24.4),
            SizedBox.fromSize(
              size: FigmaCheckMark.figmaSize,
              // Figma 컴포넌트에 해제 상태가 없어 회색 체크로 대체했다.
              child: FigmaCheckMark(color: checked ? kOrange : kGrayLightest),
            ),
            // 텍스트 좌측 22.65% x 403 - 34px 패딩 - 체크 폭.
            SizedBox(width: 57.3 - 24.4 - FigmaCheckMark.figmaSize.width),
            Expanded(
              child: Text(
                label,
                style: kBodyStyle.copyWith(fontSize: 14, height: 1),
              ),
            ),
            const FigmaChevronRight(),
          ],
        ),
      ),
    );
  }
}
