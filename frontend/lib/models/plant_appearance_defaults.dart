/// 백엔드 BodyType/ExpressionType enum의 기본값.
///
/// 바디·표정 선택 UI는 아직 없어(#84·#85) 등록 시 이 값을 보내고,
/// 응답에 알 수 없는 값이 오면 이 값으로 폴백한다.
const String kDefaultBodyId = 'body_circle';
const String kDefaultExpressionId = 'expression_default';

/// 백엔드가 enum으로 검증하는 값들. 응답 스키마는 아직 body_id/expression_id만
/// enum이고 color_id/hair_id는 평문 str이라, 파싱에서는 예외를 던지지 않고
/// 모르는 값이면 기본값으로 떨어뜨린다.
const Set<String> kKnownBodyIds = {'body_circle', 'body_thumb', 'body_square'};
const Set<String> kKnownExpressionIds = {
  'expression_default',
  'expression_happy',
  'expression_neutral',
  'expression_sad',
};

String normalizeBodyId(Object? value) =>
    value is String && kKnownBodyIds.contains(value) ? value : kDefaultBodyId;

String normalizeExpressionId(Object? value) =>
    value is String && kKnownExpressionIds.contains(value)
    ? value
    : kDefaultExpressionId;
