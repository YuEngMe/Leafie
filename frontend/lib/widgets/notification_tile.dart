import 'package:flutter/material.dart';
import 'package:yeso_plant/services/notification_api.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/plant_detail_components.dart';

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

/// 알림 캐릭터는 그 알림 식물의 몸통·색·헤어로 그린다(시안 4534:19877).
/// 알림 응답에는 외형이 없어 plant_id로 식물 목록에서 찾는다. 찾지 못하면
/// (삭제된 식물, 식물과 무관한 알림) 기본 캐릭터를 쓴다.

/// 시안(4534:19903) 회색 원 48×48. 타일(top 169) 안 x=20 y=174.
const double kNotificationCharacterWidth = 48;
const double kNotificationCharacterHeight = 48;
const double kNotificationCharacterLeft = 20 - kNotificationTileLeft;
const double kNotificationCharacterTop = 174 - 169;
const Color kNotificationCharacterBackground = Color(0xFFCCCBCB);

/// 원 안 캐릭터(4889:1530). 몸통 22 폭, 몸통 가로 중심 x=43, 몸통 바닥
/// y=219. 헤어는 몸통 위로 얹혀 원 안(top 175)까지 올라온다.
const double _kNotificationBodyWidth = 22;
const double _kNotificationBodyCenterX = 43 - kNotificationTileLeft;
const double _kNotificationBodyBottom = 219 - 169;

/// `PlantCharacterArt` 박스는 폭의 649/698 높이이고, 몸통 밑선은 박스
/// 높이의 612/649 지점이다(plant_management_screen과 같은 환산).
final double _kNotificationArtWidth = plantArtWidthFor(
  _kNotificationBodyWidth,
);
final double _kNotificationArtHeight = _kNotificationArtWidth * 649 / 698;

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.plant,
  });

  final NotificationData notification;
  final VoidCallback onTap;

  /// 이 알림의 식물. 없으면 기본 캐릭터.
  final ManagedPlant? plant;

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
          boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 4)],
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
                  const Positioned(
                    left: kNotificationCharacterLeft,
                    top: kNotificationCharacterTop,
                    width: kNotificationCharacterWidth,
                    height: kNotificationCharacterHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kNotificationCharacterBackground,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: _kNotificationBodyCenterX - _kNotificationArtWidth / 2,
                    top:
                        _kNotificationBodyBottom -
                        _kNotificationArtHeight * 612 / 649,
                    width: _kNotificationArtWidth,
                    height: _kNotificationArtHeight,
                    child: PlantCharacterArt(
                      key: Key('notification-character-${notification.id}'),
                      width: _kNotificationArtWidth,
                      body: plantBodyFromId(plant?.bodyId),
                      colorId: plant?.colorId,
                      hairId: plant?.hairId,
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
                    top: (kNotificationTileHeight - 8.187793731689453) / 2,
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
