import 'package:flutter/material.dart';

/// 찍은 사진 확인 화면 아래의 반투명 막대와 '다시 촬영' / '다음' 버튼.
///
/// 진단(4534:20043)과 식물 등록(4534:1110)이 같은 구성이다. 등록 시안은 옛
/// 자리(막대 top 815·높이 59)라 디자이너가 진단 쪽을 고친 최신 자리(메모
/// 6049:2755: 막대를 14 올리고 글자를 10씩 안쪽·12 위로)를 같이 쓴다.
/// 화면 바닥에 `Positioned(bottom: 0, height: heightOf(context))`로 깐다.
class PhotoConfirmBar extends StatelessWidget {
  const PhotoConfirmBar({
    super.key,
    required this.onRetake,
    required this.onNext,
    this.retakeKey,
    this.nextKey,
  });

  /// null이면 버튼을 누를 수 없다(제출 중 등).
  final VoidCallback? onRetake;
  final VoidCallback? onNext;
  final Key? retakeKey;
  final Key? nextKey;

  /// 막대 높이. 시안(4534:20064)은 top 801·높이 73이다. 홈 인디케이터가
  /// 시안(34)보다 큰 기기에서는 그만큼 늘린다.
  static double heightOf(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return bottomInset > 34 ? bottomInset + 39 : 73.0;
  }

  @override
  Widget build(BuildContext context) {
    // 글자 중심 y 831.57(막대 top 801 기준). 글자는 홈 인디케이터 구역에
    // 걸쳐 있다. 안전 영역을 빼고 남은 칸에 TextButton(위아래 여백 8)을
    // 넣으면 글자 칸이 줄어 잘렸으므로 막대 top 기준으로 놓는다.
    const labelCenterFromBarTop = 831.57 - 801;
    const hitHeight = 44.0;
    const hitPadding = 12.0;
    final buttonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: hitPadding),
      minimumSize: const Size(0, hitHeight),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Stack(
        children: [
          // '다시 촬영' 글자 x=40, '다음' 글자 오른쪽 끝 x=361.04.
          Positioned(
            left: 40 - hitPadding,
            top: labelCenterFromBarTop - hitHeight / 2,
            child: TextButton(
              key: retakeKey,
              style: buttonStyle,
              onPressed: onRetake,
              child: const Text('다시 촬영', style: _actionStyle),
            ),
          ),
          Positioned(
            right: 402 - 361.04 - hitPadding,
            top: labelCenterFromBarTop - hitHeight / 2,
            child: TextButton(
              key: nextKey,
              style: buttonStyle,
              onPressed: onNext,
              child: const Text('다음', style: _actionStyle),
            ),
          ),
        ],
      ),
    );
  }
}

const _actionStyle = TextStyle(
  color: Colors.white,
  fontFamily: 'Paperlogy',
  fontSize: 16,
  fontWeight: FontWeight.w500,
);
