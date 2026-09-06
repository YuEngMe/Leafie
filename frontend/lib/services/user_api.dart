import 'package:yeso_plant/services/leafie_api_client.dart';

abstract interface class UserRepository {
  Future<UserProfileData> getProfile();

  Future<UserProfileData> updateNickname(String nickname);

  Future<bool> updateNotificationSettings(bool enabled);

  Future<void> deleteAccount();
}

class UserApi implements UserRepository {
  UserApi({LeafieApiClient? client}) : _client = client ?? LeafieApiClient();

  final LeafieApiClient _client;

  @override
  Future<UserProfileData> getProfile() async {
    final response = await _client.get('/users/me');
    return _parseProfile(response);
  }

  @override
  Future<UserProfileData> updateNickname(String nickname) async {
    final normalized = nickname.trim();
    if (normalized.isEmpty) {
      throw const LeafieApiException(
        code: 'INVALID_NICKNAME',
        message: '닉네임을 입력해주세요.',
        statusCode: 422,
      );
    }
    final response = await _client.patch(
      '/users/me',
      body: {'nickname': normalized},
    );
    return _parseProfile(response);
  }

  @override
  Future<bool> updateNotificationSettings(bool enabled) async {
    final response = await _client.patch(
      '/users/me/notification-settings',
      body: {'push_enabled': enabled},
    );
    final pushEnabled = response['push_enabled'];
    if (pushEnabled is! bool) {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '알림 설정을 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
    return pushEnabled;
  }

  @override
  Future<void> deleteAccount() =>
      _client.delete('/users/me', body: const {'confirmation': 'DELETE'});

  UserProfileData _parseProfile(Map<String, dynamic> response) {
    try {
      return UserProfileData.fromJson(response);
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '회원 정보를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }
}

class UserProfileData {
  const UserProfileData({
    required this.nickname,
    required this.email,
    required this.gardenerDays,
    required this.pushEnabled,
    required this.profileCompleted,
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    final nickname = json['nickname'];
    final email = json['email'];
    final gardenerDays = json['gardener_days'];
    final pushEnabled = json['push_enabled'];
    final profileCompleted = json['profile_completed'];
    if (nickname is! String ||
        nickname.isEmpty ||
        email is! String ||
        gardenerDays is! int ||
        gardenerDays < 0 ||
        pushEnabled is! bool ||
        profileCompleted is! bool) {
      throw const FormatException('Invalid user profile');
    }
    return UserProfileData(
      nickname: nickname,
      email: email,
      gardenerDays: gardenerDays,
      pushEnabled: pushEnabled,
      profileCompleted: profileCompleted,
    );
  }

  final String nickname;
  final String email;
  final int gardenerDays;
  final bool pushEnabled;
  final bool profileCompleted;
}
