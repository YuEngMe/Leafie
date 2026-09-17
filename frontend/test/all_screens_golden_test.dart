import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/login_screen.dart';
import 'package:yeso_plant/screens/oauth_nickname_screen.dart';
import 'package:yeso_plant/screens/password_reset_screen.dart';
import 'package:yeso_plant/screens/plant_register_appearance_screen.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/screens/plant_register_environment_screen.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/screens/plant_register_personality_screen.dart';
import 'package:yeso_plant/screens/plant_species_search_screen.dart';
import 'package:yeso_plant/screens/signup_complete_screen.dart';
import 'package:yeso_plant/screens/signup_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

/// 골든은 값이 고정돼야 하므로 시안 그대로의 식물을 넘긴다.
final _goldenPlant = HomePlant(
  name: '씩씩이',
  startedOn: DateTime(2026, 1, 1),
  personalityType: 'OUTGOING',
  // Golden output must not drift as the current date advances.
  daysTogether: 258,
);

void main() {
  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kOrangeMain,
      surface: kBackgroundWhite,
    ),
    scaffoldBackgroundColor: kBackgroundWhite,
    fontFamily: kFontFamily,
  );

  PlantRegistrationDraft sampleDraft() => PlantRegistrationDraft(
    name: '새싹이',
    species: const PlantSpeciesCandidate(
      referenceId: 'catalog:ocimum-basilicum',
      displayName: '바질',
      scientificName: 'Ocimum basilicum',
      categorySuggestion: 'HERB',
    ),
  );

  Future<void> pumpGolden(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = AppLayout.referenceViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: theme, home: screen));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      await Future.wait([
        precacheImage(
          const AssetImage('assets/images/leafie_logo_symbol.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/leafie_logo_word.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/leafie_character.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/leafie_character_sprout.png'),
          context,
        ),
        for (final asset in [
          'assets/images/home_bg_default.png',
          'assets/images/home_bg_afternoon.png',
          'assets/images/home_bg_evening.png',
          'assets/images/home_bg_late_evening.png',
          'assets/images/icon_home_notification.png',
          'assets/images/icon_home_view_all.png',
          'assets/images/icon_home_view_diagnosis.png',
          'assets/images/icon_home_mailbox.png',
          'assets/images/icon_home_sun.png',
          'assets/images/icon_home_afternoon.png',
          'assets/images/icon_home_moon.png',
          'assets/images/icon_home_check.png',
        ])
          precacheImage(AssetImage(asset), context),
      ]);
    });
    await tester.pumpAndSettle();
  }

  final cases = <(String, String, Widget Function())>[
    ('로그인', 'login_402', () => const LoginScreen()),
    ('회원가입', 'signup_402', () => const SignupScreen()),
    ('비밀번호 재설정', 'password_reset_402', () => const PasswordResetScreen()),
    (
      '소셜 닉네임',
      'oauth_nickname_402',
      () => const OAuthNicknameScreen(providerLabel: '카카오톡'),
    ),
    ('회원가입 완료', 'signup_complete_402', () => const SignupCompleteScreen()),
    ('등록 이름', 'register_name_402', () => const PlantRegisterNameScreen()),
    ('식물 찾기', 'register_search_402', () => const PlantSpeciesSearchScreen()),
    (
      '키우는 장소',
      'register_environment_402',
      () => PlantRegisterEnvironmentScreen(draft: sampleDraft()),
    ),
    (
      '캐릭터 성격',
      'register_personality_402',
      () => PlantRegisterPersonalityScreen(draft: sampleDraft()),
    ),
    (
      '캐릭터 꾸미기',
      'register_appearance_402',
      () => PlantRegisterAppearanceScreen(draft: sampleDraft()),
    ),
    (
      '등록 완료',
      'register_complete_402',
      () => PlantRegisterCompleteScreen(draft: sampleDraft()),
    ),
    (
      '홈',
      'home_402',
      () => HomeScreen(plant: _goldenPlant, period: HomeTimePeriod.day),
    ),
  ];

  for (final entry in cases) {
    testWidgets('${entry.$1} 화면 402x874 스냅샷', (tester) async {
      await pumpGolden(tester, entry.$3());
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/${entry.$2}.png'),
      );
    });
  }

  testWidgets('로그인 화면 Figma 입력 상태 402x874 스냅샷', (tester) async {
    await pumpGolden(tester, const LoginScreen());
    await tester.enterText(
      find.byType(TextField).first,
      'seaminasun@naver.com',
    );
    await tester.enterText(find.byType(TextField).at(1), '1234567');
    await tester.pump();

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/login_filled_402.png'),
    );
  });

  testWidgets('회원가입 화면 Figma 입력 상태 402x874 스냅샷', (tester) async {
    await pumpGolden(tester, const SignupScreen());
    await tester.enterText(
      find.byType(TextField).first,
      'seaminasun@naver.com',
    );
    await tester.pump();
    await tester.tap(find.text('발송'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.enterText(find.byType(TextField).at(3), '식집사 콩쥐');
    await tester.pump();

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/signup_filled_402.png'),
    );
  });
}
