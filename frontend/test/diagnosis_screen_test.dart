import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/screens/diagnosis_screen.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/services/diagnosis_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

import 'support/device_view.dart';

void main() {
  _prescriptionActionTests();
  setUp(() {});

  testWidgets('빈 진단 화면은 뒤로가기로 빠져나오고, 사진 확인은 다시 촬영으로 사진을 다시 받는다', (tester) async {
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
    // 빈 진단 화면은 공통 뒤로가기로 빠져나온다.
    expect(find.byType(FigmaBackChevron), findsOneWidget);
    await tester.tap(find.text('진단하기'));
    await tester.pumpAndSettle();
    expect(find.byType(DiagnosisPhotoConfirmScreen), findsOneWidget);
    // 사진 확인 화면엔 시안대로 상단 뒤로가 없다. '다시 촬영'은 사진을 다시 받는다.
    expect(find.byType(FigmaBackChevron), findsNothing);
    await tester.tap(find.text('다시 촬영'));
    await tester.pumpAndSettle();
    expect(find.byType(DiagnosisPhotoConfirmScreen), findsOneWidget);
    expect(repository.submittedPlantId, isNull);
  });

  testWidgets('사진 확인 하단 글자는 시안(4534:20043) 자리에 잘리지 않고 앉는다', (tester) async {
    useDeviceView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisPhotoConfirmScreen(
          plantId: 'plant-id',
          photo: DiagnosisPhoto(_greenPixelPng),
          repository: _FakeDiagnosisRepository(records: const []),
          photoPicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 디자이너 수정(메모 6049:2755 "아래 검은바 좀 올리고 / 글자 안으로
    // 땡김"): 막대 4534:20064가 y 801·높이 73으로 14 올라갔고, 글자
    // 4534:20066/20067은 10씩 안쪽·12 위(중심 y 831.57)로 옮겨졌다.
    final bar = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is ColoredBox && w.color == Colors.black.withValues(alpha: 0.6),
      ),
    );
    expect(bar.top, closeTo(801, 1));
    expect(bar.bottom, closeTo(874, 1));
    final retake = tester.getRect(find.text('다시 촬영'));
    final submit = tester.getRect(find.text('다음'));
    expect(retake.center.dy, closeTo(831.57, 2));
    expect(submit.center.dy, closeTo(831.57, 2));
    expect(retake.left, closeTo(40, 1));
    expect(submit.right, closeTo(361.04, 1));
    // 예전엔 안전 영역을 뺀 25 안에 버튼을 넣어 글자 칸이 9로 잘렸다.
    for (final key in ['diagnosis-retake-button', 'diagnosis-submit-button']) {
      expect(tester.getSize(find.byKey(ValueKey(key))).height, 44);
    }
    // 시안은 사진이 맨 위까지 보인다(어두운 앱바 띠 없음).
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      Colors.transparent,
    );
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

  testWidgets('빈 상태 문구와 버튼은 실제 본문 높이에서 시안(4534:19683) 자리에 앉는다', (tester) async {
    useDeviceView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisScreen(
          plantId: 'plant-id',
          repository: _FakeDiagnosisRepository(records: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 예전엔 기준 높이 795를 본문 748에 눌러 담아 버튼이 48로 줄고
    // 문구가 5~9px 위로 올라갔다. 버튼은 y790·높이 51.
    final button = tester.getRect(
      find
          .ancestor(of: find.text('진단하기'), matching: find.byType(SizedBox))
          .first,
    );
    expect(button.top, closeTo(790, 0.5));
    expect(button.height, closeTo(51, 0.5));
    // 글자 상자 top. 보이는 글자 윗변은 제목 390·부제 423(시안)이다.
    expect(tester.getRect(find.text('진단 기록이 없습니다')).top, closeTo(389, 0.5));
    expect(
      tester.getRect(find.text('내 식물의 건강을 진단해주세요.')).top,
      closeTo(423, 0.5),
    );
  });

  testWidgets('기록 행 꺾쇠와 절 제목은 시안(4534:19827) 값이다', (tester) async {
    useDeviceView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisScreen(
          plantId: 'plant-id',
          plantName: '새싹이',
          repository: _FakeDiagnosisRepository(
            records: [_summary('today', DateTime(2026, 9, 6, 10))],
          ),
          now: () => DateTime(2026, 9, 6, 12),
          imageProviderBuilder: (_) => MemoryImage(_greenPixelPng),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 4534:19852 꺾쇠 x361 y191 8.29×13(행 오른쪽 끝에서 18.7 안쪽).
    final chevron = tester.getRect(
      find.ancestor(
        of: _svgAsset('assets/images/diagnosis_record_chevron.svg'),
        matching: find.byType(RotatedBox),
      ),
    );
    expect(chevron.left, closeTo(361, 0.5));
    expect(chevron.width, closeTo(8.29, 0.1));
    expect(chevron.center.dy, closeTo(191 + 13.004 / 2, 1));
    // 4534:19874 절 제목은 SemiBold 16.
    expect(
      tester.widget<Text>(find.text('오늘의 진단')).style?.fontWeight,
      FontWeight.w600,
    );
  });

  testWidgets('처방전 닫기 X는 시안(4534:19740) 중심에 앉는다', (tester) async {
    useDeviceView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisDetailScreen(
          diagnosisId: 'diagnosis-id',
          repository: _FakeDiagnosisRepository(records: const []),
          imageProviderBuilder: (_) => MemoryImage(_greenPixelPng),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 예전 Icons.close는 중심이 9px 왼쪽이었다.
    final close = tester.getRect(
      _svgAsset('assets/images/diagnosis_prescription_close.svg'),
    );
    expect(close.center.dx, closeTo(362.3, 0.5));
    expect(close.center.dy, closeTo(171.7, 0.5));
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
    // 추천관리는 시안처럼 첫 문장만 짧게 보여 준다.
    expect(find.text('물을 줄여주세요.'), findsOneWidget);
    expect(find.textContaining('흙이 마른 뒤에'), findsNothing);
    // 증상은 원인에서 짐작한 짧은 말이다. 짐작 못 한 원인은 건너뛴다.
    expect(find.text('잎 처짐'), findsOneWidget);
    expect(find.text('잎 변색'), findsOneWidget);
    expect(find.text('03.'), findsNothing);
    expect(find.text('건강 이상 가능성'), findsNothing);
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

  testWidgets('다시 찍어야 하는 기록은 서버가 거절한 이유를 알린다', (tester) async {
    _setIPhone16ProViewport(tester);
    final repository = _FakeDiagnosisRepository(
      records: [
        DiagnosisSummary(
          id: 'retake',
          status: 'NEEDS_RETAKE',
          diagnosedAt: DateTime(2026, 9, 6, 10),
          photoUrl: 'https://example.com/retake.jpg',
          conditionLabel: null,
          retakeReasonCode: 'PLANT_NOT_VISIBLE',
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

    expect(
      find.text('사진에서 식물을 찾지 못했어요. 식물이 잘 보이게 다시 찍어 주세요.'),
      findsOneWidget,
    );
    expect(find.text('처방전'), findsNothing);
  });

  test('재촬영 사유마다 고칠 점을 알려 주고, 모르는 사유는 기본 문구다', () {
    const codes = [
      'PLANT_NOT_VISIBLE',
      'IMAGE_TOO_DARK',
      'IMAGE_TOO_BRIGHT',
      'IMAGE_BLURRY',
      'IMAGE_TOO_SMALL',
      'IMAGE_TYPE_UNSUPPORTED',
      'IMAGE_INVALID',
    ];
    final messages = codes.map(retakeReasonMessage).toSet();
    expect(messages, hasLength(codes.length));
    expect(messages, isNot(contains('사진을 다시 촬영해주세요.')));
    expect(retakeReasonMessage(null), '사진을 다시 촬영해주세요.');
    expect(retakeReasonMessage('NEW_CODE'), '사진을 다시 촬영해주세요.');
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
      observations: const ['건강 이상 가능성'],
      possibleCauses: const [
        DiagnosisCauseData(name: '과습', confidence: 0.76),
        DiagnosisCauseData(name: '영양 결핍', confidence: 0.4),
        DiagnosisCauseData(name: '알 수 없는 원인', confidence: 0.2),
      ],
      // 실제 서버처럼 여러 문장이 이어진 관리법.
      recommendedCare: const ['물을 줄여주세요. 흙이 마른 뒤에 주는 것이 좋습니다.'],
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

Finder _svgAsset(String asset) => find.byWidgetPredicate(
  (widget) =>
      widget is SvgPicture &&
      widget.bytesLoader is SvgAssetLoader &&
      (widget.bytesLoader as SvgAssetLoader).assetName == asset,
);

void _setIPhone16ProViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final _greenPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
