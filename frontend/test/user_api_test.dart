import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/user_api.dart';

Map<String, Object?> profileJson({
  String nickname = '새싹이',
  bool pushEnabled = false,
}) => {
  'user_id': '4c738341-ef6b-4ca9-8eec-f6423e3e62ed',
  'email': 'leafie@example.com',
  'email_verified_at': '2026-09-01T00:00:00Z',
  'auth_providers': ['email'],
  'can_change_password': true,
  'nickname': nickname,
  'timezone': 'Asia/Seoul',
  'selected_plant_id': null,
  'push_enabled': pushEnabled,
  'profile_completed': true,
  'profile_completed_at': '2026-09-01T00:00:00Z',
  'gardener_days': 5,
};

LeafieApiClient client(LeafieTransport transport) => LeafieApiClient(
  baseUrl: 'http://localhost:8000/api/v1',
  accessTokenProvider: () async => 'test-token',
  transport: transport,
);

void main() {
  test('회원 정보를 조회한다', () async {
    late LeafieHttpRequest request;
    final api = UserApi(
      client: client((input) async {
        request = input;
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode(profileJson()),
        );
      }),
    );

    final profile = await api.getProfile();

    expect(request.method, 'GET');
    expect(request.uri.path, '/api/v1/users/me');
    expect(profile.nickname, '새싹이');
    expect(profile.gardenerDays, 5);
  });

  test('닉네임과 알림 설정을 PATCH한다', () async {
    final requests = <LeafieHttpRequest>[];
    final api = UserApi(
      client: client((input) async {
        requests.add(input);
        if (input.uri.path.endsWith('notification-settings')) {
          return const LeafieHttpResponse(
            statusCode: 200,
            body: '{"push_enabled":true}',
          );
        }
        return LeafieHttpResponse(
          statusCode: 200,
          body: jsonEncode(profileJson(nickname: '변경이름')),
        );
      }),
    );

    final profile = await api.updateNickname('  변경이름  ');
    final enabled = await api.updateNotificationSettings(true);

    expect(profile.nickname, '변경이름');
    expect(enabled, isTrue);
    expect(requests[0].method, 'PATCH');
    expect(requests[0].body, {'nickname': '변경이름'});
    expect(requests[1].method, 'PATCH');
    expect(requests[1].body, {'push_enabled': true});
  });

  test('회원 탈퇴는 확인 문자열을 담아 DELETE한다', () async {
    late LeafieHttpRequest request;
    final api = UserApi(
      client: client((input) async {
        request = input;
        return const LeafieHttpResponse(statusCode: 204, body: '');
      }),
    );

    await api.deleteAccount();

    expect(request.method, 'DELETE');
    expect(request.uri.path, '/api/v1/users/me');
    expect(request.body, {'confirmation': 'DELETE'});
  });
}
