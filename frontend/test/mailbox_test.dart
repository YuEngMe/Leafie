import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_letter.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/mailbox_screen.dart';

PlantLetter letter({
  bool read = false,
  String id = 'one',
  String body = '나에게 물을 줘서 고마워!\n덕분에 정말 상쾌한 아침이야~',
  String preview = '물을 줘서 고마워!',
  bool contentLoaded = false,
}) => PlantLetter(
  id: id,
  plantId: 'plant',
  recipient: '테스트 사용자',
  sender: '테스트 식물',
  body: body,
  preview: preview,
  createdAt: DateTime(2026, 9, 10),
  isRead: read,
  contentLoaded: contentLoaded,
);

Duration openingAt(double progress) => Duration(
  microseconds: (LetterOpening.duration.inMicroseconds * progress).round(),
);

Offset horizontalAxis(WidgetTester tester) {
  final paper = tester.renderObject<RenderBox>(
    find.byKey(const ValueKey('opening-paper')),
  );
  return paper.localToGlobal(Offset(paper.size.width, 0)) -
      paper.localToGlobal(Offset.zero);
}

void expectSingleUnclippedLine(
  WidgetTester tester,
  Finder finder,
  String text,
) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  expect(boxes, isNotEmpty);
  expect(boxes.map((box) => box.top.round()).toSet(), hasLength(1));
  expect(boxes.last.right, lessThanOrEqualTo(paragraph.size.width + .01));
}

Future<void> expectMailboxGolden(WidgetTester tester, String path) async {
  debugDisableShadows = false;
  try {
    void markSubtreeNeedsPaint(RenderObject renderObject) {
      renderObject.markNeedsPaint();
      renderObject.visitChildren(markSubtreeNeedsPaint);
    }

    for (final renderView in tester.binding.renderViews) {
      markSubtreeNeedsPaint(renderView);
    }
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(path));
  } finally {
    debugDisableShadows = true;
  }
}

class Repository implements PlantLetterRepository {
  Repository(this.letters);
  final List<PlantLetter> letters;
  bool failList = false;
  bool failRead = false;
  bool failDetail = false;
  bool failDelete = false;
  final reads = <String>[];
  final details = <String>[];
  final deletes = <String>[];
  final pendingReads = <String, Future<void>>{};
  final pendingDetails = <String, Future<void>>{};
  final pendingDeletes = <String, Future<void>>{};
  @override
  Future<List<PlantLetter>> listLetters(String plantId) async {
    if (failList) throw StateError('offline');
    return List.unmodifiable(letters);
  }

  @override
  Future<PlantLetter> getLetter(String plantId, String letterId) async {
    details.add(letterId);
    await pendingDetails[letterId];
    if (failDetail) throw StateError('offline');
    final summary = letters.singleWhere((letter) => letter.id == letterId);
    return PlantLetter(
      id: summary.id,
      plantId: plantId,
      recipient: summary.recipient,
      sender: summary.sender,
      body: summary.body,
      preview: summary.preview,
      createdAt: summary.createdAt,
      isRead: summary.isRead,
      contentLoaded: true,
    );
  }

  @override
  Future<void> markRead(String plantId, String letterId) async {
    await pendingReads[letterId];
    if (failRead) throw StateError('offline');
    reads.add(letterId);
  }

  @override
  Future<void> deleteLetter(String plantId, String letterId) async {
    deletes.add(letterId);
    await pendingDeletes[letterId];
    if (failDelete) throw StateError('offline');
  }
}

Future<void> launch(
  WidgetTester tester,
  Repository? repository, {
  bool reduced = false,
  bool settleMailbox = true,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: HomeScreen(
        period: HomeTimePeriod.day,
        letterRepository: repository,
        plant: const HomePlant(
          id: 'plant',
          name: '테스트 식물',
          startedOn: null,
          personalityType: null,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final context = tester.element(find.byType(HomeScreen));
    for (final asset in [
      'home_bg_default',
      // 홈 캐릭터: 옐로 circle 몸통 + 기본 얼굴.
      'character/body_circle_yellow',
      'character/face_circle_default',
      'mailbox_house_v2',
      'mailbox_foreground',
      'mail_paper_texture',
      'mail_envelope',
      'mail_flap',
      'mail_inner',
      'mail_front',
      'mail_bottom',
    ]) {
      await precacheImage(AssetImage('assets/images/$asset.png'), context);
    }
  });
  await tester.tap(find.byKey(const ValueKey('home-mailbox')));
  if (settleMailbox) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump();
  }
  expect(finder, findsWidgets);
}

