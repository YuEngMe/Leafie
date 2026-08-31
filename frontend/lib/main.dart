import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/login_screen.dart';
import 'package:yeso_plant/screens/password_reset_screen.dart';
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
        // password_reset_screen.dart를 새 비밀번호 입력 단계로 열어준다.
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                const PasswordResetScreen(startAtSetNewPassword: true),
          ),
        );
        break;
      case AuthChangeEvent.signedIn:
        // TODO: 카카오·네이버로 처음 가입한 사용자는 닉네임이 없어
        // oauth_nickname_screen.dart로 보내야 하는데, "신규 가입 vs
        // 재로그인"을 프론트가 구분할 방법이 아직 없다(GET /users/me에
        // profile_completed 같은 플래그가 없음, 2026-08-11 백엔드에 문의함).
        // 판단 기준이 정해지면 이 분기에서 신규 사용자만 닉네임 화면으로
        // 보내도록 갈라야 한다. 지금은 전부 홈으로 보낸다.
        _openAuthenticatedScreen(navigator);
        break;
      case AuthChangeEvent.initialSession:
        if (data.session != null) {
          _openAuthenticatedScreen(navigator);
        }
        break;
      case AuthChangeEvent.signedOut:
        _openLoginScreen(navigator);
        break;
      default:
        break;
    }
  }

  void _openAuthenticatedScreen(NavigatorState navigator) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => authenticatedLandingScreen()),
      (route) => false,
    );
  }

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
      home: const LoginScreen(),
    );
  }
}
