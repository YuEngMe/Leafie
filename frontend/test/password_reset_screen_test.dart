// 비밀번호 재설정 화면: 이메일 형식 검증과 발송 후 상태 전환만 확인한다.
// resetPasswordForEmail은 실제 Supabase 호출이라 여기서는 검증하지 않고,
// 그 앞뒤 UI 상태(에러 표시, 버튼 라벨 전환)만 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/password_reset_screen.dart';

void main() {
  testWidgets('이메일 형식이 틀리면 발송을 눌러도 에러만 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PasswordResetScreen()));

    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.pump();
    await tester.tap(find.text('발송'));
    await tester.pump();

    expect(find.text('이메일 형식이 올바르지 않습니다.'), findsOneWidget);
    // 형식 오류 상태에서는 여전히 이메일 입력 단계에 머문다.
    expect(find.text('시작하기'), findsOneWidget);
  });

  testWidgets('startAtSetNewPassword로 열면 이메일 UI 없이 바로 새 비밀번호 입력이 보인다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PasswordResetScreen(startAtSetNewPassword: true)),
    );

    // 딥링크로 바로 들어온 경우라 이메일을 물어본 적이 없어야 한다.
    expect(find.text('이메일'), findsNothing);
    expect(find.text('시작하기'), findsNothing);

    expect(find.text('새 비밀번호'), findsOneWidget);
    expect(find.text('비밀번호 확인'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
  });

  testWidgets('새 비밀번호 단계에서 8자 미만이면 막힌다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PasswordResetScreen(startAtSetNewPassword: true)),
    );

    await tester.enterText(find.byType(TextField).at(0), '1234567');
    await tester.tap(find.text('완료'));
    await tester.pump();

    expect(find.text('비밀번호는 최소 8자리 이상이어야 합니다.'), findsOneWidget);
  });
}
