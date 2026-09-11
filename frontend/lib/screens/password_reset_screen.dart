import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/onboarding_fields.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

final _emailFormatRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
const _resendCooldown = Duration(minutes: 3, seconds: 21); // Figma 시안의 03:21

// Figma "04 앱 진입_비밀번호 재설정"(2026-08-05 확인) 기준 4단계를
// 화면 하나의 상태 전환으로 구현. 딥링크로 앱에 돌아온 뒤 새 비밀번호를
// 저장하는 부분은 updateUser(password)로 처리.
//
// _Step.linkSent → _Step.setNewPassword 전환은 main.dart의
// onAuthStateChange 리스너가 AuthChangeEvent.passwordRecovery를 받으면
// startAtSetNewPassword: true로 이 화면을 새로 열어서 처리한다(2026-08-09).
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, this.startAtSetNewPassword = false});

  // 이메일 인증 링크를 눌러 딥링크로 돌아온 경우 true — 이메일 입력 단계를
  // 건너뛰고 바로 새 비밀번호 입력 단계로 시작한다.
  final bool startAtSetNewPassword;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

enum _Step { emailInput, linkSent, setNewPassword, done }

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _newPasswordConfirmController = TextEditingController();

  late _Step _step = widget.startAtSetNewPassword
      ? _Step.setNewPassword
      : _Step.emailInput;
  String? _emailFormatError;
  bool _loading = false;
  Timer? _cooldownTimer;
  Duration _remaining = _resendCooldown;

  bool get _emailNotEmpty => _emailController.text.trim().isNotEmpty;

  /// 2395:52/49/51은 같은 버튼의 라벨로 단계를 알린다.
  String get _sendButtonLabel => switch (_step) {
    _Step.emailInput => '발송',
    _Step.linkSent => '재발송',
    _Step.setNewPassword => '완료',
    _Step.done => '완료',
  };

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_refreshEmailAction);
  }

  void _refreshEmailAction() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.removeListener(_refreshEmailAction);
    _emailController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _remaining = _resendCooldown;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (!_emailFormatRegex.hasMatch(email)) {
      setState(() => _emailFormatError = '이메일 형식이 올바르지 않습니다.');
      return;
    }
    setState(() {
      _emailFormatError = null;
      _loading = true;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        setState(() => _step = _Step.linkSent);
        _startCooldown();
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

  Future<void> _setNewPassword() async {
    if (_newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호는 최소 8자리 이상이어야 합니다.')));
      return;
    }
    if (_newPasswordController.text != _newPasswordConfirmController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );
      if (mounted) setState(() => _step = _Step.done);
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

  String _formatRemaining() {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '비밀번호 재설정'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            // 2395:52 첫 라벨 top 145 — 회원가입과 같은 자리.
            padding: const EdgeInsets.fromLTRB(
              AppLayout.authHorizontalPadding,
              AppLayout.authFormTopPadding,
              AppLayout.authHorizontalPadding,
              AppLayout.authBottomActionPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    constraints.maxHeight -
                    AppLayout.authFormTopPadding -
                    AppLayout.authBottomActionPadding,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_step == _Step.done) ...[
                      const Spacer(),
                      // Figma node 2427:9031. 부모 Column이 start 정렬이라
                      // 폭을 채워야 textAlign.center가 실제로 먹는다.
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          '비밀번호 설정이\n완료되었습니다',
                          textAlign: TextAlign.center,
                          // 텍스트 블록 50px에 21px 두 줄 -> 행간 25/21.
                          style: kTitleStyle.copyWith(height: 25 / 21),
                        ),
                      ),
                      const Spacer(),
                      PrimaryButton(
                        label: '로그인',
                        variant: PrimaryButtonVariant.enabled,
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                      ),
                    ] else ...[
                      if (!widget.startAtSetNewPassword) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: RoundedInputField(
                                label: '이메일',
                                hintText: '이메일을 입력하세요.',
                                controller: _emailController,
                                enabled: _step == _Step.emailInput,
                                // 2307:1495 라벨+칸 75 — 회원가입 칸과 같다.
                                height: AppLayout.onboardingControlHeight,
                                labelGap: 1,
                                centerVertically: true,
                                errorText: _emailFormatError,
                                // 2395:49는 남은 시간을 입력칸 안 우측에 얹는다.
                                overlaySuffix: _step == _Step.linkSent,
                                suffix: _step == _Step.linkSent
                                    ? Text(
                                        _formatRemaining(),
                                        style: const TextStyle(
                                          fontFamily: kFontFamily,
                                          fontSize: 10,
                                          color: kErrorRed,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: AppLayout.authEmailActionGap),
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              // 2307:1517 68×51, 라벨 16 Medium — 회원가입 버튼.
                              child: SignupSendButton(
                                label: _loading ? '발송 중' : _sendButtonLabel,
                                variant:
                                    _loading ||
                                        !_emailNotEmpty ||
                                        _emailFormatError != null ||
                                        (_step == _Step.linkSent &&
                                            _remaining.inSeconds > 0)
                                    ? SignupSendButtonVariant.disabled
                                    : SignupSendButtonVariant.enabled,
                                onPressed:
                                    _loading ||
                                        !_emailNotEmpty ||
                                        _emailFormatError != null ||
                                        (_step == _Step.linkSent &&
                                            _remaining.inSeconds > 0)
                                    ? null
                                    : _sendResetLink,
                              ),
                            ),
                          ],
                        ),
                        // 2395:51은 인증 완료를 버튼 라벨('완료')로만 알린다.
                        // 2307:1662 x45 y225 — 칸 바닥(220)+5, 라벨처럼 들여쓴다.
                        if (_step == _Step.linkSent)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 5,
                              left: AppLayout.inputLabelIndent,
                            ),
                            child: Text(
                              '인증메일이 발송 되었습니다.',
                              style: kCaptionStyle.copyWith(
                                color: kErrorRed,
                                height: 1,
                              ),
                            ),
                          ),
                        const SizedBox(height: AppLayout.authFieldGap),
                      ],
                      RoundedInputField(
                        label: '새 비밀번호',
                        hintText: '비밀번호를 입력하세요.',
                        obscureText: true,
                        height: AppLayout.onboardingControlHeight,
                        labelGap: 1,
                        centerVertically: true,
                        controller: _newPasswordController,
                        enabled: _step == _Step.setNewPassword,
                      ),
                      const SizedBox(height: AppLayout.authFieldGap),
                      RoundedInputField(
                        label: '비밀번호 확인',
                        hintText: '비밀번호를 입력하세요.',
                        obscureText: true,
                        height: AppLayout.onboardingControlHeight,
                        labelGap: 1,
                        centerVertically: true,
                        controller: _newPasswordConfirmController,
                        enabled: _step == _Step.setNewPassword,
                      ),
                      const Spacer(),
                      PrimaryButton(
                        label: _step == _Step.setNewPassword
                            ? (_loading ? '설정 중...' : '완료')
                            : (_loading ? '발송 중...' : '시작하기'),
                        variant: _loading || _step != _Step.setNewPassword
                            ? PrimaryButtonVariant.disabled
                            : PrimaryButtonVariant.enabled,
                        onPressed: _loading || _step != _Step.setNewPassword
                            ? null
                            : _setNewPassword,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
