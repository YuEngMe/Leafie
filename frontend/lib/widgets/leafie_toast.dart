import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

/// Figma 3564:243(알림 설정), 2353:408(닉네임 변경)의 회색 알약 토스트.
///
/// 334×36, radius 50, `#A1A1A1`, 그림자 흐림 4 검정 18%(4534:3094), 12px 흰 글씨
/// 중앙. 알림 쪽만 왼쪽 17px에 종 아이콘(13.816×16)이 붙는다.
///
/// 시안은 한 줄 문구만 있다. 서버 오류처럼 길이를 모르는 문구가 한 줄을 넘으면
/// 잘리지 않게 높이를 늘려 여러 줄로 보인다(한 줄이면 시안 그대로 36).
class LeafieToast extends StatelessWidget {
  const LeafieToast({super.key, required this.text, this.bell = false});

  final String text;
  final bool bell;

  static const double width = 334;
  static const double height = 36;

  /// 여러 줄일 때 글자 좌우 여백. 알약 둥근 끝에 글자가 닿지 않게 한다.
  static const double _sidePadding = 24;

  @override
  Widget build(BuildContext context) {
    final toastWidth = math.min(width, MediaQuery.sizeOf(context).width - 32);
    final oneLine = kCaptionStyle.copyWith(color: Colors.white, height: 1);
    final textWidth = toastWidth - _sidePadding * 2;
    final painter = TextPainter(
      text: TextSpan(text: text, style: oneLine),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: textWidth);
    final multiLine = painter.didExceedMaxLines;
    painter.dispose();
    return Container(
      width: toastWidth,
      constraints: const BoxConstraints(minHeight: height),
      padding: multiLine
          ? const EdgeInsets.symmetric(horizontal: _sidePadding, vertical: 10)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: kTextLight,
        borderRadius: BorderRadius.circular(50),
        boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 4)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (bell)
            Positioned(
              left: 17,
              top: 10,
              child: SvgPicture.asset(
                'assets/images/icon_toast_bell.svg',
                width: 13.8156,
                height: 16,
              ),
            ),
          if (multiLine)
            Text(
              text,
              textAlign: TextAlign.center,
              style: oneLine.copyWith(height: 1.4),
            )
          else
            SizedBox(
              height: height,
              child: Center(child: Text(text, style: oneLine)),
            ),
        ],
      ),
    );
  }
}

/// 시안 토스트 바닥(y 780)이 화면 아래에서 떨어진 거리(402×874 기준). 하단
/// 탭바(79)와 화면 하단 버튼 위에 놓인다.
const double _kToastBottomGap = 874 - 780;

/// 지금 떠 있는 토스트. 새 토스트가 뜨면 이전 것을 바로 걷어 겹치지 않는다.
OverlayEntry? _currentEntry;
OverlayState? _currentOverlay;
Completer<void>? _currentDone;

void _dismissCurrent() {
  // 앱(테스트) 루트가 바뀌어 Overlay가 이미 사라졌으면 걷을 것이 없다.
  if (_currentOverlay?.mounted ?? false) _currentEntry?.remove();
  _forgetCurrent();
}

void _forgetCurrent() {
  _currentEntry = null;
  _currentOverlay = null;
  final done = _currentDone;
  _currentDone = null;
  if (done != null && !done.isCompleted) done.complete();
}

/// 토스트를 띄우고 [duration] 뒤에 걷는다. 걷히면 Future가 끝난다.
///
/// [top]을 주면 그 자리(시안이 화면마다 자리를 정한 곳: 마이페이지 744,
/// 내 정보 수정 790)에, 없으면 화면 아래(시안 744 자리)에 띄우고 키보드가
/// 올라와 있으면 그 위로 올린다. 화면을 옮겨도 남도록 맨 위 Overlay에 띄운다.
/// [duration]이 없으면 짧은 문구는 시안대로 1.5초, 긴 문구(서버 오류 등)는
/// 읽을 시간을 더 줘 2.5초 띄운다.
Future<void> showLeafieToast(
  BuildContext context, {
  required String text,
  double? top,
  bool bell = false,
  Duration? duration,
}) {
  return showLeafieToastOn(
    Overlay.of(context, rootOverlay: true),
    text: text,
    top: top,
    bell: bell,
    duration: duration,
  );
}

/// [showLeafieToast]와 같지만 BuildContext 대신 Overlay를 직접 받는다.
/// Navigator 바깥(앱 루트)에서 띄울 때 쓴다.
Future<void> showLeafieToastOn(
  OverlayState overlay, {
  required String text,
  double? top,
  bool bell = false,
  Duration? duration,
}) {
  _dismissCurrent();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ToastHost(
      duration:
          duration ??
          (text.length > 20
              ? const Duration(milliseconds: 2500)
              : const Duration(milliseconds: 1500)),
      onTimeout: () {
        if (identical(_currentEntry, entry)) _dismissCurrent();
      },
      onGone: () {
        if (identical(_currentEntry, entry)) _forgetCurrent();
      },
      top: top,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: LeafieToast(text: text, bell: bell),
        ),
      ),
    ),
  );
  final done = Completer<void>();
  _currentEntry = entry;
  _currentOverlay = overlay;
  _currentDone = done;
  overlay.insert(entry);
  return done.future;
}

/// 토스트 한 개의 자리와 수명. 타이머를 위젯이 쥐고 있어, 화면이 통째로
/// 사라지면(앱 재시작·테스트 종료) 타이머도 같이 걷힌다.
class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.duration,
    required this.onTimeout,
    required this.onGone,
    required this.top,
    required this.child,
  });

  final Duration duration;
  final VoidCallback onTimeout;
  final VoidCallback onGone;
  final double? top;
  final Widget child;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onTimeout);
  }

  @override
  void dispose() {
    _timer.cancel();
    widget.onGone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = widget.top;
    if (top != null) {
      return Positioned(top: top, left: 0, right: 0, child: widget.child);
    }
    final media = MediaQuery.of(context);
    final gap = _kToastBottomGap * media.size.height / 874;
    final bottom = math.max(gap, media.viewInsets.bottom + 16);
    return Positioned(
      bottom: bottom,
      left: 0,
      right: 0,
      child: IgnorePointer(child: widget.child),
    );
  }
}
