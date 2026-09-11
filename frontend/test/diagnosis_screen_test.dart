import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/diagnosis_screen.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/services/diagnosis_api.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

void main() {
  setUp(() {});

  testWidgets('빈 진단 화면과 사진 확인에서 공통 뒤로가기로 빠져나온다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeDiagnosisRepository(records: const []);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DiagnosisScreen(
                      plantId: 'plant-id',
                      repository: repository,
                      photoPicker: () async => DiagnosisPhoto(_greenPixelPng),
                    ),
                  ),
                ),
                child: const Text('진단 열기'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('진단 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(FigmaBackChevron), findsOneWidget);
    await tester.tap(find.text('진단하기'));
    await tester.pumpAndSettle();
    expect(find.byType(DiagnosisPhotoConfirmScreen), findsOneWidget);
    await tester.tap(find.byType(FigmaBackChevron));
    await tester.pumpAndSettle();
    expect(find.byType(DiagnosisPhotoConfirmScreen), findsNothing);
    expect(find.text('진단 기록이 없습니다'), findsOneWidget);
    expect(repository.submittedPlantId, isNull);
    await tester.tap(find.byType(FigmaBackChevron));
    await tester.pumpAndSettle();
    expect(find.text('진단 열기'), findsOneWidget);
    expect(find.byType(DiagnosisScreen), findsNothing);
  });

  testWidgets('기록이 없으면 Figma 빈 상태와 진단 버튼을 보여준다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeDiagnosisRepository(records: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisScreen(
          plantId: 'plant-id',
          plantName: '새싹이',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('진단 기록이 없습니다'), findsOneWidget);
    expect(find.text('내 식물의 건강을 진단해주세요.'), findsOneWidget);
    expect(find.text('진단하기'), findsOneWidget);
    expect(find.text('진단기록'), findsNothing);
  });

  testWidgets('오늘과 지난 진단을 나누고 상세 처방전으로 이동한다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeDiagnosisRepository(
      records: [
        _summary('today', DateTime(2026, 9, 6, 10)),
        _summary('past', DateTime(2026, 9, 5, 10)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisScreen(
          plantId: 'plant-id',
          plantName: '새싹이',
          repository: repository,
          now: () => DateTime(2026, 9, 6, 12),
          imageProviderBuilder: (_) => MemoryImage(_greenPixelPng),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오늘의 진단'), findsOneWidget);
    expect(find.text('지난 진단'), findsOneWidget);
    expect(find.text('새싹이 진단 기록'), findsNWidgets(2));
    expect(find.text('2026. 9. 6 일'), findsOneWidget);
    expect(find.text('2026. 9. 5 토'), findsOneWidget);

    await tester.tap(find.text('새싹이 진단 기록').first);
    await tester.pumpAndSettle();

    expect(find.text('진단하기'), findsOneWidget);
    expect(find.text('처방전'), findsOneWidget);
    expect(find.text('조금 관리가 필요해요'), findsOneWidget);
    expect(find.text('해바라기'), findsOneWidget);
    expect(find.text('다시 진단하기'), findsOneWidget);
  });

  testWidgets('홈 우측 진단 아이콘이 진단 기록 화면을 연다', (tester) async {
    _setIPhone16ProViewport(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          plant: HomePlant(
            id: 'plant-id',
            name: '새싹이',
            startedOn: null,
            personalityType: null,
          ),
          period: HomeTimePeriod.day,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-diagnosis-switch')));
    await tester.pumpAndSettle();

    expect(find.text('진단기록'), findsOneWidget);
  });

  testWidgets('진행 중인 기록은 빈 처방전 대신 상태를 알린다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeDiagnosisRepository(
      records: [
        DiagnosisSummary(
          id: 'processing',
          status: 'PROCESSING',
          diagnosedAt: DateTime(2026, 9, 6, 10),
          photoUrl: 'https://example.com/processing.jpg',
          conditionLabel: null,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisScreen(
          plantId: 'plant-id',
          plantName: '새싹이',
          repository: repository,
          now: () => DateTime(2026, 9, 6, 12),
          imageProviderBuilder: (_) => MemoryImage(_greenPixelPng),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('새싹이 진단 기록'));
    await tester.pump();

    expect(find.text('진단이 진행 중이에요.'), findsOneWidget);
    expect(find.text('처방전'), findsNothing);
  });

  testWidgets('진단하기는 촬영 사진 확인 후 실제 진단 요청으로 이어진다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeDiagnosisRepository(records: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisScreen(
          plantId: 'plant-id',
          plantName: '새싹이',
          repository: repository,
          photoPicker: () async => DiagnosisPhoto(_greenPixelPng),
          imageProviderBuilder: (_) => MemoryImage(_greenPixelPng),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('진단하기'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('diagnosis-confirm-photo')),
      findsOneWidget,
    );
    expect(find.text('다시 촬영'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('diagnosis-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.submittedPlantId, 'plant-id');
    expect(repository.submittedBytes, _greenPixelPng);
    expect(find.text('처방전'), findsOneWidget);
  });

  testWidgets('재진단 결과를 닫으면 이전 처방전이 아니라 기록으로 돌아간다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeDiagnosisRepository(
      records: [_summary('old-diagnosis', DateTime(2026, 9, 6, 10))],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisScreen(
          plantId: 'plant-id',
          plantName: '새싹이',
          repository: repository,
          now: () => DateTime(2026, 9, 6, 12),
          photoPicker: () async => DiagnosisPhoto(_greenPixelPng),
          imageProviderBuilder: (_) => MemoryImage(_greenPixelPng),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('새싹이 진단 기록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 진단하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diagnosis-submit-button')));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.text('처방전'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('진단기록'), findsOneWidget);
    expect(find.text('처방전'), findsNothing);
  });
}

DiagnosisSummary _summary(String id, DateTime diagnosedAt) => DiagnosisSummary(
  id: id,
  status: 'COMPLETED',
  diagnosedAt: diagnosedAt,
  photoUrl: 'https://example.com/$id.jpg',
  conditionLabel: '조금 관리가 필요해요',
);

class _FakeDiagnosisRepository implements DiagnosisRepository {
  _FakeDiagnosisRepository({required this.records});

  final List<DiagnosisSummary> records;
  String? submittedPlantId;
  List<int>? submittedBytes;

  @override
  Future<DiagnosisDetailData> getDiagnosis(String diagnosisId) async {
    return DiagnosisDetailData(
      id: diagnosisId,
      plantId: 'plant-id',
      status: 'COMPLETED',
      diagnosedAt: DateTime(2026, 9, 6),
      photoUrl: 'https://example.com/$diagnosisId.jpg',
      conditionLabel: '조금 관리가 필요해요',
      observations: const ['잎 처짐'],
      possibleCauses: const [DiagnosisCauseData(name: '과습', confidence: 0.76)],
      recommendedCare: const ['물을 줄여주세요.'],
    );
  }

  @override
  Future<DiagnosisPlantData> getPlant(String plantId) async {
    return DiagnosisPlantData(
      id: plantId,
      nickname: '새싹이',
      speciesDisplayName: '해바라기',
      startedOn: DateTime(2026, 3, 1),
    );
  }

  @override
  Future<List<DiagnosisSummary>> listDiagnoses(String plantId) async => records;

  @override
  Future<DiagnosisDetailData> submitDiagnosis({
    required String plantId,
    required List<int> photoBytes,
  }) async {
    submittedPlantId = plantId;
    submittedBytes = photoBytes;
    return getDiagnosis('submitted-diagnosis');
  }
}

void _setIPhone16ProViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final _greenPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
