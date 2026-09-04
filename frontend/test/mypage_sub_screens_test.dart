// 마이페이지 하위 화면: 내 정보 수정(2316:6397)과 회원 탈퇴(2570:1994).
// 좌표와 함께, 값 없이는 버튼이 열리지 않는 규칙을 잠근다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/change_password_screen.dart';
import 'package:yeso_plant/screens/edit_profile_screen.dart';
import 'package:yeso_plant/screens/withdraw_screen.dart';
import 'package:yeso_plant/widgets/figma_glyphs.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

/// 골든에는 상태바가 없어 시안 y에서 46을 뺀다.
const double _statusBar = 46;

void _expectAt(
  WidgetTester tester,
  String label,
  Finder f,
  double x,
  double y,
) {
  final rect = tester.getRect(f.first);
  expect(rect.left, closeTo(x, 1), reason: '$label x');
  expect(rect.top + _statusBar, closeTo(y, 1), reason: '$label y');
}

/// Supabase 없이 인증 단계만 돌려 보는 가짜. 어떤 코드든 '123456'이면
/// 통과한다.
class _FakeAuth implements ChangePasswordAuth {
  final List<String> sent = [];
  String? updatedPassword;

  @override
  Future<void> sendCode(String email) async => sent.add(email);

  @override
  Future<void> verifyCode(String email, String token) async {
    if (token != '123456') {
      throw const AuthException('인증코드가 올바르지 않습니다.');
    }
  }

  @override
  Future<void> updatePassword(String password) async =>
      updatedPassword = password;
}

