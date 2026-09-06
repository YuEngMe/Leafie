import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

/// Figma 3564:243(알림 설정), 2353:408(닉네임 변경)의 회색 알약 토스트.
///
/// 334×36, radius 50, `#A1A1A1`, 그림자 0 0 2 rgba(0,0,0,.18), 12px 흰 글씨
/// 중앙. 알림 쪽만 왼쪽 17px에 종 아이콘(13.816×16)이 붙는다.
class LeafieToast extends StatelessWidget {
  const LeafieToast({super.key, required this.text, this.bell = false});

  final String text;
  final bool bell;

  static const double width = 334;
  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kTextLight,
        borderRadius: BorderRadius.circular(50),
        boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 2)],
      ),
      child: Stack(
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
          Center(
            child: Text(
              text,
              style: kCaptionStyle.copyWith(color: Colors.white, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면 위 [top]에 토스트를 띄우고 [duration] 뒤에 걷는다. 시안은 화면마다
/// 자리가 달라(마이페이지 744, 내 정보 수정 790) 호출부가 top을 준다.
Future<void> showLeafieToast(
  BuildContext context, {
  required String text,
  required double top,
  bool bell = false,
  Duration duration = const Duration(milliseconds: 1500),
}) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: LeafieToast(text: text, bell: bell),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  return Future<void>.delayed(duration).whenComplete(entry.remove);
}
