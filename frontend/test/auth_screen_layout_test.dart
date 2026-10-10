// 인증 화면 좌표를 최신 시안(섹션 4534:22)에 고정한다. 2026-10 감사에서
// 로그인 폼이 15.5px 위, 가입 완료 로고가 옛 워드마크로 47px 아래, 타이머가
// 6px 위에 있던 것을 바로잡았다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/login_screen.dart';
import 'package:yeso_plant/screens/signup_complete_screen.dart';
import 'package:yeso_plant/screens/signup_screen.dart';
import 'package:yeso_plant/widgets/brand_logo.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/figma_glyphs.dart';
import 'package:yeso_plant/widgets/login_credentials_form.dart';
import 'package:yeso_plant/widgets/onboarding_fields.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

import 'support/device_view.dart';

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  useDeviceView(tester);
  await tester.pumpWidget(MaterialApp(home: screen));
  // 로고 높이는 이미지 비율로 정해지므로 디코딩을 기다린다.
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    await Future.wait([
      precacheImage(
        const AssetImage('assets/images/leafie_logo_symbol.png'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/images/leafie_logo_word.png'),
        context,
      ),
    ]);
  });
  await tester.pumpAndSettle();
}

void _expectRect(Rect actual, Rect expected, {double tolerance = 0.5}) {
  expect(actual.left, closeTo(expected.left, tolerance), reason: 'left');
  expect(actual.top, closeTo(expected.top, tolerance), reason: 'top');
  expect(actual.width, closeTo(expected.width, tolerance), reason: 'width');
  expect(actual.height, closeTo(expected.height, tolerance), reason: 'height');
}

void main() {
  testWidgets('로그인 로고·입력칸·버튼·소셜이 시안 4534:2499 자리에 앉는다', (tester) async {
    await _pumpScreen(tester, const LoginScreen());

    // 로고 4792:106 150,169 102x130.37.
    _expectRect(
      tester.getRect(find.byType(BrandLogo)),
      const Rect.fromLTWH(150, 169, 102, 130.37),
    );
    // 빈 이메일칸 4534:2520 34,382 334x49 · 비번칸 4534:2522 y445.
    _expectRect(
      tester.getRect(find.byType(LoginEmailField)),
      const Rect.fromLTWH(34, 382, 334, 49),
    );
    expect(
      tester.getTopLeft(find.byType(LoginPasswordField)).dy,
      closeTo(445, 0.5),
    );
    // 로그인 버튼 4534:2532 y558.
    _expectRect(
      tester.getRect(find.byType(PrimaryButton)),
      const Rect.fromLTWH(34, 558, 334, 51),
    );
    // 구분선 줄 4534:2579 y694. Divider는 16 높이 상자 가운데에 줄을 긋는다.
    expect(tester.getCenter(find.byType(Divider).first).dy, closeTo(694, 0.5));
    // 소셜 버튼 4534:2573 x121 · 4534:2539 x230.4, top 735.
    final socials = find.byType(FigmaSocialButton);
    expect(tester.getTopLeft(socials.at(0)).dx, closeTo(121, 0.5));
    expect(tester.getTopLeft(socials.at(1)).dx, closeTo(230.4, 0.5));
    expect(tester.getTopLeft(socials.at(0)).dy, closeTo(735, 0.5));
  });

  testWidgets('로그인 이메일칸에 값이 있으면 51 높이로 바뀌어도 비번칸은 445다', (tester) async {
    await _pumpScreen(tester, const LoginScreen());
    await tester.enterText(find.byType(TextField).first, 'a@b.co');
    await tester.pump();

    // 4534:1423 값 있는 칸 51 + 간격 12.
    _expectRect(
      tester.getRect(find.byType(LoginEmailField)),
      const Rect.fromLTWH(34, 382, 334, 51),
    );
    expect(
      tester.getTopLeft(find.byType(LoginPasswordField)).dy,
      closeTo(445, 0.5),
    );
  });

  testWidgets('회원가입 완료 로고와 문구가 시안 4534:2454 자리에 앉는다', (tester) async {
    await _pumpScreen(tester, const SignupCompleteScreen());

    // 로고 4889:386 150,236 102x130.37 — 로그인 로고와 같은 묶음.
    _expectRect(
      tester.getRect(find.byType(BrandLogo)),
      const Rect.fromLTWH(150, 236, 102, 130.37),
    );
    // 글자가 475(제목)·508(부제)에 찍히도록 Flutter 상자 위 여백만큼 올린 값.
    expect(
      tester.getTopLeft(find.text('회원가입이 완료되었습니다.')).dy,
      closeTo(474.5, 0.5),
    );
    expect(
      tester.getTopLeft(find.text('리피와 함께 나의 반려식물을 키워요!')).dy,
      closeTo(508.5, 0.5),
    );
  });

  testWidgets('회원가입 타이머가 이메일칸 세로 가운데(시안 4534:1765)에 찍힌다', (tester) async {
    useDeviceView(tester);
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    await tester.enterText(find.byType(TextField).first, 'a@b.co');
    await tester.pump();
    await tester.tap(find.text('발송'));
    await tester.pump();

    // 시안 글자 상자 252,188(높이 12). Flutter 상자는 14 높이라 위로 1
    // 넓고, 아래 여백 2로 글자를 시안 줄(190~197)에 맞췄다.
    final timer = tester.getRect(
      find.descendant(
        of: find.byType(VerificationCountdown),
        matching: find.byType(Text),
      ),
    );
    final field = tester.getRect(find.byType(SignupEmailField));
    expect(timer.right, closeTo(field.left + 261 - 13, 1));
    expect(timer.center.dy, closeTo(193.5, 1));
  });

  testWidgets('약관 시트 꺾쇠가 시안 4534:2189 자리에 그려진다', (tester) async {
    useDeviceView(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TermsAgreementSheet(),
          ),
        ),
      ),
    );

    // 꺾쇠 선은 상자 왼쪽에서 0.74 들어와 355.85에서 시작한다.
    final chevron = tester.getRect(find.byType(FigmaChevronRight).first);
    expect(chevron.left + 0.739621, closeTo(355.85, 0.5));
  });
}
