import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/diagnosis_components.dart';
import 'package:yeso_plant/widgets/home_components.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';

void main() {
  testWidgets('홈 말풍선과 환경 게이지 402x260 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(402, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: const Scaffold(
          backgroundColor: Color(0xFFEBEBEB),
          body: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlantRequestBubble(message: '나 지금 목말라.. 물이 필요해'),
                SizedBox(height: 16),
                EnvironmentGauge(
                  kind: EnvironmentGaugeKind.humidity,
                  description: '새싹이는 40 - 70% 습도를 좋아해요',
                  currentRatio: 0.43,
                  comfortRatio: 0.7,
                  currentLabel: '현재습도 43%',
                  maxLabel: '65%',
                ),
                EnvironmentGauge(
                  kind: EnvironmentGaugeKind.light,
                  description: '새싹이는 40 - 80% 조도를 좋아해요',
                  currentRatio: 0.18,
                  comfortRatio: 0.84,
                  currentLabel: '현재조도 10%',
                  maxLabel: '80%',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/home_components_402.png'),
    );
  });

  testWidgets('진단 기록 행과 빈 상태 402x200 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(402, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: Scaffold(
          backgroundColor: const Color(0xFFEBEBEB),
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                DiagnosisRecordTile(
                  thumbnail: MemoryImage(_greenPixelPng),
                  title: '새싹이 진단 기록',
                  dateLabel: '2026. 3. 7 수',
                  onTap: () {},
                ),
                const SizedBox(height: 24),
                const DiagnosisEmptyState(),
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/diagnosis_list_402.png'),
    );
  });

  testWidgets('처방전 카드 379x643 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(379, 643);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: kFontFamily),
        home: Scaffold(
          backgroundColor: const Color(0xFFEBEBEB),
          body: PrescriptionCard(
            photo: MemoryImage(_greenPixelPng),
            statusLabel: '조금 관리가 필요해요',
            patientRows: const [
              ('환자성명', '새싹이'),
              ('식물명', '해바라기'),
              ('생년월일', '2002. 04. 05'),
              ('진단일', '2026. 07. 08'),
            ],
            symptoms: const ['잎 처짐', '잎 처짐', '잎 처짐'],
            causes: const [
              PrescriptionCause(
                label: '과습',
                percent: 76,
                color: kCauseOverwater,
              ),
              PrescriptionCause(
                label: '햇빛 부족',
                percent: 38,
                color: kCauseLowLight,
              ),
              PrescriptionCause(label: '병충해', percent: 64, color: kCausePest),
            ],
            recommendations: const [
              '물을 충분히 주세요.',
              '밝은 곳으로 옮겨주세요.',
              '3일 후 다시 진단해 주세요.',
            ],
            onClose: () {},
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(PrescriptionCard),
      matchesGoldenFile('goldens/prescription_card_379.png'),
    );
  });

  testWidgets('캐릭터 삭제 모달 348x199 스냅샷', (tester) async {
    tester.view.physicalSize = const Size(348, 199);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFFEBEBEB),
          body: Center(
            child: CharacterDeleteDialog(tenureLabel: '함께한지 130일이에요'),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(CharacterDeleteDialog),
      matchesGoldenFile('goldens/character_delete_dialog_348.png'),
    );
  });
}

/// 골든에서 사진 자리를 채우는 1x1 초록 PNG.
final _greenPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
