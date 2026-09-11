// 로그인 화면과 회원가입 이동을 확인하는 기본 스모크 테스트.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yeso_plant/main.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/login_screen.dart';

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

  testWidgets('로그인 화면에 네이버·카카오·애플 간편로그인 버튼이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const YesoApp());

    expect(find.text('네이버'), findsOneWidget);
    expect(find.text('카카오'), findsOneWidget);
    expect(find.text('애플'), findsOneWidget);
  });

  testWidgets('로그인 완료 사용자를 식물 등록 화면에 가두지 않고 홈으로 보낸다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: authenticatedLandingScreen()));

    expect(find.text('내 식물이 기다리고 있어요'), findsOneWidget);
    expect(find.text('내 식물 등록하기'), findsNothing);
  });

  testWidgets('홈의 로그아웃 버튼은 세션 종료를 요청한다', (WidgetTester tester) async {
    var signOutRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          signOut: () async {
            signOutRequested = true;
          },
        ),
      ),
    );

    final logoutButton = find.widgetWithText(TextButton, '로그아웃');
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(tester.getSize(logoutButton).height, greaterThanOrEqualTo(48));

    await tester.tap(logoutButton);
    await tester.pump();

    expect(signOutRequested, isTrue);
  });

  testWidgets('애플 버튼은 아직 준비 중 안내만 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(const YesoApp());

    final appleButton = find.text('애플');
    await tester.ensureVisible(appleButton);
    await tester.pumpAndSettle();
    await tester.tap(appleButton);
    await tester.pump();
    expect(find.text('애플 로그인은 준비 중이에요'), findsOneWidget);
  });

  testWidgets('카카오 버튼은 Supabase 표준 Kakao 제공자를 요청한다', (
    WidgetTester tester,
  ) async {
    OAuthProvider? requestedProvider;
    String? requestedRedirect;
    String? requestedScopes;
    LaunchMode? requestedLaunchMode;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          oauthSignIn:
              (
                provider, {
                redirectTo,
                scopes,
                authScreenLaunchMode = LaunchMode.platformDefault,
              }) async {
                requestedProvider = provider;
                requestedRedirect = redirectTo;
                requestedScopes = scopes;
                requestedLaunchMode = authScreenLaunchMode;
                return true;
              },
        ),
      ),
    );

    final kakaoButton = find.text('카카오');
    await tester.ensureVisible(kakaoButton);
    await tester.pumpAndSettle();
    await tester.tap(kakaoButton);
    await tester.pump();

    expect(requestedProvider, OAuthProvider.kakao);
    expect(requestedRedirect, 'yesoplant://login-callback');
    expect(requestedScopes, isNull);
    expect(requestedLaunchMode, LaunchMode.externalApplication);
  });

  testWidgets('네이버 버튼은 지원되는 OIDC 권한만 요청한다', (WidgetTester tester) async {
    OAuthProvider? requestedProvider;
    String? requestedRedirect;
    String? requestedScopes;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          oauthSignIn:
              (
                provider, {
                redirectTo,
                scopes,
                authScreenLaunchMode = LaunchMode.platformDefault,
              }) async {
                requestedProvider = provider;
                requestedRedirect = redirectTo;
                requestedScopes = scopes;
                return true;
              },
        ),
      ),
    );

    final naverButton = find.text('네이버');
    await tester.ensureVisible(naverButton);
    await tester.pumpAndSettle();
    await tester.tap(naverButton);
    await tester.pump();

    expect(requestedProvider, const OAuthProvider('custom:naver'));
    expect(requestedRedirect, 'yesoplant://login-callback');
    expect(requestedScopes, 'openid profile');
  });
}
