// 시안 글자와 다르게 적혀 있던 문구들(2026-09-07 감사). 글자 단위로 고정한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/plant_register_personality_screen.dart';

void main() {
  test('성격 6종의 이름·순서가 시안 2318:3129~3430과 같다', () {
    expect(kPersonalityLabels, [
      '활발한 성격',
      '시크한 성격',
      '귀여운 성격',
      '소심한 성격',
      '짝사랑 성격',
      '충청도 성격',
    ]);
  });
}
