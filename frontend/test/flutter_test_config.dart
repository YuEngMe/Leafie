import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  await testMain();
}
