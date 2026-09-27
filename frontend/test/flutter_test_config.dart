import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final paperlogyLoader = FontLoader('Paperlogy')
      ..addFont(rootBundle.load('assets/fonts/Paperlogy-4Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Paperlogy-5Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Paperlogy-6SemiBold.ttf'));
    final materialIconsLoader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));

    await Future.wait([paperlogyLoader.load(), materialIconsLoader.load()]);
  });

  // 등록 임시저장이 SharedPreferences를 쓰는데 테스트에는 플랫폼 응답이 없어
  // await가 끝나지 않는다. 매 테스트를 빈 메모리 저장소로 시작한다.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  await testMain();
}
