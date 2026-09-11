import 'package:flutter/material.dart';
import 'package:yeso_plant/services/notification_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

// 시안 3448:2(알림). 좌표는 프레임 402×874 기준 절대값이고, 본문 top은
// 상태바 46 + 앱바 46 = 92다.

/// 절 헤더 잉크 top 140 − 본문 top 92.
const double kNotificationSectionTop = 48;

/// Flutter가 Paperlogy 16을 그리는 줄 높이. 시안 텍스트 박스는 19지만
/// 실제 렌더는 23이라 헤더 아래 여백을 이 값으로 뺀다.
const double kNotificationHeaderRenderHeight = 23;

/// 헤더 잉크 top 140 → 첫 타일 top 169.
const double kNotificationHeaderToTile = 29 - kNotificationHeaderRenderHeight;

/// 타일 top 242.196 − 이전 타일 바닥(169 + 58.196).
const double kNotificationTileGap = 15;

const double kNotificationTileHeight = 58.19580078125;
const double kNotificationTileLeft = 14;
const double kNotificationTileWidth = 374;

/// 3448:113 / 3456:4891.
const Color kNotificationDotUnread = Color(0xFFFF5E5E);
const Color kNotificationDotRead = Color(0xFFCCCBCB);

/// 3448:28 제목.
const Color kNotificationTitleColor = Color(0xFF1F2E21);

/// 시안의 캐릭터 PNG. `NotificationData`에 어떤 캐릭터인지 알려주는 필드가
/// 없어 종류별로 고를 수 없다.
// TODO(design): 알림에 캐릭터/식물 이미지 필드가 생기면 종류별 에셋으로 바꾼다.
const String kNotificationCharacterAsset =
    'assets/images/notification_character.png';

/// 시안 3448:4408 캐릭터 박스(30.904×46.5, 타일 안에서 세로 중앙, x=32).
const double kNotificationCharacterWidth = 30.904;
const double kNotificationCharacterHeight = 46.5;
const double kNotificationCharacterLeft = 32 - kNotificationTileLeft;

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final NotificationData notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kNotificationTileLeft),
      child: DecoratedBox(
        // 3448:26: 흰 알약, radius 50, 그림자 0 0 4 rgba(0,0,0,.18).
        decoration: BoxDecoration(
          color: kBackgroundWhite,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [
            BoxShadow(color: Color(0x2E000000), blurRadius: 4),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: Key('notification-${notification.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: SizedBox(
              width: kNotificationTileWidth,
              height: kNotificationTileHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: kNotificationCharacterLeft,
                    top:
                        (kNotificationTileHeight -
                            kNotificationCharacterHeight) /
                        2,
                    width: kNotificationCharacterWidth,
                    height: kNotificationCharacterHeight,
                    child: Image.asset(
                      kNotificationCharacterAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    // 3448:28 제목 x=109.293.
                    left: 109.29314422607422 - kNotificationTileLeft,
                    right: 374 - 355 + 8.187793731689453,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kBodyStyle.copyWith(
                          color: kNotificationTitleColor,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    // 3448:113 점 x=355, 지름 8.188, 타일 세로 중앙.
                    key: Key('notification-dot-${notification.id}'),
                    left: 355 - kNotificationTileLeft,
                    top:
                        (kNotificationTileHeight - 8.187793731689453) / 2,
                    width: 8.187793731689453,
                    height: 8.187793731689453,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: unread
                            ? kNotificationDotUnread
                            : kNotificationDotRead,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