void main() {
  group('내 정보 수정', () {
    testWidgets('시안 2316:6397 좌표를 지킨다', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
      await tester.pumpAndSettle();

      // 시안은 마이페이지 쪽 화면에서만 라벨을 입력칸보다 11px 들여쓴다.
      _expectAt(tester, '라벨', find.text('닉네임'), 45, 145);
      // RoundedInputField는 라벨까지 감싸 rect가 145에서 시작한다.
      // 알약 자체는 그 안의 Container다.
      _expectAt(
        tester,
        '입력칸',
        find.descendant(
          of: find.byType(RoundedInputField),
          matching: find.byType(Container),
        ),
        34,
        169,
      );
      _expectAt(tester, '버튼', find.byType(PrimaryButton), 34, 244);
    });

    testWidgets('빈 칸에서도 버튼은 오렌지이고, 눌러도 넘어가지 않는다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));

      // 시안 2316:6397은 기존 값을 채우지 않고 힌트만 보여준다.
      expect(find.text('닉네임을 입력하세요.'), findsOneWidget);

      // 회원가입과 달리 비활성 시안이 없다(2316:6397, 2353:376 모두 오렌지).
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).variant,
        PrimaryButtonVariant.enabled,
      );

      await tester.tap(find.text('변경하기'));
      await tester.pump();

      expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
    });

    testWidgets('변경하기를 누르면 새 닉네임을 돌려준다', (tester) async {
      String? returned;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  returned = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '다다다');
      await tester.pump();
      await tester.tap(find.text('변경하기'));
      await tester.pumpAndSettle();

      expect(returned, '다다다');
    });
  });

  group('회원 탈퇴', () {
    testWidgets('시안 2570:1994 좌표를 지킨다', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: WithdrawScreen()));
      await tester.pumpAndSettle();

      _expectAt(tester, '헤드라인', find.text('리피 탈퇴 전 확인하세요'), 45, 140);
      _expectAt(tester, '부제', find.text('정말 탈퇴하시나요? 너무 아쉬워요..'), 45, 175);
      _expectAt(
        tester,
        '안내 첫 줄',
        find.text(WithdrawScreen.notices[0]),
        66,
        255,
      );
      _expectAt(tester, '체크박스', find.byType(FigmaConsentCheckbox), 45, 357);
      _expectAt(tester, '버튼', find.byType(PrimaryButton), 34, 466);
    });

    testWidgets('안내 세 줄이 모두 뜬다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WithdrawScreen()));

      for (final notice in WithdrawScreen.notices) {
        expect(find.text(notice), findsOneWidget);
      }
    });

    testWidgets('동의하기 전에는 탈퇴 버튼이 잠겨 있다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WithdrawScreen()));

      PrimaryButtonVariant variant() =>
          tester.widget<PrimaryButton>(find.byType(PrimaryButton)).variant;

      expect(variant(), PrimaryButtonVariant.disabled);
      expect(
        tester
            .widget<FigmaConsentCheckbox>(find.byType(FigmaConsentCheckbox))
            .checked,
        isFalse,
      );

      await tester.tap(find.byType(FigmaConsentCheckbox));
      await tester.pumpAndSettle();

      expect(variant(), PrimaryButtonVariant.enabled);
    });

    testWidgets('동의 줄은 글자를 눌러도 체크된다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WithdrawScreen()));

      await tester.tap(find.text('안내 사항을 모두 확인하였으며, 이에 동의합니다.'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FigmaConsentCheckbox>(find.byType(FigmaConsentCheckbox))
            .checked,
        isTrue,
      );
    });
  });

  group('비밀번호 변경', () {
    testWidgets('시안 2346:2722 좌표를 지킨다', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangePasswordScreen(email: 'a@b.com', auth: _FakeAuth()),
        ),
      );
      await tester.pumpAndSettle();

      _expectAt(tester, '이메일 라벨', find.text('이메일'), 45, 145);
      _expectAt(tester, '새 비밀번호 라벨', find.text('새 비밀번호'), 45, 255);
      _expectAt(tester, '비밀번호 확인 라벨', find.text('비밀번호 확인'), 45, 365);
      // 변경하기의 세로 위치는 하단 SafeArea가 정한다. 실기기 조건은
      // device_safe_area_test.dart에서 본다. 여기서는 좌우만 확인한다.
      final submit = tester.getRect(
        find.ancestor(
          of: find.text('변경하기'),
          matching: find.byType(PrimaryButton),
        ),
      );
      expect(submit.left, closeTo(34, 1));
      expect(submit.width, closeTo(334, 1));
    });

    testWidgets('메일을 보내야 인증코드 칸이 열린다', (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangePasswordScreen(email: 'a@b.com', auth: auth),
        ),
      );

      // 세션 이메일이 미리 채워져 바로 보낼 수 있다.
      expect(find.text('a@b.com'), findsOneWidget);
      expect(find.text('인증코드'), findsNothing);

      await tester.tap(find.text('발송'));
      await tester.pumpAndSettle();

      expect(auth.sent, ['a@b.com']);
      expect(find.text('재발송'), findsOneWidget);
      expect(find.text('인증코드'), findsOneWidget);
    });

    testWidgets('틀린 인증코드는 오류를 띄우고 통과시키지 않는다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangePasswordScreen(email: 'a@b.com', auth: _FakeAuth()),
        ),
      );

      await tester.tap(find.text('발송'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '000000');
      await tester.pump();
      await tester.tap(find.text('재발송'));
      await tester.pumpAndSettle();

      expect(find.text('인증코드가 올바르지 않습니다.'), findsOneWidget);
      expect(find.text('완료'), findsNothing);
    });

    testWidgets('인증을 마쳐야 변경하기가 열리고 실제로 비밀번호를 바꾼다', (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangePasswordScreen(email: 'a@b.com', auth: auth),
        ),
      );

      PrimaryButtonVariant submitVariant() => tester
          .widget<PrimaryButton>(
            find.ancestor(
              of: find.text('변경하기'),
              matching: find.byType(PrimaryButton),
            ),
          )
          .variant;

      // 인증 전에는 비밀번호를 채워도 잠겨 있다.
      await tester.tap(find.text('발송'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), 'newpass1!');
      await tester.enterText(find.byType(TextField).at(3), 'newpass1!');
      await tester.pump();
      expect(submitVariant(), PrimaryButtonVariant.disabled);

      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.pump();
      await tester.tap(find.text('재발송'));
      await tester.pumpAndSettle();

      expect(find.text('완료'), findsOneWidget);
      expect(submitVariant(), PrimaryButtonVariant.enabled);

      await tester.tap(find.text('변경하기'));
      await tester.pumpAndSettle();

      expect(auth.updatedPassword, 'newpass1!');
    });

    testWidgets('두 비밀번호가 다르면 바꾸지 않는다', (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangePasswordScreen(email: 'a@b.com', auth: auth),
        ),
      );

      await tester.tap(find.text('발송'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.pump();
      await tester.tap(find.text('재발송'));
      await tester.pumpAndSettle();

      // 인증이 끝나면 인증코드 칸이 사라져 인덱스가 밀린다. 라벨로 찾는다.
      Finder fieldUnder(String label) => find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(RoundedInputField),
        ),
        matching: find.byType(TextField),
      );

      await tester.enterText(fieldUnder('새 비밀번호'), 'newpass1!');
      await tester.enterText(fieldUnder('비밀번호 확인'), 'other2!');
      await tester.pump();
      await tester.tap(find.text('변경하기'));
      await tester.pump();

      expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
      expect(auth.updatedPassword, isNull);
    });
  });
}
