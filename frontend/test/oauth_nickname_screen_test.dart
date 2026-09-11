// 소셜 로그인 닉네임 설정 화면: 빈 값 검증과 provider 라벨 표시만 확인한다.
// updateUser는 실제 Supabase 호출이라 여기서는 검증하지 않는다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/oauth_nickname_screen.dart';

void main() {
  testWidgets('AppBar 타이틀에 provider 이름이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OAuthNicknameScreen(providerLabel: '카카오톡'),
      ),
    );

    expect(find.text('카카오톡 로그인'), findsOneWidget);
    expect(find.text('닉네임을 설정해주세요!'), findsOneWidget);
  });

  testWidgets('닉네임을 비운 채 회원가입을 누르면 안내만 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OAuthNicknameScreen(providerLabel: '네이버'),
      ),
    );

    await tester.tap(find.text('회원가입'));
    await tester.pump();

    expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);
  });
}
