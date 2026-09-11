import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeso_plant/models/plant_letter.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/screens/mailbox_screen.dart';

PlantLetter letter({bool read = false, String id = 'one'}) => PlantLetter(
  id: id,
  recipient: '테스트 사용자',
  sender: '테스트 식물',
  body: '나에게 물을 줘서 고마워!\n덕분에 정말 상쾌한 아침이야~',
  createdAt: DateTime(2026, 9, 10),
  isRead: read,
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

class Repository implements PlantLetterRepository {
  Repository(this.letters);
  final List<PlantLetter> letters;
  bool failList = false;
  bool failRead = false;
  final reads = <String>[];
  final pendingReads = <String, Future<void>>{};
  @override
  Future<List<PlantLetter>> listLetters(String plantId) async {
    if (failList) throw StateError('offline');
    return List.unmodifiable(letters);
  }

  @override
  Future<void> markRead(String plantId, String letterId) async {
    await pendingReads[letterId];
    if (failRead) throw StateError('offline');
    reads.add(letterId);
  }
}

Future<void> launch(
  WidgetTester tester,
  Repository? repository, {
  bool reduced = false,
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
      'leafie_character',
      'mailbox_house',
      'mailbox_new',
      'mailbox_foreground',
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
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('미연동 앱에서도 미리보기 재생과 반복 후 원래 화면으로 돌아온다', (tester) async {
    await launch(tester, null);
    await tester.tap(find.byKey(const ValueKey('mail-motion-preview')));
    await tester.pumpAndSettle();
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
    expect(find.text('편지 서비스 연결을 준비 중이에요.'), findsOneWidget);
    expect(find.text('TO. 미리보기 사용자'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('미리보기는 실제 저장소 읽음 상태를 변경하지 않는다', (tester) async {
    final repository = Repository([letter()]);
    await launch(tester, repository);
    await tester.tap(find.byKey(const ValueKey('mail-motion-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
    await tester.pumpAndSettle();
    expect(repository.reads, isEmpty);
    await tester.tap(find.byKey(const ValueKey('mail-preview-exit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-new-letter')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
    await tester.pumpAndSettle();
    expect(find.text('TO. 테스트 사용자'), findsOneWidget);
    expect(repository.reads, ['one']);
  });

  testWidgets('느린 읽음 저장은 다른 편지 읽음 처리나 오류 상태를 덮어쓰지 않는다', (tester) async {
    final a = Completer<void>();
    final b = Completer<void>();
    final repository = Repository([letter(), letter(id: 'two')]);
    repository.pendingReads.addAll({'one': a.future, 'two': b.future});
    await launch(tester, repository);
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
    await tester.pumpAndSettle();
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
  testWidgets('새 편지 안내에서 바로 세 단계 모션을 재생하고 마지막에 읽음 처리', (tester) async {
    final repository = Repository([letter()]);
    await launch(tester, repository);
    expect(find.byKey(const ValueKey('mail-new-letter')), findsOneWidget);
    expect(find.byKey(const ValueKey('mail-list')), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mail_new_402.png'),
    );
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
    await tester.pump();
    expect(repository.reads, isEmpty);
    final start = tester.getRect(
      find.byKey(const ValueKey('travelling-envelope')),
    );
    expect(start.left, closeTo(137.5, .1));
    expect(start.top, closeTo(294, .1));
    await tester.pump(LetterOpening.pressDuration + LetterOpening.liftDuration);
    final lifted = tester.getRect(
      find.byKey(const ValueKey('travelling-envelope')),
    );
    expect(lifted.center.dy, lessThan(start.center.dy));
    expect(repository.reads, isEmpty);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mail_pull_402.png'),
    );
    await tester.pump(LetterOpening.travelDuration);
    expect(
      tester.getRect(find.byKey(const ValueKey('travelling-envelope'))).left,
      closeTo(53, .1),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mail_closed_402.png'),
    );
    await tester.pump(openingAt(.45));
    expect(repository.reads, isEmpty);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mail_opening_402.png'),
    );
    await tester.pump(openingAt(.55) - const Duration(milliseconds: 1));
    expect(repository.reads, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(repository.reads, ['one']);
    expect(find.text('TO. 테스트 사용자'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mail_opened_402.png'),
    );
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
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mail_list_402.png'),
    );
    await tester.tap(find.byKey(const ValueKey('mail-one')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('opened-letter')), findsOneWidget);
    expect(repository.reads, isEmpty);
  });

  testWidgets('빈 목록과 미연동 상태를 구분하고 닫기로 홈에 복귀한다', (tester) async {
    await launch(tester, null);
    expect(find.text('편지 서비스 연결을 준비 중이에요.'), findsOneWidget);
    expect(find.text('아직 도착한 편지가 없어요.'), findsNothing);
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    expect(find.byType(MailboxScreen), findsNothing);
  });

  testWidgets('빈 우편함은 예시 편지를 만들지 않는다', (tester) async {
    await launch(tester, Repository([]));
    expect(find.text('아직 도착한 편지가 없어요.'), findsOneWidget);
    expect(find.text('NEW!'), findsNothing);
    await tester.tap(find.byTooltip('닫기').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-house-envelope')), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mail_house_402.png'),
    );
    await tester.tap(find.byKey(const ValueKey('mail-house-envelope')));
    await tester.pumpAndSettle();
    expect(find.text('아직 도착한 편지가 없어요.'), findsOneWidget);
  });

  testWidgets('조회 실패 재시도와 읽음 저장 실패 재시도', (tester) async {
    final repository = Repository([letter()])..failList = true;
    await launch(tester, repository);
    expect(find.text('편지를 불러오지 못했어요.'), findsOneWidget);
    repository.failList = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    repository.failRead = true;
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
    await tester.pumpAndSettle();
    expect(find.textContaining('읽음 상태를 저장하지 못했어요.'), findsOneWidget);
    repository.failRead = false;
    await tester.tap(find.textContaining('읽음 상태를 저장하지 못했어요.'));
    await tester.pumpAndSettle();
    expect(repository.reads, ['one']);
  });

  testWidgets('동작 줄이기에서는 바로 편지를 표시한다', (tester) async {
    final repository = Repository([letter()]);
    await launch(tester, repository, reduced: true);
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('opened-letter')), findsOneWidget);
    expect(repository.reads, ['one']);
  });

  testWidgets('모션 도중 닫으면 읽음 처리하지 않는다', (tester) async {
    final repository = Repository([letter()]);
    await launch(tester, repository);
    await tester.tap(find.byKey(const ValueKey('mail-new-letter')));
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
