import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_toggle_switch.dart';
import 'package:yeso_plant/widgets/mypage_cards.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';

void main() {
  testWidgets('마이페이지 카드와 토글 384x460 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(384, 460);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFFEBEBEB),
          body: _MypageGallery(),
        ),
      ),
    );

    await expectLater(
      find.byType(_MypageGallery),
      matchesGoldenFile('goldens/mypage_cards_384.png'),
    );
  });

  testWidgets('로그아웃 확인 모달 348x199 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(348, 199);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFFEBEBEB),
          body: Center(child: SignOutConfirmDialog()),
        ),
      ),
    );

    await expectLater(
      find.byType(SignOutConfirmDialog),
      matchesGoldenFile('goldens/sign_out_dialog_348.png'),
    );
  });
}

class _MypageGallery extends StatefulWidget {
  const _MypageGallery();

  @override
  State<_MypageGallery> createState() => _MypageGalleryState();
}

class _MypageGalleryState extends State<_MypageGallery> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: kBodyStyle,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileSummaryCard(
              nickname: '김윤지님',
              email: 'akdrotorl@naver.com',
              tenureLabel: '식집사가 된 지 128일째',
            ),
            // Figma 2353:710 하단 97.762 -> 2353:711 상단 111.762.
            const SizedBox(height: 14),
            ProfileMenuCard(
              onEditProfile: () {},
              onChangePassword: () {},
              onWithdraw: () {},
              notificationsEnabled: _notifications,
              onNotificationsChanged: (value) =>
                  setState(() => _notifications = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FigmaToggleSwitch(value: true, onChanged: (_) {}),
                const SizedBox(width: 16),
                FigmaToggleSwitch(value: false, onChanged: (_) {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
