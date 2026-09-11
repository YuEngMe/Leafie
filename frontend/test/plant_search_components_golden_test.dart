import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_search_components.dart';

void main() {
  testWidgets('식물 결과 카드 366x470 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(366, 470);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFEBEBEB),
          body: Center(
            child: PlantResultCard(
              // 실제 사진은 런타임에 들어오므로 단색으로 자리만 잡는다.
              imageProvider: MemoryImage(_greenPixelPng),
              speciesName: '바위채송화',
              familyName: '돌나무과',
              bloomSeason: '8월 ~ 9월',
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(PlantResultCard),
      matchesGoldenFile('goldens/plant_result_card_366.png'),
    );
  });

  testWidgets('결과 확인 버튼 쌍 366x84 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(366, 84);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: Scaffold(
          backgroundColor: const Color(0xFFEBEBEB),
          body: Center(
            child: PlantResultConfirmButtons(onConfirm: () {}, onReject: () {}),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(PlantResultConfirmButtons),
      matchesGoldenFile('goldens/plant_confirm_buttons_366.png'),
    );
  });

  testWidgets('카메라 뷰파인더 288x287 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(288, 287);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFFEBEBEB),
          body: CameraViewfinderOverlay(),
        ),
      ),
    );

    await expectLater(
      find.byType(CameraViewfinderOverlay),
      matchesGoldenFile('goldens/camera_viewfinder_288.png'),
    );
  });

  testWidgets('날짜 피커 시트 402x325 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(402, 325);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: Scaffold(
          body: PlantDatePickerSheet(initialDate: DateTime(2025, 3, 24)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PlantDatePickerSheet),
      matchesGoldenFile('goldens/plant_date_picker_402.png'),
    );
  });
}

/// 골든에서 사진 자리를 채우는 1x1 초록 PNG.
final _greenPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
