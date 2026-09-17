# ADR 0001. 앱 아이콘 생성: flutter_launcher_icons

- 날짜: 2026-09-17
- 상태: 채택

## 맥락
디자이너가 새 로고·앱 아이콘 시안을 완성했다(Figma 4882:6). 앱 아이콘은
iOS가 크기별 PNG 15장 + `Contents.json` 매핑을, Android가 mipmap 5단계 +
adaptive icon(전경/배경 분리)을 요구한다. 원본 1024 한 장에서 이 규격을
채워야 한다.

## 결정
`flutter_launcher_icons`(dev_dependency)로 원본 1장에서 iOS/Android 전 크기와
Contents.json, adaptive 레이어를 자동 생성한다. adaptive 배경은 로고 배경색
(#FFB52A), 전경은 캐릭터 심볼을 쓴다.

## 대안
- **수동 리사이즈**: PIL로 20여 장을 직접 만들고 Contents.json을 손으로 맞춘다.
  규격(특히 Contents.json 매핑, Android adaptive 전경/배경 분리)을 사람이 지켜야
  해 실수 여지가 크고, 아이콘을 다시 바꿀 때마다 전량 재작업이다. 지금 한 번은
  가능하나 반복·정확성에서 불리해 제외했다.

## 결과
아이콘 교체가 "원본 PNG 교체 + `dart run flutter_launcher_icons`"로 단순해졌다.
비용은 dev_dependency 1개(런타임 번들에는 포함되지 않음). 앱 내 로고
(`brand_logo`)는 규격 문제가 없어 이 도구를 쓰지 않고 `assets/images/` PNG를
직접 교체한다.
