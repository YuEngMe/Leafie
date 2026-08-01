// 로그인 화면이 정상적으로 뜨는지 확인하는 기본 스모크 테스트.

import 'package:flutter_test/flutter_test.dart';

import 'package:yeso_plant/main.dart';

void main() {
  testWidgets('로그인 화면에 아이디·비밀번호·로그인 버튼이 보인다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const YesoApp());

    expect(find.text('아이디'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets); // 상단 제목 + 버튼, 2곳에 존재
  });
}
