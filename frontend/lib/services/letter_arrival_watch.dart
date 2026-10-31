import 'package:flutter/foundation.dart';

/// 새 다이어리를 저장했다는 신호. 서버는 새 다이어리마다 식물 편지를 5~15분
/// 뒤(데모 서버는 몇 초 뒤) 보낸다. 홈은 평소에 편지 수를 다시 세지 않아
/// 홈 응답 시간을 그대로 두고, 이 신호를 받은 뒤 편지가 올 때까지만 센다.
class LetterArrivalWatch extends ChangeNotifier {
  LetterArrivalWatch._();

  static final instance = LetterArrivalWatch._();

  /// 이미 있던 다이어리를 고친 건 편지가 다시 오지 않으므로 부르지 않는다.
  void diaryCreated() => notifyListeners();
}
