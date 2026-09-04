// 앱바 뒤로가기(3345:996)는 7개 화면이 공유한다. 좌표가 틀어지면 전부
// 틀어지므로 시안 값을 여기서 잠가 둔다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

void main() {
  testWidgets('뒤로가기 꺾쇠가 시안 좌표에 앉는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: YesoAppBar(title: '마이페이지')),
      ),
    );
    await tester.pumpAndSettle();

    // 골든에는 상태바가 없어 시안 y에서 46을 뺀다.
    const statusBar = 46.0;
    final chevron = tester.getRect(find.byType(FigmaBackChevron));

    expect(chevron.left, closeTo(21.5, 0.5));
    expect(chevron.top + statusBar, closeTo(60, 0.5));
    expect(chevron.width, closeTo(FigmaBackChevron.figmaSize.width, 0.01));
    expect(chevron.height, closeTo(FigmaBackChevron.figmaSize.height, 0.01));
  });

  testWidgets('Material 기본 뒤로가기 아이콘을 쓰지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: YesoAppBar(title: '회원가입')),
      ),
    );

    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    expect(find.byType(FigmaBackChevron), findsOneWidget);
  });

  testWidgets('showBack이 false면 꺾쇠를 그리지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: YesoAppBar(title: '회원가입', showBack: false)),
      ),
    );

    expect(find.byType(FigmaBackChevron), findsNothing);
  });
}
