// 로그인 화면과 회원가입 이동을 확인하는 기본 스모크 테스트.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yeso_plant/main.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/login_screen.dart';
import 'package:yeso_plant/widgets/login_credentials_form.dart';
import 'package:yeso_plant/widgets/social_login_section.dart';

void main() {
  testWidgets('로그인 화면에 Figma 입력 안내와 로그인 버튼이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const YesoApp());

    expect(find.byType(LoginCredentialsForm), findsOneWidget);
    expect(find.byType(LoginEmailField), findsOneWidget);
    expect(find.byType(LoginPasswordField), findsOneWidget);
    expect(find.byType(SocialLoginSection), findsOneWidget);
    expect(find.text('이메일을 입력하세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력하세요.'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets); // 상단 제목 + 버튼

    final emailField = tester.widget<LoginEmailField>(
      find.byType(LoginEmailField),
    );
    expect(emailField.variant, LoginEmailFieldVariant.empty);

    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.pump();
    expect(
      tester.widget<LoginEmailField>(find.byType(LoginEmailField)).variant,
      LoginEmailFieldVariant.filled,
    );
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

    // 시안에서 라벨 글씨가 빠지고 색 원만 남아 시맨틱 라벨로 확인한다.
    expect(find.bySemanticsLabel('네이버 로그인'), findsOneWidget);
    expect(find.bySemanticsLabel('카카오 로그인'), findsOneWidget);
    expect(find.bySemanticsLabel('애플 로그인'), findsOneWidget);
  });

  testWidgets('로그인 완료 사용자를 식물 등록 화면에 가두지 않고 홈으로 보낸다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: authenticatedLandingScreen()));

    expect(find.text('좋은 하루야!'), findsOneWidget);
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

    await tester.tap(find.text('알림'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pump();

    expect(signOutRequested, isTrue);
  });

  testWidgets('애플 버튼은 아직 준비 중 안내만 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(const YesoApp());

    final appleButton = find.bySemanticsLabel('애플 로그인');
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

    final kakaoButton = find.bySemanticsLabel('카카오 로그인');
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

    final naverButton = find.bySemanticsLabel('네이버 로그인');
    await tester.ensureVisible(naverButton);
    await tester.pumpAndSettle();
    await tester.tap(naverButton);
    await tester.pump();

    expect(requestedProvider, const OAuthProvider('custom:naver'));
    expect(requestedRedirect, 'yesoplant://login-callback');
    expect(requestedScopes, 'openid profile');
  });
}
