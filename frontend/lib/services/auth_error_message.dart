import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 인증 실패를 화면에 띄울 한국어 문구로 바꾼다.
///
/// `AuthException.message`는 영어("User already registered" 등)이고, 연결
/// 실패는 예외 문자열이 그대로 담겨 와서 사용자에게 그대로 보이면 안 된다.
/// 코드로 갈리는 흔한 실패만 따로 적고, 나머지는 화면마다 넘긴 [fallback]을
/// 쓴다.
String authErrorMessage(AuthException error, {required String fallback}) {
  if (error is AuthRetryableFetchException) {
    return '네트워크 연결을 확인해 주세요.';
  }
  final code = error.code;
  if (code == ErrorCode.overRequestRateLimit.code ||
      code == ErrorCode.overEmailSendRateLimit.code) {
    return '요청이 너무 잦아요. 잠시 후 다시 시도해 주세요.';
  }
  if (code == ErrorCode.userAlreadyExists.code ||
      code == ErrorCode.emailExists.code) {
    return '이미 가입된 이메일입니다.';
  }
  if (code == ErrorCode.weakPassword.code) {
    return '비밀번호가 너무 쉬워요. 다른 비밀번호를 입력해 주세요.';
  }
  if (code == ErrorCode.samePassword.code) {
    return '지금 쓰는 비밀번호와 다른 비밀번호를 입력해 주세요.';
  }
  if (code == ErrorCode.emailNotConfirmed.code) {
    return '이메일 인증을 마친 뒤 로그인해 주세요.';
  }
  if (code == ErrorCode.sessionNotFound.code ||
      code == ErrorCode.sessionExpired.code) {
    return '로그인이 만료됐어요. 다시 로그인해 주세요.';
  }
  return fallback;
}
