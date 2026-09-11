// 온보딩 입력 라벨은 시안(2307:933 등)에서 입력칸보다 11px 들여쓴 x45,
// 첫 라벨 top 145에 앉는다. 2026-09-07 감사에서 세 화면이 함께 어긋나
// 있었기에 한 곳에서 좌표를 고정한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/oauth_nickname_screen.dart';
import 'package:yeso_plant/screens/password_reset_screen.dart';
import 'package:yeso_plant/screens/signup_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';

void _setUpView(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.reset);
}

void _expectLabel(WidgetTester tester, String label, double top) {
  final rect = tester.getRect(find.text(label));
  expect(rect.left, closeTo(45, 1), reason: '$label x');
  expect(rect.top, closeTo(top, 1), reason: '$label y');
  expect(tester.widget<Text>(find.text(label)).style?.color, kOrangeMain);
}

void main() {
  testWidgets('회원가입 라벨 4개가 시안 자리에 앉는다', (tester) async {
    _setUpView(tester);
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    await tester.pumpAndSettle();
    _expectLabel(tester, '이메일', 145);
    _expectLabel(tester, '비밀번호', 255);
    _expectLabel(tester, '비밀번호 확인', 365);
    _expectLabel(tester, '닉네임', 475);
  });

  testWidgets('비밀번호 재설정 라벨 3개가 회원가입과 같은 자리에 앉는다', (tester) async {
    _setUpView(tester);
    await tester.pumpWidget(const MaterialApp(home: PasswordResetScreen()));
    await tester.pumpAndSettle();
    _expectLabel(tester, '이메일', 145);
    _expectLabel(tester, '새 비밀번호', 255);
    _expectLabel(tester, '비밀번호 확인', 365);
    // 2307:1518 발송 라벨 16 Medium.
    final send = tester.widget<Text>(find.text('발송')).style!;
    expect(send.fontSize, 16);
    expect(send.fontWeight, FontWeight.w500);
  });

  testWidgets('소셜 닉네임 문구와 라벨이 시안 자리에 앉는다', (tester) async {
    _setUpView(tester);
    await tester.pumpWidget(
      const MaterialApp(home: OAuthNicknameScreen(providerLabel: '카카오톡')),
    );
    await tester.pumpAndSettle();
    // 2307:751 / 2307:752 / 2307:744.
    expect(tester.getRect(find.text('닉네임을 설정해주세요!')).topLeft, const Offset(45, 140));
    expect(tester.getRect(find.text('당신을 뭐라고 부르면 좋을까요?')).topLeft, const Offset(45, 175));
    _expectLabel(tester, '닉네임', 237);
  });
}
