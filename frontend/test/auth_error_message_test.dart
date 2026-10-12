// Supabase 인증 실패 문구가 영어 원문 대신 한국어로 보이는지 확인한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/services/auth_error_message.dart';

const _fallback = '화면별 기본 문구';

String _message(AuthException error) =>
    authErrorMessage(error, fallback: _fallback);

void main() {
  test('연결 실패는 예외 문자열 대신 네트워크 안내를 띄운다', () {
    expect(
      _message(AuthRetryableFetchException(message: 'ClientException: ...')),
      '네트워크 연결을 확인해 주세요.',
    );
  });

  test('코드로 갈리는 흔한 실패는 한국어로 바꾼다', () {
    final cases = {
      'user_already_exists': '이미 가입된 이메일입니다.',
      'email_exists': '이미 가입된 이메일입니다.',
      'weak_password': '비밀번호가 너무 쉬워요. 다른 비밀번호를 입력해 주세요.',
      'same_password': '지금 쓰는 비밀번호와 다른 비밀번호를 입력해 주세요.',
      'email_not_confirmed': '이메일 인증을 마친 뒤 로그인해 주세요.',
      'over_request_rate_limit': '요청이 너무 잦아요. 잠시 후 다시 시도해 주세요.',
      'over_email_send_rate_limit': '요청이 너무 잦아요. 잠시 후 다시 시도해 주세요.',
      'session_expired': '로그인이 만료됐어요. 다시 로그인해 주세요.',
    };
    for (final entry in cases.entries) {
      expect(
        _message(
          AuthApiException('English', statusCode: '422', code: entry.key),
        ),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('모르는 실패는 영어 원문 대신 화면별 기본 문구를 쓴다', () {
    expect(
      _message(const AuthApiException('Something went wrong', code: 'xyz')),
      _fallback,
    );
    expect(_message(const AuthException('Unknown')), _fallback);
  });
}
