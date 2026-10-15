import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 입력창 밖을 탭하면 키보드를 내린다(디자이너 요청 2026-10).
///
/// Flutter 기본값은 모바일 터치로 바깥을 눌러도 포커스를 놓지 않아, iOS에서
/// 키보드를 내릴 방법이 없었다. 화면마다 `onTapOutside`를 달지 않고 앱 루트에서
/// 바깥 탭 intent 두 개를 덮어써 모든 입력창에 같은 규칙을 적용한다.
///
/// 손가락을 뗄 때 누른 자리에서 [kTouchSlop] 안이면 탭으로 보고 포커스를 놓는다.
/// 바깥을 끌어 스크롤할 때는 키보드를 그대로 둔다. 다른 입력창은 같은
/// [TextFieldTapRegion] 묶음이라 바깥으로 치지 않아 포커스가 그쪽으로 옮겨 간다.
class TapOutsideUnfocus extends StatefulWidget {
  const TapOutsideUnfocus({super.key, required this.child});

  final Widget child;

  @override
  State<TapOutsideUnfocus> createState() => _TapOutsideUnfocusState();
}

class _TapOutsideUnfocusState extends State<TapOutsideUnfocus> {
  Offset? _downPosition;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (intent) {
                _downPosition = intent.pointerDownEvent.position;
                return null;
              },
            ),
        EditableTextTapUpOutsideIntent:
            CallbackAction<EditableTextTapUpOutsideIntent>(
              onInvoke: (intent) {
                final down = _downPosition;
                _downPosition = null;
                if (down == null) return null;
                final moved = (intent.pointerUpEvent.position - down).distance;
                if (moved < kTouchSlop) intent.focusNode.unfocus();
                return null;
              },
            ),
      },
      child: widget.child,
    );
  }
}
