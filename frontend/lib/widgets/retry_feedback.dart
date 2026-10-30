import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:yeso_plant/theme/app_motion.dart';

/// '다시 시도' 버튼이 보여 줄 상태.
enum RetryPhase { idle, busy, failed }

// TODO(design): 시안에 없는 상태라 디자이너 확정 전 임시 문구.
const String kRetryBusyLabel = '연결 중…';
const String kRetryFailedMessage = '아직 연결되지 않았어요';

/// '다시 시도'를 눌러도 화면이 그대로라 눌렸는지 모르겠다는 피드백(10/30).
/// 누른 즉시 가벼운 진동과 함께 [RetryPhase.busy]로 바꾸고, 다시 실패하면
/// [RetryPhase.failed]를 [AppMotion.retryFailedHold]만큼 보여 준다. 요청이
/// 곧바로 실패해도 busy가 [AppMotion.retryMinBusy]는 유지된다.
///
/// 상태를 이 위젯이 쥐므로, 재시도하는 동안 부모가 이 위젯을 로딩 화면으로
/// 갈아 끼우면 안 된다. 각 화면은 오류 화면을 둔 채 다시 불러오고 성공
/// 여부만 [onRetry]로 돌려준다.
class RetryFeedback extends StatefulWidget {
  const RetryFeedback({
    super.key,
    required this.onRetry,
    required this.builder,
    this.onSucceeded,
  });

  /// 다시 시도해서 성공하면 true.
  final Future<bool> Function() onRetry;

  /// busy를 다 보여 준 뒤 성공했을 때. 모달을 닫는 자리에서 쓴다.
  final VoidCallback? onSucceeded;

  /// [retry]는 busy 동안에도 그대로 넘긴다. 버튼을 회색(비활성)으로
  /// 바꾸지 않고 겹친 탭만 막는다.
  final Widget Function(
    BuildContext context,
    RetryPhase phase,
    VoidCallback retry,
  )
  builder;

  @override
  State<RetryFeedback> createState() => _RetryFeedbackState();
}

class _RetryFeedbackState extends State<RetryFeedback> {
  RetryPhase _phase = RetryPhase.idle;
  Timer? _minBusyTimer;
  Timer? _failedTimer;

  Future<void> _retry() async {
    if (_phase == RetryPhase.busy) return;
    unawaited(HapticFeedback.lightImpact());
    _failedTimer?.cancel();
    setState(() => _phase = RetryPhase.busy);
    // 성공하면 부모가 이 위젯을 걷어 내므로, 남은 대기는 dispose에서 끊는다.
    final minBusy = Completer<void>();
    _minBusyTimer = Timer(AppMotion.retryMinBusy, minBusy.complete);
    final succeeded = await _attempt();
    if (!mounted) return;
    await minBusy.future;
    if (!mounted) return;
    if (succeeded) {
      setState(() => _phase = RetryPhase.idle);
      widget.onSucceeded?.call();
      return;
    }
    setState(() => _phase = RetryPhase.failed);
    _failedTimer = Timer(AppMotion.retryFailedHold, () {
      if (mounted) setState(() => _phase = RetryPhase.idle);
    });
  }

  Future<bool> _attempt() async {
    try {
      return await widget.onRetry();
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _minBusyTimer?.cancel();
    _failedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _phase, _retry);
}
