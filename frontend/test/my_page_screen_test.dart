// 마이페이지 화면(2319:2). 시안 대조용 골든 하나와, 로그아웃 확인 모달이
// '아니오'에서 실제로 signOut을 막는지 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/my_page_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/figma_toggle_switch.dart';
import 'package:yeso_plant/widgets/mypage_cards.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';

/// 시안(2319:2)이 그린 값 그대로의 가짜 세션. 화면이 세션에서 값을 읽으므로
/// 좌표·문구 검증에는 고정된 사용자가 필요하다.
User _mockUser() => User(
  id: 'test-user',
  appMetadata: const {},
  userMetadata: const {'leafie_nickname': '김윤지'},
  aud: 'authenticated',
  email: 'akdrotorl@naver.com',
  createdAt: DateTime.now()
      .subtract(const Duration(days: 128))
      .toIso8601String(),
);

void main() {
  testWidgets('마이페이지 402x874 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: MyPageScreen(user: _mockUser())));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MyPageScreen),
      matchesGoldenFile('goldens/my_page_402.png'),
    );
  });

  testWidgets('시안 문구와 카드 두 장이 모두 뜬다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MyPageScreen(user: _mockUser())));

    expect(find.text('마이페이지'), findsOneWidget);
    expect(find.byType(ProfileSummaryCard), findsOneWidget);
    expect(find.byType(ProfileMenuCard), findsOneWidget);
    expect(find.text('식집사가 된 지 128일째'), findsOneWidget);
    // 시안에 하단 네비게이션이 없다.
    expect(find.text('달력'), findsNothing);
  });

  testWidgets('앱 알림 토글은 꺼진 채로 시작해 누르면 켜진다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MyPageScreen(user: _mockUser())));

    // 2319:2가 꺼짐, 2353:577이 켜짐 상태다.
    expect(
      tester.widget<FigmaToggleSwitch>(find.byType(FigmaToggleSwitch)).value,
      isFalse,
    );

    await tester.tap(find.byType(FigmaToggleSwitch));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FigmaToggleSwitch>(find.byType(FigmaToggleSwitch)).value,
      isTrue,
    );
    // 3562:196 — 켤 때 토스트가 잠깐 떴다가 사라진다.
    expect(find.text('알림이 설정되었어요!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('알림이 설정되었어요!'), findsNothing);
  });

  testWidgets('로그아웃을 누르면 확인 모달이 시안 딤과 함께 뜬다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MyPageScreen(user: _mockUser())));

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.byType(SignOutConfirmDialog), findsOneWidget);
    expect(find.text('로그아웃 하시겠습니까?'), findsOneWidget);

    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, kModalBarrier);
  });

  testWidgets('모달에서 아니오를 고르면 로그아웃하지 않고 화면에 머문다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MyPageScreen(user: _mockUser())));

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아니오'));
    await tester.pumpAndSettle();

    // Supabase를 초기화하지 않은 테스트라, 실제 signOut이 불렸다면
    // 여기서 예외가 터진다. 모달만 닫히고 화면이 남아야 한다.
    expect(find.byType(SignOutConfirmDialog), findsNothing);
    expect(find.byType(MyPageScreen), findsOneWidget);
  });

  testWidgets('시안 2319:2의 좌표를 전부 지킨다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: MyPageScreen(user: _mockUser())));
    await tester.pumpAndSettle();

    // 골든에는 상태바가 없어 시안 y에서 46을 뺀다.
    const statusBar = 46.0;
    void expectAt(String label, Finder finder, double x, double y) {
      final rect = tester.getRect(finder.first);
      expect(rect.left, closeTo(x, 1), reason: '$label x');
      expect(rect.top + statusBar, closeTo(y, 1), reason: '$label y');
    }

    expectAt('프로필 카드', find.byType(ProfileSummaryCard), 29, 119);
    expectAt('닉네임', find.text('김윤지님'), 52, 133.24);
    expectAt('가입 기간', find.text('식집사가 된 지 128일째'), 131, 142);
    expectAt('이메일', find.text('akdrotorl@naver.com'), 52, 166.1);
    expectAt('메뉴 카드', find.byType(ProfileMenuCard), 29, 211);
    expectAt('프로필 관리', find.text('프로필 관리'), 52, 227);
    expectAt('내 정보 수정', find.text('내 정보 수정'), 52, 264.76);
    expectAt('비밀번호 변경', find.text('비밀번호 변경'), 52, 313.76);
    expectAt('회원 탈퇴', find.text('회원 탈퇴'), 52, 362.76);
    expectAt('앱 알림', find.text('앱 알림'), 52, 411.76);

    // 카드는 폭 344인데 버튼만 334다(2319:23). 세로 위치는 하단 SafeArea가
    // 정하므로 여기(상태바 없는 조건)서는 보지 않는다 —
    // device_safe_area_test.dart가 실기기 조건에서 확인한다.
    final button = tester.getRect(find.byType(PrimaryButton));
    expect(button.left, closeTo(34, 1));
    expect(button.width, closeTo(334, 1));

    // Switch가 48px 터치 영역을 차지해 rect는 시안보다 크다. 트랙이
    // 앉는 자리는 중심으로 본다.
    final toggle = tester.getRect(find.byType(FigmaToggleSwitch));
    expect(toggle.center.dy + statusBar, closeTo(409.76 + 24.923 / 2, 1));
  });

  testWidgets('프로필은 하드코딩이 아니라 세션에서 읽는다', (tester) async {
    final user = User(
      id: 'other-user',
      appMetadata: const {},
      userMetadata: const {'leafie_nickname': '박승현'},
      aud: 'authenticated',
      email: 'seunghyun@example.com',
      createdAt: DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String(),
    );

    await tester.pumpWidget(MaterialApp(home: MyPageScreen(user: user)));

    expect(find.text('박승현님'), findsOneWidget);
    expect(find.text('seunghyun@example.com'), findsOneWidget);
    expect(find.text('식집사가 된 지 7일째'), findsOneWidget);

    // 시안이 그린 더미가 남아 있으면 안 된다.
    expect(find.text('김윤지님'), findsNothing);
    expect(find.text('akdrotorl@naver.com'), findsNothing);
  });

  testWidgets('닉네임이 비어 있어도 화면은 뜬다', (tester) async {
    final user = User(
      id: 'no-nickname',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: 'plain@example.com',
      createdAt: DateTime.now().toIso8601String(),
    );

    await tester.pumpWidget(MaterialApp(home: MyPageScreen(user: user)));

    expect(find.text('식집사님'), findsOneWidget);
    expect(find.text('plain@example.com'), findsOneWidget);
  });
}
