import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yeso_plant/widgets/photo_confirm_bar.dart';

/// Figma 4534:1110 "캐릭터 등록4". 식물 등록에서 찍은 사진을 확인한다.
///
/// 시안은 사진을 화면 가득 깔고 아래 막대에 '다시 촬영' / '다음'만 둔다
/// (위쪽 뒤로가기·제목 없음). '다음'이면 true, '다시 촬영'이면 false로
/// 닫는다. 뒤로 밀어 닫으면 null이다.
class PlantPhotoConfirmScreen extends StatelessWidget {
  const PlantPhotoConfirmScreen({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              bytes,
              key: const ValueKey('plant-confirm-photo'),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: PhotoConfirmBar.heightOf(context),
              child: PhotoConfirmBar(
                retakeKey: const ValueKey('plant-retake-button'),
                nextKey: const ValueKey('plant-next-button'),
                onRetake: () => Navigator.of(context).pop(false),
                onNext: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
