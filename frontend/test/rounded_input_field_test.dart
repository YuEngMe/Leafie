// 공용 입력칸이 정하는 시안 값(눈 아이콘 자리, 가림 문자, 힌트 자간)을
// 잠근다. 화면마다 눈 아이콘이 5~16px씩 어긋나고 가림 문자가 작은 •로
// 찍히던 것을 4534:22 섹션 시안 값으로 맞춘 뒤 추가했다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_glyphs.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';

Future<void> _pump(WidgetTester tester, Widget field) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: kFontFamily),
      home: Scaffold(
        body: Center(child: SizedBox(width: 334, child: field)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 흰 바탕·둥근 모서리를 그리는 입력칸 상자.
Rect _fieldBox(WidgetTester tester) => tester.getRect(
  find
      .descendant(
        of: find.byType(RoundedInputField),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      )
      .first,
);

/// 칸 왼쪽 위를 원점으로 한 눈 아이콘 상자.
Rect _eyeInField(WidgetTester tester) {
  final field = _fieldBox(tester);
  return tester.getRect(find.byType(FigmaEyeIcon)).shift(-field.topLeft);
}

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

void main() {
  testWidgets('인증 화면 눈은 칸 안 x292·top12 자리에 22.63×27.39로 놓인다', (tester) async {
    final controller = TextEditingController(text: 'secret12');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      RoundedInputField(
        label: '비밀번호',
        labelGap: 1,
        controller: controller,
        obscureText: true,
        height: AppLayout.onboardingControlHeight,
      ),
    );

    // 회원가입 4534:2076 · 비밀번호 변경 4534:2784 · 로그인 4534:1343.
    final eye = _eyeInField(tester);
    expect(eye.left, closeTo(292, 0.5));
    expect(eye.top, closeTo(12, 0.5));
    expect(eye.width, closeTo(22.63, 0.01));
    expect(eye.height, closeTo(27.39, 0.01));
  });

  testWidgets('기기연결 눈은 칸 안 x282 자리에 시안 그룹 크기로 놓인다', (tester) async {
    final controller = TextEditingController(text: '48201937');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      RoundedInputField(
        label: '기기 PIN',
        labelGap: 4,
        controller: controller,
        obscureText: true,
        eyeVariant: FigmaEyeVariant.sensor,
        height: 51,
      ),
    );

    // PIN 5728:5761 · Wi-Fi 비밀번호 5728:5842.
    final eye = _eyeInField(tester);
    expect(eye.left, closeTo(282, 0.5));
    expect(eye.top, closeTo(12, 0.6));
    expect(eye.width, closeTo(23.51, 0.01));
  });

  testWidgets('가림 문자는 연회색 12 Regular ●이고, 눈을 누르면 평문 스타일로 바뀐다', (tester) async {
    final controller = TextEditingController(text: 'secret12');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      RoundedInputField(
        controller: controller,
        obscureText: true,
        height: AppLayout.onboardingControlHeight,
      ),
    );

    // 4534:2075 — Paperlogy Regular 12, #A1A1A1, ●.
    var editable = _editable(tester);
    expect(editable.obscureText, isTrue);
    expect(editable.obscuringCharacter, '●');
    expect(editable.style.fontSize, 12);
    expect(editable.style.fontWeight, FontWeight.w400);
    expect(editable.style.color, kTextLight);
    expect(editable.style.letterSpacing, 0);
    expect(
      tester.widget<FigmaEyeIcon>(find.byType(FigmaEyeIcon)).obscured,
      isTrue,
    );

    await tester.tap(find.byType(FigmaEyeIcon));
    await tester.pump();

    // 4534:2840 — 평문은 14 Medium 진한 텍스트, 눈은 뜬 상태(4534:2841).
    editable = _editable(tester);
    expect(editable.obscureText, isFalse);
    expect(editable.style.fontSize, 14);
    expect(editable.style.color, kTextDark);
    expect(
      tester.widget<FigmaEyeIcon>(find.byType(FigmaEyeIcon)).obscured,
      isFalse,
    );
  });

  testWidgets('힌트와 입력 글자에 Material 기본 자간 0.5가 붙지 않는다', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      RoundedInputField(
        controller: controller,
        hintText: '예: 베란다',
        height: AppLayout.onboardingControlHeight,
      ),
    );

    // 시안 '작은 글씨'·'항목' 스타일은 letterSpacing 0이다.
    final hint = tester.widget<Text>(find.text('예: 베란다'));
    expect(hint.style?.letterSpacing, 0);
    expect(_editable(tester).style.letterSpacing, 0);
  });

  testWidgets('첫 글자를 넣어 눈이 나타나도 입력 포커스가 유지된다', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      RoundedInputField(
        controller: controller,
        obscureText: true,
        hintText: '비밀번호를 입력하세요.',
        height: AppLayout.onboardingControlHeight,
      ),
    );
    expect(find.byType(FigmaEyeIcon), findsNothing);

    await tester.showKeyboard(find.byType(TextField));
    final state = tester.state(find.byType(EditableText));
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();

    // 눈이 생기면서 TextField가 다시 만들어지면 키보드가 닫힌다.
    expect(find.byType(FigmaEyeIcon), findsOneWidget);
    expect(tester.state(find.byType(EditableText)), same(state));
    expect(_editable(tester).focusNode.hasFocus, isTrue);
  });

  testWidgets('호출부가 정한 힌트 자간은 그대로 둔다', (tester) async {
    await _pump(
      tester,
      const RoundedInputField(
        hintText: '이메일을 입력하세요.',
        hintStyle: kLoginHintStyle,
        height: AppLayout.onboardingControlHeight,
      ),
    );

    final hint = tester.widget<Text>(find.text('이메일을 입력하세요.'));
    expect(hint.style?.letterSpacing, kLoginHintStyle.letterSpacing);
  });

  testWidgets('라벨 글자 상자는 시안 h19이고 칸 자리는 라벨 top + 24 그대로다', (tester) async {
    await _pump(
      tester,
      const RoundedInputField(
        label: '닉네임',
        labelGap: 1,
        hintText: '닉네임을 입력하세요.',
        height: AppLayout.onboardingControlHeight,
      ),
    );

    // 회원가입 4534:1700은 라벨 y145·h19, 칸 4534:1701은 y169다. 라벨을
    // 기본 줄 높이(23)로 그리면 글자가 1.75px 아래로 내려갔다.
    final label = tester.getRect(find.text('닉네임'));
    expect(label.height, 19);
    expect(_fieldBox(tester).top - label.top, 24);
  });

  testWidgets('힌트는 입력 글자 baseline보다 2px 위에 그린다', (tester) async {
    Future<double> hintTop(double lift) async {
      await _pump(
        tester,
        RoundedInputField(
          hintText: '예: 베란다',
          hintLift: lift,
          height: AppLayout.onboardingControlHeight,
        ),
      );
      return tester.getRect(find.text('예: 베란다')).top - _fieldBox(tester).top;
    }

    // 12pt 힌트가 14pt 입력 글자와 같은 baseline에 앉아 시안(4534:1702 등)
    // 보다 2px 아래였다. 로그인처럼 0을 넘긴 칸만 원래 자리에 둔다.
    final lifted = await hintTop(2);
    final original = await hintTop(0);
    expect(original - lifted, 2);
  });
}
