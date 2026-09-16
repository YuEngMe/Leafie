import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/diagnosis_screen.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/services/diagnosis_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

void main() {
  _prescriptionActionTests();
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
  _FakeDiagnosisRepository({
    required this.records,
    this.status = 'COMPLETED',
    this.failureCode,
    this.retryError,
    this.cancelError,
  });

  final List<DiagnosisSummary> records;

  /// getDiagnosis가 돌려줄 상태. 재시도·취소 버튼 분기를 확인할 때 바꾼다.
  String status;
  String? failureCode;

  /// 서버가 409를 주는 상황을 흉내 낼 때 넣는다.
  final LeafieApiException? retryError;
  final LeafieApiException? cancelError;

  String? submittedPlantId;
  List<int>? submittedBytes;
  final List<String> retried = [];
  final List<String> cancelled = [];

  @override
  Future<DiagnosisDetailData> retryDiagnosis(String diagnosisId) async {
    retried.add(diagnosisId);
    final error = retryError;
    if (error != null) throw error;
    status = 'COMPLETED';
    failureCode = null;
    return getDiagnosis(diagnosisId);
  }

  @override
  Future<void> cancelDiagnosis(String diagnosisId) async {
    cancelled.add(diagnosisId);
    final error = cancelError;
    if (error != null) throw error;
    status = 'CANCELLED';
  }

  @override
  Future<DiagnosisDetailData> getDiagnosis(String diagnosisId) async {
    return DiagnosisDetailData(
      id: diagnosisId,
      plantId: 'plant-id',
      status: status,
      failureCode: failureCode,
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

/// 처방전 하단 버튼은 서버가 허용하는 동작만 띄운다
/// (backend/app/services/diagnosis.py:327-355).
void _prescriptionActionTests() {
  Future<_FakeDiagnosisRepository> pump(
    WidgetTester tester, {
    required String status,
    String? failureCode,
    LeafieApiException? retryError,
    LeafieApiException? cancelError,
  }) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeDiagnosisRepository(
      records: const [],
      status: status,
      failureCode: failureCode,
      retryError: retryError,
      cancelError: cancelError,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisDetailScreen(
          diagnosisId: 'diagnosis-id',
          repository: repository,
          imageProviderBuilder: (_) => MemoryImage(_greenPixelPng),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('재시도 가능한 실패는 같은 사진으로 다시 맡긴다', (tester) async {
    final repository = await pump(
      tester,
      status: 'FAILED',
      failureCode: 'DIAGNOSIS_PROVIDER_UNAVAILABLE',
    );

    expect(find.text('다시 시도하기'), findsOneWidget);
    await tester.tap(find.text('다시 시도하기'));
    await tester.pumpAndSettle();

    expect(repository.retried, ['diagnosis-id']);
    // 성공하면 화면을 다시 읽어 완료 상태가 된다.
    expect(find.text('다시 진단하기'), findsOneWidget);
  });

  testWidgets('재시도 불가한 실패는 새 사진을 받는다', (tester) async {
    final repository = await pump(
      tester,
      status: 'FAILED',
      // 사진 문제는 서버가 재시도를 거부한다.
      failureCode: 'DIAGNOSIS_NEW_PHOTO_REQUIRED',
    );

    expect(find.text('다시 진단하기'), findsOneWidget);
    expect(find.text('다시 시도하기'), findsNothing);
    expect(repository.retried, isEmpty);
  });

  testWidgets('대기 중인 진단은 취소할 수 있다', (tester) async {
    final repository = await pump(tester, status: 'PENDING');

    expect(find.text('진단 취소하기'), findsOneWidget);
    await tester.tap(find.text('진단 취소하기'));
    await tester.pumpAndSettle();

    expect(repository.cancelled, ['diagnosis-id']);
  });

  testWidgets('이미 시작된 진단은 취소가 거절된다', (tester) async {
    await pump(
      tester,
      status: 'PENDING',
      cancelError: const LeafieApiException(
        code: 'DIAGNOSIS_NOT_CANCELLABLE',
        message: '대기 중인 진단만 취소할 수 있습니다.',
        statusCode: 409,
      ),
    );

    await tester.tap(find.text('진단 취소하기'));
    await tester.pumpAndSettle();

    expect(find.text('대기 중인 진단만 취소할 수 있습니다.'), findsOneWidget);
  });

  testWidgets('서버가 거절하면 그 문구를 보여 준다', (tester) async {
    await pump(
      tester,
      status: 'FAILED',
      failureCode: 'STORAGE_UNAVAILABLE',
      retryError: const LeafieApiException(
        code: 'DIAGNOSIS_NOT_RETRYABLE',
        message: '다시 시도할 수 없는 진단입니다.',
        statusCode: 409,
      ),
    );

    await tester.tap(find.text('다시 시도하기'));
    await tester.pumpAndSettle();

    expect(find.text('다시 시도할 수 없는 진단입니다.'), findsOneWidget);
  });
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
