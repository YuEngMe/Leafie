// 마이페이지 화면(2319:2). 시안 대조용 골든 하나와, 로그아웃 확인 모달이
// '아니오'에서 실제로 signOut을 막는지 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/my_page_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/figma_toggle_switch.dart';
import 'package:yeso_plant/widgets/mypage_cards.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';

void main() {
  testWidgets('마이페이지 402x874 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: MyPageScreen()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MyPageScreen),
      matchesGoldenFile('goldens/my_page_402.png'),
    );
  });

  testWidgets('시안 문구와 카드 두 장이 모두 뜬다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyPageScreen()));

    expect(find.text('마이페이지'), findsOneWidget);
    expect(find.byType(ProfileSummaryCard), findsOneWidget);
    expect(find.byType(ProfileMenuCard), findsOneWidget);
    expect(find.text('식집사가 된 지 128일째'), findsOneWidget);
    // 시안에 하단 네비게이션이 없다.
    expect(find.text('달력'), findsNothing);
  });

  testWidgets('앱 알림 토글은 꺼진 채로 시작해 누르면 켜진다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyPageScreen()));

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
  });

  testWidgets('로그아웃을 누르면 확인 모달이 시안 딤과 함께 뜬다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyPageScreen()));

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.byType(SignOutConfirmDialog), findsOneWidget);
    expect(find.text('로그아웃 하시겠습니까?'), findsOneWidget);

    final barrier = tester.widget<ModalBarrier>(
      find.byType(ModalBarrier).last,
    );
    expect(barrier.color, kModalBarrier);
  });

  testWidgets('모달에서 아니오를 고르면 로그아웃하지 않고 화면에 머문다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyPageScreen()));

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아니오'));
    await tester.pumpAndSettle();

    // Supabase를 초기화하지 않은 테스트라, 실제 signOut이 불렸다면
    // 여기서 예외가 터진다. 모달만 닫히고 화면이 남아야 한다.
    expect(find.byType(SignOutConfirmDialog), findsNothing);
    expect(find.byType(MyPageScreen), findsOneWidget);
  });
}
