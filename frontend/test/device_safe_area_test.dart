// 골든은 상태바가 없는 조건에서 찍힌다. 그 값만 보고 하단 여백을 정하면
// 실기기에서 하단 SafeArea와 겹쳐 버튼이 뜬다(2026-09-05 실측으로 확인).
// 여기서는 실기기 조건을 흉내 내 하단 버튼이 시안 자리에 앉는지 본다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/change_password_screen.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/widgets/app_bottom_nav.dart';
import 'package:yeso_plant/screens/my_page_screen.dart';
import 'package:yeso_plant/screens/oauth_nickname_screen.dart';
import 'package:yeso_plant/screens/signup_complete_screen.dart';
import 'package:yeso_plant/screens/signup_screen.dart';
import 'package:yeso_plant/widgets/mypage_cards.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

/// iPhone 17 Pro 실측값. 시안은 상태바 46 기기로 그려져 상단은 16px
/// 내려앉는데, 이는 SafeArea가 제 일을 한 결과라 그대로 둔다.
const _deviceInsets = FakeViewPadding(top: 62, bottom: 34);

/// 시안(2319:23 등)의 하단 버튼 top.
const double _mockButtonTop = 790;

void main() {
  Future<void> expectButtonAtMock(
    WidgetTester tester,
    String label,
    Widget screen,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = _deviceInsets;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();

    final button = tester.getRect(find.byType(PrimaryButton).last);
    expect(button.top, closeTo(_mockButtonTop, 2), reason: label);
  }

  testWidgets('회원가입 하단 버튼이 시안 자리에 앉는다', (tester) async {
    await expectButtonAtMock(tester, '회원가입', const SignupScreen());
  });

  testWidgets('회원가입 완료 하단 버튼이 시안 자리에 앉는다', (tester) async {
    await expectButtonAtMock(tester, '회원가입 완료', const SignupCompleteScreen());
  });

  testWidgets('소셜 닉네임 하단 버튼이 시안 자리에 앉는다', (tester) async {
    await expectButtonAtMock(
      tester,
      '소셜 닉네임',
      const OAuthNicknameScreen(providerLabel: '카카오톡'),
    );
  });

  testWidgets('마이페이지 하단 버튼이 시안 자리에 앉는다', (tester) async {
    await expectButtonAtMock(tester, '마이페이지', const MyPageScreen());
  });

  testWidgets('비밀번호 변경 하단 버튼이 시안 자리에 앉는다', (tester) async {
    await expectButtonAtMock(
      tester,
      '비밀번호 변경',
      const ChangePasswordScreen(email: 'a@b.com'),
    );
  });

  testWidgets('상단은 상태바만큼 내려앉는다 — SafeArea를 존중한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = _deviceInsets;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: MyPageScreen()));
    await tester.pumpAndSettle();

    // 시안은 119지만 기기 상태바가 62라 16px 아래에서 시작한다. 이는
    // 의도된 동작이며, 시안 절대좌표에 억지로 맞추면 노치에 가린다.
    final card = tester.getRect(find.byType(ProfileSummaryCard));
    expect(card.top, closeTo(119 + (62 - 46), 2));
  });

  testWidgets('홈 네비바는 화면 바닥에 닿는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = _deviceInsets;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );
    await tester.pumpAndSettle();

    // SafeArea 안에 두면 홈 인디케이터(34px)만큼 떠서 빈 띠가 생긴다.
    final nav = tester.getRect(find.byType(AppBottomNav));
    expect(nav.top, closeTo(795, 2));
    expect(nav.bottom, closeTo(874, 2));
  });
}
