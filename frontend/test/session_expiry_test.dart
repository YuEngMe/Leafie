import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';

// Session.expiresAt은 accessToken JWT의 exp 클레임에서 읽는다.
Session _sessionExpiringAt(DateTime expiry) {
  final payload = base64Url
      .encode(
        utf8.encode(jsonEncode({'exp': expiry.millisecondsSinceEpoch ~/ 1000})),
      )
      .replaceAll('=', '');
  return Session(
    accessToken: 'h.$payload.s',
    tokenType: 'bearer',
    user: const User(
      id: 'u',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '',
    ),
  );
}

void main() {
  final now = DateTime(2026, 9, 9, 12);

  test('만료 30초 전부터는 곧 만료로 본다', () {
    expect(
      sessionExpiresSoon(
        _sessionExpiringAt(now.add(const Duration(seconds: 10))),
        now: now,
      ),
      isTrue,
    );
    expect(
      sessionExpiresSoon(
        _sessionExpiringAt(now.subtract(const Duration(hours: 1))),
        now: now,
      ),
      isTrue,
    );
  });

  test('넉넉히 남은 토큰은 그대로 쓴다', () {
    expect(
      sessionExpiresSoon(
        _sessionExpiringAt(now.add(const Duration(minutes: 5))),
        now: now,
      ),
      isFalse,
    );
  });
}
