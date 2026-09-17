import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/change_password_screen.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/login_screen.dart';
import 'package:yeso_plant/screens/splash_screen.dart';
import 'package:yeso_plant/screens/oauth_nickname_screen.dart';
import 'package:yeso_plant/screens/password_reset_screen.dart';
import 'package:yeso_plant/services/user_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

// OAuth·이메일 인증·비밀번호 재설정 링크가 모두 이 스킴으로 앱에 돌아온다.
// android/ios에 등록해둔 값과 반드시 일치해야 한다.
const oauthRedirectUrl = 'yesoplant://login-callback';

@visibleForTesting
Widget authenticatedLandingScreen() => const HomeScreen();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );
  runApp(const YesoApp());
}

class YesoApp extends StatefulWidget {
  const YesoApp({super.key});

  @override
  State<YesoApp> createState() => _YesoAppState();
}

class _YesoAppState extends State<YesoApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;

  // 스플래시 애니가 끝날 때까지 auth 화면 전환을 보류한다. 완료 전에 세션
  // 이벤트가 오면 목적지만 저장해 뒀다가, 스플래시가 끝나면 실행한다.
  bool _splashDone = false;
  VoidCallback? _pendingNavigation;

  void _runOrDefer(VoidCallback navigate) {
    if (_splashDone) {
      navigate();
    } else {
      _pendingNavigation = navigate;
    }
  }

  void _onSplashDone() {
    _splashDone = true;
    final pending = _pendingNavigation;
    _pendingNavigation = null;
    final navigator = _navigatorKey.currentState;
    if (pending != null) {
      pending();
    } else if (navigator != null) {
      // 대기 중인 세션 전환이 없으면(로그아웃 상태) 로그인 화면으로.
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // 위젯 테스트는 main()의 Supabase.initialize()를 거치지 않고 YesoApp만
    // 그린다. Supabase.instance는 미초기화 시 AssertionError를 던지는 게
    // 이 패키지의 유일한 초기화 확인 수단이라, 여기서 잡아 테스트 환경에서
    // 크래시하지 않게 한다.
    late final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      return;
    }

    // Supabase.initialize()가 yesoplant://login-callback 딥링크를 자동으로
    // 파싱해 세션을 만든다. 앱은 그 결과(AuthChangeEvent)만 듣고 화면을 바꾼다.
    _authSubscription = client.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: (Object error) {
        // OAUTH_CALLBACK_FAILED: 콜백 URL 교환 자체가 실패한 경우.
        // api-spec.md 3장의 OAuth 오류 상태 중 하나 — 로그인 화면에 남아
        // 다시 시도하게 한다.
        _showSnackBar('로그인 처리 중 오류가 발생했어요. 다시 시도해주세요.');
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthStateChange(AuthState data) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    switch (data.event) {
      case AuthChangeEvent.passwordRecovery:
        // 비밀번호 재설정 이메일의 링크를 눌러 돌아온 경우.
        // 마이페이지 쪽 화면(ChangePasswordScreen)이 이미 열려 있으면 그
        // 화면이 스스로 이 이벤트를 받아 '완료'로 넘어간다. 여기서 또
        // 띄우면 같은 일을 하는 화면이 두 장 겹친다.
        if (!ChangePasswordAuth.isOpen) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) =>
                  const PasswordResetScreen(startAtSetNewPassword: true),
            ),
          );
        }
        break;
      case AuthChangeEvent.signedIn:
        // 서버 프로필의 profile_completed로 신규 소셜 가입자를 가른다.
        _runOrDefer(() => _openAuthenticatedScreen(navigator, data.session?.user));
        break;
      case AuthChangeEvent.initialSession:
        if (data.session != null) {
          _runOrDefer(
            () => _openAuthenticatedScreen(navigator, data.session?.user),
          );
        }
        break;
      case AuthChangeEvent.signedOut:
        _runOrDefer(() => _openLoginScreen(navigator));
        break;
      default:
        break;
    }
  }

  Future<void> _openAuthenticatedScreen(
    NavigatorState navigator,
    User? user,
  ) async {
    try {
      final profile = await UserApi().getProfile();
      if (!profile.profileCompleted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                OAuthNicknameScreen(providerLabel: _providerLabel(user)),
          ),
          (route) => false,
        );
        return;
      }
    } catch (_) {
      // 프로필 확인 실패가 로그인 성공 자체를 막지는 않는다. 홈에서 재시도한다.
    }
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => authenticatedLandingScreen()),
      (route) => false,
    );
  }

  String _providerLabel(User? user) =>
      switch (user?.appMetadata['provider']?.toString().toLowerCase()) {
        'kakao' => '카카오톡',
        'naver' => '네이버',
        'apple' => 'Apple',
        _ => '소셜',
      };

  void _openLoginScreen(NavigatorState navigator) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSnackBar(String message) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      title: '리피 - 내 식물 친구',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kOrangeMain,
          surface: kBackgroundWhite,
        ),
        scaffoldBackgroundColor: kBackgroundWhite,
        fontFamily: kFontFamily,
      ),
      home: SplashScreen(onDone: _onSplashDone),
    );
  }
}
