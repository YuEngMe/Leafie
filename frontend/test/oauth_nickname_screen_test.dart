// 소셜 로그인 닉네임 설정 화면: 빈 값 검증과 provider 라벨 표시만 확인한다.
// updateUser는 실제 Supabase 호출이라 여기서는 검증하지 않는다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/oauth_nickname_screen.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/services/user_api.dart';
import 'package:yeso_plant/widgets/onboarding_copy.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';
import 'package:yeso_plant/widgets/onboarding_fields.dart';

class _NicknameRepository implements UserRepository {
  String? saved;

  @override
  Future<UserProfileData> updateNickname(String nickname) async {
    saved = nickname;
    return UserProfileData(
      nickname: nickname,
      email: 'social@example.com',
      gardenerDays: 0,
      pushEnabled: false,
      profileCompleted: true,
    );
  }

  @override
  Future<void> deleteAccount() => throw UnimplementedError();

  @override
  Future<UserProfileData> getProfile() => throw UnimplementedError();

  @override
  Future<bool> updateNotificationSettings(bool enabled) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('AppBar 타이틀에 provider 이름이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OAuthNicknameScreen(providerLabel: '카카오톡')),
    );

    expect(find.text('카카오톡 로그인'), findsOneWidget);
    expect(find.byType(OnboardingCopy), findsOneWidget);
    expect(find.byType(SignupNicknameField), findsOneWidget);
    expect(find.text('닉네임을 설정해주세요!'), findsOneWidget);
  });

  testWidgets('닉네임을 비운 채 완료 입력을 보내면 안내만 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OAuthNicknameScreen(providerLabel: '네이버')),
    );

    await tester.tap(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);
  });

  testWidgets('뒤로가기를 누르면 회원가입 중단 확인 모달을 연다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OAuthNicknameScreen(providerLabel: '카카오톡')),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(SignupAbortDialog), findsOneWidget);
    expect(find.text('회원가입을 중단하시겠습니까?'), findsOneWidget);
  });

  testWidgets('닉네임을 서버에 저장한 뒤 홈으로 이동한다', (tester) async {
    final repository = _NicknameRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: OAuthNicknameScreen(
          providerLabel: '카카오톡',
          repository: repository,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '소셜새싹');
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(repository.saved, '소셜새싹');
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
