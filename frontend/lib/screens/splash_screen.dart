import 'package:flutter/material.dart';
import 'package:yeso_plant/screens/login_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';

/// 앱 시작 스플래시(시안 4918:639). 흰 배경 중앙에 가로형 로고를 두고,
/// "Leafie" 글자를 왼→오른 계단식으로 드러낸 뒤 오른쪽 심볼이 통통 튀며
/// 마무리한다(Ding 스타일 A안). 애니가 끝나면 로그인 화면으로 넘어가고
/// 이후 세션 판단은 기존 onAuthStateChange가 맡는다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onDone});

  /// 애니메이션이 끝난 뒤 호출. 기본은 LoginScreen으로 교체.
  final VoidCallback? onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 시안 가로형 로고 폭(≈168 논리폭)과 글자·심볼 원본 크기(회색 제거 후).
  static const double _logoWidth = 168;
  static const double _wordAspect = 2025 / 514; // 글자 이미지 비율
  static const double _symbolAspect = 540 / 516; // 심볼 이미지 비율
  static const double _gap = 8; // 글자와 심볼 사이 간격(논리폭)

  // 전체 진행(0~1)에서 글자 페이드가 차지하는 구간. 나머지에서 심볼이 팝.
  static const double _wordSpan = 0.68;
  // 글자 계단식 단계.
  static const int _steps = 14;
  static const double _stepFade = 0.34;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 260), _goNext);
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

  /// 글자 계단식 알파: 글자 구간(0~_wordSpan) 안에서 왼→오른 순차, 유지형.
  double _letterAlpha(int step, double t) {
    final wt = (t / _wordSpan).clamp(0.0, 1.0); // 글자 구간 로컬 진행
    final startSpan = 1.0 - _stepFade;
    final start = _steps == 1 ? 0.0 : startSpan * (step / (_steps - 1));
    final local = ((wt - start) / _stepFade).clamp(0.0, 1.0);
    return Curves.easeOut.transform(local);
  }

  @override
  Widget build(BuildContext context) {
    // 글자·심볼 실제 렌더 폭을 로고 폭에 맞춰 배분한다.
    final wordW = _wordAspect * _logoHeight;
    final symW = _symbolAspect * _logoHeight;

    return Scaffold(
      backgroundColor: kBackgroundWhite,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            // 심볼 팝: 글자 구간이 끝난 뒤 진행(_wordSpan~1)에서 스케일 튐.
            final st = ((t - _wordSpan) / (1 - _wordSpan)).clamp(0.0, 1.0);
            final symScale = _popScale(st);
            final symOpacity = Curves.easeOut.transform(st.clamp(0.0, 1.0));

            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 글자 — 왼→오른 계단식 페이드.
                SizedBox(
                  width: wordW,
                  height: _logoHeight,
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) {
                      final stops = <double>[];
                      final colors = <Color>[];
                      for (int i = 0; i < _steps; i++) {
                        stops.add(i / (_steps - 1));
                        colors.add(
                          Colors.white.withValues(alpha: _letterAlpha(i, t)),
                        );
                      }
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: stops,
                        colors: colors,
                      ).createShader(rect);
                    },
                    child: Image.asset(
                      'assets/images/leafie_logo_word.png',
                      fit: BoxFit.contain,
                      semanticLabel: 'Leafie',
                    ),
                  ),
                ),
                const SizedBox(width: _gap),
                // 심볼 — 글자 뒤에 통통 팝.
                SizedBox(
                  width: symW,
                  height: _logoHeight,
                  child: Opacity(
                    opacity: symOpacity,
                    child: Transform.scale(
                      scale: symScale,
                      child: Image.asset(
                        'assets/images/leafie_logo_symbol.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 로고 높이(폭 168 기준 가로형 비율에서 역산). 글자 높이에 맞춘다.
  static const double _logoHeight = _logoWidth / (2692 / 516);

  /// 통통 팝: 작게 시작(0.4)해 살짝 오버슈트(≈1.12)했다가 제자리(1.0)로.
  /// easeOutBack이 1을 넘겼다 돌아오므로, 그 오버슈트를 스케일에 그대로 실어
  /// "통" 튀는 느낌을 남긴다.
  double _popScale(double s) {
    if (s <= 0) return 0.4;
    if (s >= 1) return 1.0;
    final eased = Curves.easeOutBack.transform(s); // 0→(≈1.1)→1
    return 0.4 + (1.0 - 0.4) * eased; // 시작 0.4, eased가 1 넘을 때 1을 넘어 팝
  }
}