Future<void> openMotionPreview(
  WidgetTester tester,
  Repository repository,
) async {
  final context = tester.element(find.byType(MailboxScreen));
  unawaited(
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, animation, secondaryAnimation) => MailboxScreen(
        plantId: 'plant',
        repository: repository,
        debugPreview: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('미연동 앱에서도 미리보기 재생과 반복 후 원래 화면으로 돌아온다', (tester) async {
    final repository = Repository([]);
    await launch(tester, repository);
    expect(find.byKey(const ValueKey('mail-motion-preview')), findsNothing);
    expect(find.text('편지 모션 미리보기'), findsNothing);
    await openMotionPreview(tester, repository);
    expect(find.text('개발용 미리보기 · 서버 저장 없음'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
    await tester.pump();
    expect(find.byKey(const ValueKey('travelling-envelope')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('TO. 미리보기 사용자'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mail-preview-replay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-new-letter')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('mail-preview-exit')));
    await tester.pumpAndSettle();
    expect(find.text('아직 도착한 편지가 없어요.'), findsOneWidget);
    expect(find.text('TO. 미리보기 사용자'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('미리보기는 실제 저장소 읽음 상태를 변경하지 않는다', (tester) async {
    final repository = Repository([letter(read: true)]);
    await launch(tester, repository);
    await openMotionPreview(tester, repository);
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
    await tester.pumpAndSettle();
    expect(repository.reads, isEmpty);
    await tester.tap(find.byKey(const ValueKey('mail-preview-exit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-list')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mail-one')));
    await tester.pumpAndSettle();
    expect(find.text('TO. 테스트 사용자'), findsOneWidget);
    expect(repository.reads, isEmpty);
  });

  testWidgets('느린 읽음 저장은 다른 편지 읽음 처리나 오류 상태를 덮어쓰지 않는다', (tester) async {
    final a = Completer<void>();
    final b = Completer<void>();
    final repository = Repository([letter(), letter(id: 'two')]);
    repository.pendingReads.addAll({'one': a.future, 'two': b.future});
    await launch(tester, repository);
    expect(find.byKey(const ValueKey('opened-letter')), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mail-two')));
    await tester.pumpAndSettle();
    b.complete();
    await tester.pumpAndSettle();
    expect(repository.reads, ['two']);
    a.completeError(StateError('first failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('읽음 상태를 저장하지 못했어요.'), findsNothing);
  });
  testWidgets('새 편지가 있으면 자동으로 세 단계 모션을 재생하고 마지막에 읽음 처리', (tester) async {
    final repository = Repository([letter()]);
    await launch(tester, repository, settleMailbox: false);
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('travelling-envelope')),
    );
    expect(find.byKey(const ValueKey('mail-new-letter')), findsNothing);
    expect(find.byKey(const ValueKey('mail-list')), findsNothing);
    expect(repository.details, ['one']);
    expect(repository.reads, isEmpty);
    final start = tester.getRect(
      find.byKey(const ValueKey('travelling-envelope')),
    );
    expect(start.left, closeTo(140, .1));
    expect(start.top, closeTo(312, .1));
    await tester.pump(LetterOpening.pressDuration + LetterOpening.liftDuration);
    final lifted = tester.getRect(
      find.byKey(const ValueKey('travelling-envelope')),
    );
    expect(lifted.center.dy, lessThan(start.center.dy));
    expect(repository.reads, isEmpty);
    await expectMailboxGolden(tester, 'goldens/mail_pull_402.png');
    await tester.pump(LetterOpening.travelDuration);
    expect(
      tester.getRect(find.byKey(const ValueKey('travelling-envelope'))).left,
      closeTo(53, .1),
    );
    await expectMailboxGolden(tester, 'goldens/mail_closed_402.png');
    await tester.pump(openingAt(.45));
    expect(repository.reads, isEmpty);
    await expectMailboxGolden(tester, 'goldens/mail_opening_402.png');
    await tester.pump(openingAt(.55) - const Duration(milliseconds: 1));
    expect(repository.reads, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(repository.reads, ['one']);
    expect(find.text('TO. 테스트 사용자'), findsOneWidget);
    await expectMailboxGolden(tester, 'goldens/mail_opened_402.png');
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-list')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mail-one')));
    await tester.pumpAndSettle();
    expect(repository.reads, ['one']);
  });

  testWidgets('새 편지가 없으면 목록으로 바로 이동하고 기존 편지도 열 수 있다', (tester) async {
    final repository = Repository([letter(read: true)]);
    await launch(tester, repository);
    expect(find.text('NEW!'), findsNothing);
    expect(find.byKey(const ValueKey('mail-list')), findsOneWidget);
    expectSingleUnclippedLine(
      tester,
      find.byKey(const ValueKey('mail-list-title-text')),
      '우편함',
    );
    expectSingleUnclippedLine(
      tester,
      find.byKey(const ValueKey('mail-date-one')),
      '2026. 9. 10 목',
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('mail-list-title-text'))).width,
      lessThanOrEqualTo(66),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('mail-date-one'))).width,
      lessThanOrEqualTo(90.147),
    );
    await expectMailboxGolden(tester, 'goldens/mail_list_402.png');
    await tester.tap(find.byKey(const ValueKey('mail-one')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('opened-letter')), findsOneWidget);
    expect(repository.reads, isEmpty);
  });

  testWidgets('여러 행 목록은 피치와 부드러운 그림자를 유지한다', (tester) async {
    final repository = Repository([
      letter(read: true, id: 'one', preview: '첫 번째 편지예요.'),
      letter(read: true, id: 'two', preview: '두 번째 편지예요.'),
      letter(read: true, id: 'three', preview: '세 번째 편지예요.'),
    ]);
    await launch(tester, repository);
    final first = tester.getRect(find.byKey(const ValueKey('mail-one')));
    final second = tester.getRect(find.byKey(const ValueKey('mail-two')));
    expect(first.left, closeTo(43, .01));
    expect(first.top, closeTo(330.786, .01));
    expect(second.top - first.top, closeTo(69.8994, .01));
    await expectMailboxGolden(tester, 'goldens/mail_list_three_402.png');
  });

  testWidgets('선택 식물이 없으면 식물 등록 행동을 안내한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MailboxScreen(plantId: null, repository: Repository([])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('먼저 식물을 등록해 주세요.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '식물 등록하기'), findsOneWidget);
    expect(find.text('편지 서비스 연결을 준비 중이에요.'), findsNothing);
  });

  testWidgets('빈 우편함은 예시 편지를 만들지 않는다', (tester) async {
    await launch(tester, Repository([]));
    expect(find.text('아직 도착한 편지가 없어요.'), findsOneWidget);
    expect(find.text('NEW!'), findsNothing);
    await tester.tap(find.byTooltip('닫기').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-house-envelope')), findsOneWidget);
    await expectMailboxGolden(tester, 'goldens/mail_house_402.png');
    await tester.tap(find.byKey(const ValueKey('mail-house-envelope')));
    await tester.pumpAndSettle();
    expect(find.text('아직 도착한 편지가 없어요.'), findsOneWidget);
  });

  testWidgets('조회 실패 재시도와 읽음 저장 실패 재시도', (tester) async {
    final repository = Repository([letter()])..failList = true;
    await launch(tester, repository);
    expect(find.text('편지를 불러오지 못했어요.'), findsOneWidget);
    repository.failList = false;
    repository.failRead = true;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.textContaining('읽음 상태를 저장하지 못했어요.'), findsOneWidget);
    repository.failRead = false;
    await tester.tap(find.textContaining('읽음 상태를 저장하지 못했어요.'));
    await tester.pumpAndSettle();
    expect(repository.reads, ['one']);
  });

  testWidgets('상세 내용을 받기 전에는 미리보기를 편지 본문으로 보이지 않는다', (tester) async {
    final pending = Completer<void>();
    const longBody = '상세 API에서만 오는 긴 본문입니다.\n이 내용은 요약 목록에 등장하면 안 됩니다.';
    final repository = Repository([letter(body: longBody)])
      ..pendingDetails['one'] = pending.future;
    await launch(tester, repository, settleMailbox: false);
    await pumpUntilFound(tester, find.text('편지를 펼치고 있어요.'));
    expect(find.text(longBody), findsNothing);
    expect(find.text('편지를 펼치고 있어요.'), findsOneWidget);
    expect(repository.reads, isEmpty);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text(longBody), findsOneWidget);
    expect(repository.details, ['one']);
    expect(repository.reads, ['one']);
  });

  testWidgets('상세 요청 취소와 실패 재시도가 오래된 응답을 열지 않는다', (tester) async {
    final pending = Completer<void>();
    final repository = Repository([letter()])
      ..pendingDetails['one'] = pending.future;
    await launch(tester, repository, settleMailbox: false);
    await pumpUntilFound(tester, find.text('편지를 펼치고 있어요.'));
    await tester.tap(find.text('취소'));
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('letter-opening')), findsNothing);
    expect(repository.reads, isEmpty);

    repository.pendingDetails.clear();
    repository.failDetail = true;
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
    await tester.pumpAndSettle();
    expect(find.text('편지 내용을 불러오지 못했어요.'), findsOneWidget);
    repository.failDetail = false;
    await tester.tap(find.byKey(const ValueKey('mail-detail-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('opened-letter')), findsOneWidget);
    expect(repository.details, ['one', 'one', 'one']);
  });

  testWidgets('스와이프 삭제는 확인 후 서버 성공에서만 행을 제거한다', (tester) async {
    final pending = Completer<void>();
    final repository = Repository([letter(read: true)])
      ..pendingDeletes['one'] = pending.future;
    await launch(tester, repository);
    await tester.timedDrag(
      find.byKey(const ValueKey('mail-one')),
      const Offset(-180, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-delete-one')), findsOneWidget);
    final revealedRow = tester.getRect(find.byKey(const ValueKey('mail-one')));
    final trash = tester.getRect(find.byKey(const ValueKey('mail-delete-one')));
    expect(revealedRow.left, closeTo(49, .01));
    expect(revealedRow.width, closeTo(248, .01));
    expect(trash.left, closeTo(309, .01));
    expect(trash.top, closeTo(333.286, .01));
    expect(trash.size, const Size.square(46));
    expect(repository.deletes, isEmpty);
    await expectMailboxGolden(tester, 'goldens/mail_delete_revealed_402.png');
    await tester.tap(find.byKey(const ValueKey('mail-delete-one')));
    await tester.pumpAndSettle();
    final confirmation = tester.getRect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.width == 308 &&
              widget.height == 158.829,
        ),
      ),
    );
    expect(confirmation.left, closeTo(47, .01));
    expect(confirmation.top, closeTo(357.5855, .01));
    expect(confirmation.width, closeTo(308, .01));
    expect(confirmation.height, closeTo(158.829, .01));
    await expectMailboxGolden(tester, 'goldens/mail_delete_confirm_402.png');
    await tester.tap(find.text('아니오'));
    await tester.pumpAndSettle();
    expect(repository.deletes, isEmpty);
    expect(find.byKey(const ValueKey('mail-one')), findsOneWidget);

    await tester.longPress(find.byKey(const ValueKey('mail-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mail-delete-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('네'));
    await tester.pump();
    expect(repository.deletes, ['one']);
    expect(find.byKey(const ValueKey('mail-one')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mail-delete-one')));
    await tester.pump();
    expect(repository.deletes, ['one']);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-one')), findsNothing);
    expect(find.text('아직 도착한 편지가 없어요.'), findsOneWidget);
  });

  testWidgets('삭제 실패는 행을 유지하고 명시적 재시도를 제공한다', (tester) async {
    final repository = Repository([letter(read: true)])..failDelete = true;
    await launch(tester, repository);
    await tester.longPress(find.byKey(const ValueKey('mail-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mail-delete-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('네'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-one')), findsOneWidget);
    expect(find.text('삭제하지 못했어요. 다시 시도'), findsOneWidget);
    repository.failDelete = false;
    await tester.tap(find.byKey(const ValueKey('mail-delete-retry-one')));
    await tester.pumpAndSettle();
    expect(repository.deletes, ['one', 'one']);
    expect(find.byKey(const ValueKey('mail-one')), findsNothing);
  });

  testWidgets('동작 줄이기에서는 바로 편지를 표시한다', (tester) async {
    final repository = Repository([letter()]);
    await launch(tester, repository, reduced: true);
    expect(find.byKey(const ValueKey('opened-letter')), findsOneWidget);
    expect(repository.reads, ['one']);
  });

  testWidgets('모션 도중 닫으면 읽음 처리하지 않는다', (tester) async {
    final repository = Repository([letter()]);
    await launch(tester, repository, settleMailbox: false);
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('travelling-envelope')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(repository.reads, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('스크롤한 목록의 선택 행에서 꺼내오며 화면 배율을 반영한다', (tester) async {
    final repository = Repository(
      List.generate(10, (i) => letter(read: true, id: '$i')),
    );
    await launch(tester, repository);
    tester.view.physicalSize = const Size(804, 1748);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mail-7')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    final row = tester.getRect(find.byKey(const ValueKey('mail-7')));
    await tester.tap(find.byKey(const ValueKey('mail-7')));
    await tester.pump();
    final envelope = tester.getRect(
      find.byKey(const ValueKey('travelling-envelope')),
    );
    expect(envelope.center.dx, closeTo(row.center.dx, .1));
    expect(envelope.center.dy, closeTo(row.center.dy, .1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('opened-letter')), findsOneWidget);
    expect(repository.reads, isEmpty);
  });

  testWidgets('편지는 봉투 안에서 수직 추출된 뒤 끊김 없이 정면으로 다가온다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LetterOpening(letter: letter(), onOpened: () => opened++),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump(openingAt(LetterOpening.extractionStart));
    final early = tester.getRect(find.byKey(const ValueKey('opening-paper')));
    expect(early, LetterOpening.initialPaperRect);
    final envelopeBottom = tester.getRect(
      find.byKey(const ValueKey('open-envelope-mail_bottom')),
    );
    final clip = tester.renderObject<RenderClipRect>(
      find.byKey(const ValueKey('envelope-pocket-clip')),
    );
    final localClip = clip.clipper!.getClip(clip.size);
    final globalClipBottom = clip.localToGlobal(localClip.bottomLeft).dy;
    expect(early.bottom, lessThanOrEqualTo(envelopeBottom.bottom));
    expect(globalClipBottom, lessThanOrEqualTo(envelopeBottom.bottom));
    expect(horizontalAxis(tester).dy, closeTo(0, .001));

    const extractionProbe = .45;
    await tester.pump(
      openingAt(extractionProbe - LetterOpening.extractionStart),
    );
    final middle = tester.getRect(find.byKey(const ValueKey('opening-paper')));
    expect(middle.center.dx, closeTo(early.center.dx, .001));
    expect(middle.top, lessThan(early.top));
    expect(middle.bottom, lessThanOrEqualTo(envelopeBottom.bottom));
    expect(horizontalAxis(tester).dy, closeTo(0, .001));

    await tester.pump(openingAt(LetterOpening.extractionEnd - extractionProbe));
    final extracted = tester.getRect(
      find.byKey(const ValueKey('opening-paper')),
    );
    expect(extracted, LetterOpening.extractedPaperRect);
    expect(extracted.center.dx, closeTo(middle.center.dx, .001));
    expect(extracted.top, lessThan(middle.top));
    expect(opened, 0);

    await tester.pump(const Duration(milliseconds: 1));
    final approachStart = tester.getRect(
      find.byKey(const ValueKey('opening-paper')),
    );
    expect((approachStart.topLeft - extracted.topLeft).distance, lessThan(.03));
    expect(horizontalAxis(tester).dy, closeTo(0, .001));

    const presentationMid =
        (LetterOpening.extractionEnd + LetterOpening.presentationEnd) / 2;
    await tester.pump(
      openingAt(presentationMid - LetterOpening.extractionEnd) -
          const Duration(milliseconds: 1),
    );
    final approaching = tester.getRect(
      find.byKey(const ValueKey('opening-paper')),
    );
    expect(approaching.width, greaterThan(extracted.width));
    expect(approaching.top, greaterThan(extracted.top));
    expect(horizontalAxis(tester).dy, closeTo(0, .001));
    expect(opened, 0);

    await tester.pump(
      openingAt(LetterOpening.presentationEnd - presentationMid) -
          const Duration(milliseconds: 1),
    );
    expect(opened, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(
      tester.getRect(find.byKey(const ValueKey('opening-paper'))),
      LetterOpening.finalPaperRect,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(opened, 1);
  });
}
