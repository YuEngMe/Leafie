import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/signup_complete_screen.dart';

void main() {
  testWidgets('회원가입 완료 화면에 안내 문구와 시작하기 버튼이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignupCompleteScreen()),
    );

    expect(find.text('회원가입이 완료되었습니다.'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });
}
