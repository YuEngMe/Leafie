import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/login_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';

/// 앱 시작 스플래시(시안 4918:639). 흰 배경 중앙에 가로형 로고를 두고,
/// "Leafie"를 왼→오른 세로 구간으로 나눠 각 구간이 차례로 한 번씩 페이드인한다.
/// 한 번 뜬 구간은 계속 선명하게 남아, 지나가며 흐려지는 느낌 없이 스르륵
/// 드러난다. 애니가 끝나면 로그인 화면으로 넘어가고 이후 세션 판단은 기존
/// onAuthStateChange가 맡는다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onDone});

  /// 애니메이션이 끝난 뒤 호출. 기본은 LoginScreen으로 교체.
  final VoidCallback? onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 시안 로고 폭(가로형 로고 ≈ 168 논리폭).
  static const double _logoWidth = 168;
  // 왼→오른 페이드 단계 수. 각 단계는 자기 차례에 투명→불투명으로 한 번만
  // 오르고 유지된다. 많을수록 "스르륵"이 매끈하다.
  static const int _steps = 16;
  // 한 단계가 페이드되는 진행 비율. 단계 간 시작을 겹쳐 물결처럼 드러낸다.
  static const double _stepFade = 0.32;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    // 애니 후 아주 잠깐만 머문 뒤 다음 화면으로.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 220), _goNext);
      }
    });
  }

  void _goNext() {
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// x위치(0~1)의 불투명도. 왼쪽 단계부터 순서대로 오르고, 한 번 오르면
  /// 유지되어 다시 흐려지지 않는다.
  double _alphaAt(int step, double t) {
    final startSpan = 1.0 - _stepFade;
    final start = _steps == 1 ? 0.0 : startSpan * (step / (_steps - 1));
    final local = ((t - start) / _stepFade).clamp(0.0, 1.0);
    return Curves.easeOut.transform(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      body: Center(
        child: SizedBox(
          width: _logoWidth,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              // 각 단계 x위치의 알파를 계단식으로 만들어 dstIn 마스크로 씌운다.
              // 왼→오른으로 불투명 영역이 계단처럼 늘고, 지난 구간은 알파 1 유지.
              final stops = <double>[];
              final colors = <Color>[];
              for (int i = 0; i < _steps; i++) {
                stops.add(i / (_steps - 1));
                colors.add(Colors.white.withValues(alpha: _alphaAt(i, t)));
              }
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: stops,
                  colors: colors,
                ).createShader(rect),
                child: child,
              );
            },
            child: Image.asset(
              'assets/images/leafie_logo_horizontal.png',
              fit: BoxFit.contain,
              semanticLabel: 'Leafie',
            ),
          ),
        ),
      ),
    );
  }
}
