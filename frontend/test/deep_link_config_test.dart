import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase가 단독으로 OAuth 딥링크를 처리하도록 플랫폼 설정을 비활성화한다', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final iosInfoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      androidManifest,
      contains(
        'android:name="flutter_deeplinking_enabled" android:value="false"',
      ),
    );
    expect(
      iosInfoPlist,
      contains('<key>FlutterDeepLinkingEnabled</key>\n\t<false/>'),
    );
  });
}
