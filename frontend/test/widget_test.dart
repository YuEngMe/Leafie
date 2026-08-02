// 로그인 화면과 회원가입 이동을 확인하는 기본 스모크 테스트.

import 'package:flutter_test/flutter_test.dart';

import 'package:yeso_plant/main.dart';

void main() {
  testWidgets('로그인 화면에 이메일·비밀번호·로그인 버튼이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const YesoApp());

    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets); // 상단 제목 + 버튼
  });

  testWidgets('회원가입을 누르면 회원가입 화면으로 이동한다', (WidgetTester tester) async {
    await tester.pumpWidget(const YesoApp());

    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();

    expect(find.text('비밀번호 확인'), findsOneWidget);
    expect(find.text('닉네임'), findsOneWidget);
  });
}
