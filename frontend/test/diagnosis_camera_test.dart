// 인앱 카메라(4534:20001). 실기기 카메라를 열 수 없으니 카메라 목록과
// 앨범 선택을 갈아끼워 조작과 좌표만 확인한다.

import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/diagnosis_camera_screen.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

void _setUpView(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 46, bottom: 34);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('카메라를 못 열면 이유를 보여 준다', (tester) async {
    _setUpView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisCameraScreen(
          openCameras: () async => const <CameraDescription>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('쓸 수 있는 카메라가 없어요.'), findsOneWidget);
    // 가운데 초점 십자가 문구를 가려서(HG-ISS-019) 오류일 땐 가이드를 숨긴다.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader is SvgAssetLoader &&
            (widget.bytesLoader as SvgAssetLoader).assetName ==
                'assets/images/icon_camera_focus.svg',
      ),
      findsNothing,
    );
  });

  testWidgets('뒤로 꺾쇠와 꺼진 플래시는 시안(4534:20001) 값이다', (tester) async {
    _setUpView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisCameraScreen(
          openCameras: () async => const <CameraDescription>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 4534:20042 꺾쇠 x21.52 y60. 예전엔 6px 오른쪽, 3px 아래였다.
    final back = tester.getRect(find.byType(FigmaBackChevron));
    expect(back.left, closeTo(21.52, 0.5));
    expect(back.top, closeTo(60, 0.5));
    // 꺼진 상태도 시안처럼 흰 아이콘 그대로다(흐리게 덮지 않는다).
    expect(
      find.ancestor(
        of: find.bySemanticsLabel('플래시 켜기'),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('앨범에서 고르면 그 사진을 돌려준다', (tester) async {
    _setUpView(tester);
    final bytes = Uint8List.fromList([1, 2, 3]);
    Uint8List? popped;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<Uint8List>(
                MaterialPageRoute(
                  builder: (_) => DiagnosisCameraScreen(
                    openCameras: () async => const <CameraDescription>[],
                    albumPicker: () async => bytes,
                  ),
                ),
              );
            },
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('앨범에서 고르기'));
    await tester.pumpAndSettle();

    expect(popped, bytes);
  });

  testWidgets('셔터·앨범·플래시가 시안 자리에 앉는다', (tester) async {
    _setUpView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisCameraScreen(
          openCameras: () async => const <CameraDescription>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 4534:20023 셔터 x168 y761.234 65.765.
    final shutter = tester.getRect(find.bySemanticsLabel('사진 찍기'));
    expect(shutter.left, closeTo(168, 1));
    expect(shutter.top, closeTo(761.234, 1));
    expect(shutter.width, closeTo(65.765, 1));

    // 4534:20037 앨범 x52 y779, 4534:20041 플래시 x325 y774.
    // 탭 범위를 48로 넓혔으므로 그림(SVG) 자체를 잰다.
    final album = tester.getRect(
      find.descendant(
        of: find.bySemanticsLabel('앨범에서 고르기'),
        matching: find.byType(SvgPicture),
      ),
    );
    expect(album.left, closeTo(52, 1));
    expect(album.top, closeTo(779, 1));

    final flash = tester.getRect(
      find.descendant(
        of: find.bySemanticsLabel('플래시 켜기'),
        matching: find.byType(SvgPicture),
      ),
    );
    expect(flash.left, closeTo(325, 1));
    expect(flash.top, closeTo(774, 1));
  });
}
