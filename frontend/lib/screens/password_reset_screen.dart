import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/app_text_field.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

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
  const PasswordResetScreen({
    super.key,
    this.startAtSetNewPassword = false,
  });

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

  @override
  void dispose() {
    _cooldownTimer?.cancel();
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
      appBar: AppBar(title: const Text('비밀번호 초기화')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step == _Step.done) ...[
                const SizedBox(height: 60),
                const Text(
                  '비밀번호 설정이\n완료되었습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 200),
                PrimaryButton(
                  label: '로그인',
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ] else ...[
                // 딥링크로 바로 들어온 경우(startAtSetNewPassword)는 이메일을
                // 입력받은 적이 없으므로 이메일 관련 UI를 아예 보여주지 않는다.
                if (!widget.startAtSetNewPassword) ...[
                  Text(
                    '가입하신 이메일로 인증 링크를 보내드려요.\n링크를 눌러 새 비밀번호를 설정해주세요.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    label: '이메일',
                    controller: _emailController,
                    errorText: _emailFormatError,
                  ),
                  if (_step == _Step.linkSent ||
                      _step == _Step.setNewPassword) ...[
                    const SizedBox(height: 4),
                    Text(
                      _step == _Step.linkSent
                          ? '인증 메일이 발송 되었습니다. ($_formatRemaining)'
                          : '인증 완료',
                      style: TextStyle(
                        color: _step == _Step.linkSent
                            ? Colors.red
                            : kButtonGreen,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                if (_step == _Step.emailInput)
                  PrimaryButton(
                    label: _loading ? '발송 중...' : '인증 링크 발송',
                    onPressed: _loading ? () {} : _sendResetLink,
                  ),
                if (_step == _Step.linkSent)
                  PrimaryButton(
                    label: _remaining.inSeconds > 0
                        ? '재발송 ($_formatRemaining)'
                        : '재발송',
                    onPressed: _remaining.inSeconds > 0
                        ? () {}
                        : _sendResetLink,
                  ),
                if (_step == _Step.setNewPassword) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    label: '새 비밀번호',
                    obscureText: true,
                    controller: _newPasswordController,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: '비밀번호 확인',
                    obscureText: true,
                    controller: _newPasswordConfirmController,
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: _loading ? '설정 중...' : '완료',
                    onPressed: _loading ? () {} : _setNewPassword,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
