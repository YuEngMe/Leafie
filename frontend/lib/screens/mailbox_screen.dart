import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/models/plant_letter.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';

Future<void> showPlantMailbox(
  BuildContext context, {
  required String? plantId,
  PlantLetterRepository? repository,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.black.withValues(alpha: 0.45),
  pageBuilder: (_, animation, secondaryAnimation) =>
      MailboxScreen(plantId: plantId, repository: repository),
);

enum _MailView { loading, house, newLetter, list, opening }

/// Figma 3725:19529 / 3652:15470 / 3765:51829, over the actual home.
class MailboxScreen extends StatefulWidget {
  const MailboxScreen({
    super.key,
    required this.plantId,
    this.repository,
    this.debugPreview = false,
  });
  final String? plantId;
  final PlantLetterRepository? repository;
  final bool debugPreview;
  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen> {
  _MailView _view = _MailView.loading;
  List<PlantLetter> _letters = [];
  final Set<String> _read = {};
  PlantLetter? _selected;
  String? _error;
  final Set<String> _savingRead = {};
  final _canvasKey = GlobalKey();
  final _newEnvelopeKey = GlobalKey();
  Rect? _openingSource;
  _MailView _openingOrigin = _MailView.newLetter;
  bool _motionImagesLoaded = false;
  bool _previewOpen = false;
  bool get _isPreview => kDebugMode && widget.debugPreview;

  Future<void> _showMotionPreview() async {
    if (!kDebugMode || _previewOpen) return;
    setState(() => _previewOpen = true);
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, animation, secondaryAnimation) =>
            const MailboxScreen(plantId: null, debugPreview: true),
      );
    } finally {
      if (mounted) setState(() => _previewOpen = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionImagesLoaded) return;
    _motionImagesLoaded = true;
    // Warm the frames while the mailbox is visible, before the first tap.
    for (final asset in [
      'mail_envelope',
      'mail_flap',
      'mail_inner',
      'mail_front',
      'mail_bottom',
    ]) {
      precacheImage(AssetImage('assets/images/$asset.png'), context);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isPreview) {
      // Only this isolated debug route owns sample data; never query the server.
      final sample = PlantLetter(
        id: 'debug-motion-preview',
        recipient: '미리보기 사용자',
        sender: '미리보기 식물',
        body: '편지 모션 미리보기예요!\n실제 편지가 아니며 저장되지 않아요.',
        createdAt: DateTime(2026, 9, 10),
        isRead: false,
      );
      setState(() {
        _letters = [sample];
        _selected = sample;
        _view = _MailView.newLetter;
      });
      return;
    }
    final repository = widget.repository;
    if (repository == null || widget.plantId == null) {
      setState(() {
        _view = _MailView.list;
        _error = '편지 서비스 연결을 준비 중이에요.';
      });
      return;
    }
    setState(() {
      _view = _MailView.loading;
      _error = null;
    });
    try {
      final letters = List<PlantLetter>.of(
        await repository.listLetters(widget.plantId!),
      );
      if (!mounted) return;
      letters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _letters = List.of(letters);
        _selected = _letters
            .where((l) => !l.isRead && !_read.contains(l.id))
            .firstOrNull;
        _view = _selected == null ? _MailView.list : _MailView.newLetter;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _view = _MailView.list;
        _error = '편지를 불러오지 못했어요.';
      });
    }
  }

  void _open(PlantLetter letter, Rect globalBounds) {
    if (_view == _MailView.opening) return;
    final canvas = _canvasKey.currentContext!.findRenderObject() as RenderBox;
    final localBounds = Rect.fromPoints(
      canvas.globalToLocal(globalBounds.topLeft),
      canvas.globalToLocal(globalBounds.bottomRight),
    );
    setState(() {
      _openingOrigin = _view;
      _openingSource = localBounds;
      _selected = letter;
      _view = _MailView.opening;
      _error = null;
    });
  }

  Widget _departureScene() => IgnorePointer(
    child: Stack(
      children: [
        Positioned(
          left: 6,
          top: _openingOrigin == _MailView.newLetter ? 128 : 165,
          width: 390.69,
          height: 711,
          child: _MailboxIllustration(
            isNew: _openingOrigin == _MailView.newLetter,
          ),
        ),
        const Positioned.fill(child: _MailboxForeground()),
        if (_openingOrigin == _MailView.list) ...[
          const Positioned.fill(child: ColoredBox(color: Color(0x33000000))),
          Positioned(
            left: 26,
            top: 228,
            width: 349,
            height: 418,
            child: _LetterList(
              letters: _letters,
              readIds: _read,
              onOpen: (_, bounds) {},
              onClose: () {},
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _markRead() async {
    if (_isPreview) return;
    final letter = _selected;
    if (letter == null ||
        letter.isRead ||
        _read.contains(letter.id) ||
        _savingRead.contains(letter.id)) {
      return;
    }
    _savingRead.add(letter.id);
    try {
      await widget.repository!.markRead(widget.plantId!, letter.id);
      if (mounted) {
        setState(() {
          _read.add(letter.id);
          if (_selected?.id == letter.id) _error = null;
        });
      }
    } catch (_) {
      if (mounted && _selected?.id == letter.id && _view == _MailView.opening) {
        setState(() {
          _error = '읽음 상태를 저장하지 못했어요.';
        });
      }
    } finally {
      _savingRead.remove(letter.id);
    }
  }

  @override
  Widget build(BuildContext context) => _previewOpen
      ? const SizedBox.expand()
      : Material(
          type: MaterialType.transparency,
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: 402,
                height: 874,
                child: Stack(
                  key: _canvasKey,
                  children: [
                    if (_view == _MailView.house ||
                        _view == _MailView.newLetter ||
                        _view == _MailView.list) ...[
                      Positioned(
                        left: 6,
                        top: _view == _MailView.newLetter ? 128 : 165,
                        width: 390.69,
                        height: 711,
                        child: _MailboxIllustration(
                          isNew: _view == _MailView.newLetter,
                        ),
                      ),
                      const Positioned.fill(child: _MailboxForeground()),
                    ],
                    if (_view == _MailView.loading)
                      const Center(
                        child: CircularProgressIndicator(color: kOrangeMain),
                      ),
                    if (_view == _MailView.newLetter)
                      Positioned(
                        left: 122,
                        top: 255,
                        width: 157,
                        height: 130,
                        child: Semantics(
                          key: _newEnvelopeKey,
                          button: true,
                          label: '새 편지 열기',
                          child: GestureDetector(
                            key: const ValueKey('mail-new-letter'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final box =
                                  _newEnvelopeKey.currentContext!
                                          .findRenderObject()
                                      as RenderBox;
                              // The tappable region also includes the slot above the envelope.
                              _open(
                                _selected!,
                                Rect.fromPoints(
                                  box.localToGlobal(const Offset(15.5, 39)),
                                  box.localToGlobal(const Offset(139, 134)),
                                ),
                              );
                            },
                            child: const Center(
                              child: Text(
                                'NEW!',
                                style: TextStyle(
                                  fontFamily: kFontFamily,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_view == _MailView.house)
                      Positioned(
                        left: 125,
                        top: 292,
                        width: 152,
                        height: 116,
                        child: Semantics(
                          button: true,
                          label: '우편함 목록 열기',
                          child: GestureDetector(
                            key: const ValueKey('mail-house-envelope'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _view = _MailView.list),
                          ),
                        ),
                      ),
                    if (_view == _MailView.list) ...[
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0x33000000)),
                      ),
                      Positioned(
                        left: 26,
                        top: 228,
                        width: 349,
                        height: 418,
                        child: _LetterList(
                          letters: _letters,
                          readIds: _read,
                          error: _error,
                          onOpen: _open,
                          onClose: () =>
                              setState(() => _view = _MailView.house),
                          onRetry:
                              widget.repository == null ||
                                  widget.plantId == null
                              ? null
                              : _load,
                        ),
                      ),
                    ],
                    if (_view == _MailView.opening)
                      LetterOpening(
                        key: ValueKey(_selected!.id),
                        letter: _selected!,
                        onOpened: _markRead,
                        sourceRect: _openingSource,
                        departureScene: _departureScene(),
                      ),
                    if (_view == _MailView.opening && _error != null)
                      Positioned(
                        left: 35,
                        right: 35,
                        top: 610,
                        child: TextButton(
                          onPressed: _markRead,
                          child: Text(
                            '$_error 다시 시도',
                            style: kSmallStyle.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 331,
                      top: 47,
                      width: 49,
                      height: 49,
                      child: _MailClose(
                        onPressed: () {
                          if (_view == _MailView.opening) {
                            setState(() {
                              _view = _MailView.list;
                              _error = null;
                            });
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                    if (kDebugMode)
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 24,
                        child: _isPreview
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '개발용 미리보기 · 서버 저장 없음',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FilledButton(
                                        key: const ValueKey(
                                          'mail-preview-replay',
                                        ),
                                        onPressed: () => setState(() {
                                          _view = _MailView.newLetter;
                                          _selected = _letters.first;
                                          _error = null;
                                        }),
                                        child: const Text('처음부터'),
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton(
                                        key: const ValueKey(
                                          'mail-preview-exit',
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('미리보기 종료'),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Center(
                                child: FilledButton(
                                  key: const ValueKey('mail-motion-preview'),
                                  onPressed: _showMotionPreview,
                                  child: const Text('편지 모션 미리보기'),
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
}

class _MailClose extends StatelessWidget {
  const _MailClose({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '닫기',
    onPressed: onPressed,
    padding: const EdgeInsets.all(6),
    icon: SvgPicture.asset(
      'assets/images/mail_close.svg',
      width: 37,
      height: 37,
    ),
  );
}

class _LetterList extends StatelessWidget {
  const _LetterList({
    required this.letters,
    required this.readIds,
    required this.onOpen,
    required this.onClose,
    this.error,
    this.onRetry,
  });
  final List<PlantLetter> letters;
  final Set<String> readIds;
  final void Function(PlantLetter, Rect) onOpen;
  final VoidCallback onClose;
  final VoidCallback? onRetry;
  final String? error;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('mail-list'),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: kPaleYellow, width: 6),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 25,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/images/mail_list_icon.svg',
                width: 33,
                height: 26,
              ),
              const SizedBox(width: 10),
              Text('우편함', style: kTitleStyle.copyWith(fontSize: 25)),
            ],
          ),
        ),
        Positioned(
          right: -3,
          top: -4,
          width: 44,
          height: 44,
          child: _MailClose(onPressed: onClose),
        ),
        Positioned(
          left: 11,
          right: 11,
          top: 97,
          bottom: 24,
          child: error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error!,
                        style: kSmallStyle,
                        textAlign: TextAlign.center,
                      ),
                      if (onRetry != null)
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('다시 시도'),
                        ),
                    ],
                  ),
                )
              : letters.isEmpty
              ? const Center(child: Text('아직 도착한 편지가 없어요.', style: kSmallStyle))
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: letters.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 19),
                  itemBuilder: (context, index) {
                    final letter = letters[index];
                    final date = letter.createdAt.toLocal();
                    return Container(
                      height: 51,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(60),
                        boxShadow: const [
                          BoxShadow(color: Color(0x2E000000), blurRadius: 4.82),
                        ],
                      ),
                      child: Builder(
                        builder: (rowContext) => InkWell(
                          key: ValueKey('mail-${letter.id}'),
                          borderRadius: BorderRadius.circular(60),
                          onTap: () {
                            final box =
                                rowContext.findRenderObject() as RenderBox;
                            // Start at this visible row, including its current scroll offset.
                            final center = box.localToGlobal(
                              box.size.center(Offset.zero),
                            );
                            final size =
                                box.localToGlobal(Offset(64, 48)) -
                                box.localToGlobal(Offset.zero);
                            onOpen(
                              letter,
                              Rect.fromCenter(
                                center: center,
                                width: size.dx,
                                height: size.dy,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    letter.body.replaceAll('\n', ' '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: kSmallStyle.copyWith(
                                      color: Colors.black,
                                      fontWeight:
                                          letter.isRead ||
                                              readIds.contains(letter.id)
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${date.year}. ${date.month}. ${date.day} ${'월화수목금토일'[date.weekday - 1]}',
                                  style: kSmallStyle.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

/// User-requested interpolation between Figma's three static states (3852:4).
/// No Figma timeline is defined; duration is a local, adjustable motion token.
class LetterOpening extends StatefulWidget {
  const LetterOpening({
    super.key,
    required this.letter,
    required this.onOpened,
    this.sourceRect,
    this.departureScene,
  });
  final PlantLetter letter;
  final VoidCallback onOpened;
  final Rect? sourceRect;
  final Widget? departureScene;
  static const duration = Duration(milliseconds: 2300);
  static const pullDuration = Duration(milliseconds: 800);
  static const pressDuration = Duration(milliseconds: 100);
  static const liftDuration = Duration(milliseconds: 280);
  static const travelDuration = Duration(milliseconds: 420);

  static const flapEnd = .20;
  static const extractionStart = .18;
  static const extractionEnd = .62;
  static const presentationEnd = 1.0;

  static const envelopeRect = Rect.fromLTWH(53, 348.2471, 295.8224, 222.8359);
  static const openEnvelopeRect = Rect.fromLTWH(53, 230, 296, 335);
  static const initialPaperRect = Rect.fromLTWH(95, 365, 212, 154);
  static const extractedPaperRect = Rect.fromLTWH(95, 185, 212, 154);
  static const finalPaperRect = Rect.fromLTWH(27, 311, 348, 253);
  @override
  State<LetterOpening> createState() => _LetterOpeningState();
}

class _LetterOpeningState extends State<LetterOpening>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration:
        LetterOpening.duration +
        (widget.sourceRect == null
            ? Duration.zero
            : LetterOpening.pullDuration),
  );
  bool _started = false;
  bool _notified = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_notified) {
        _notified = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onOpened();
        });
      }
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final elapsed = _controller.value * _controller.duration!.inMilliseconds;
      final pullMs = widget.sourceRect == null
          ? 0.0
          : LetterOpening.pullDuration.inMilliseconds.toDouble();
      final pressMs = LetterOpening.pressDuration.inMilliseconds.toDouble();
      final liftEndMs =
          pressMs + LetterOpening.liftDuration.inMilliseconds.toDouble();
      final pulling = elapsed < pullMs;
      final t = ((elapsed - pullMs) / LetterOpening.duration.inMilliseconds)
          .clamp(0.0, 1.0);
      var envelope = LetterOpening.envelopeRect;
      var angle = 0.0;
      if (pulling) {
        final source = widget.sourceRect!;
        final pressed = Rect.fromCenter(
          center: source.center,
          width: source.width * .95,
          height: source.height * .95,
        );
        final lifted = pressed.shift(const Offset(0, -28));
        if (elapsed < pressMs) {
          envelope = Rect.lerp(
            source,
            pressed,
            Curves.easeOut.transform(elapsed / pressMs),
          )!;
        } else if (elapsed < liftEndMs) {
          final p = Curves.easeInOutCubic.transform(
            (elapsed - pressMs) / LetterOpening.liftDuration.inMilliseconds,
          );
          envelope = Rect.lerp(pressed, lifted, p)!;
          angle = -.0872665 * p;
        } else {
          final p =
              ((elapsed - liftEndMs) /
                      LetterOpening.travelDuration.inMilliseconds)
                  .clamp(0.0, 1.0);
          envelope = Rect.lerp(
            lifted,
            LetterOpening.envelopeRect,
            Curves.easeInOutCubic.transform(p),
          )!;
          angle = -.0872665 * (1 - Curves.easeOutCubic.transform(p));
        }
      }
      final flap = const Interval(
        0,
        LetterOpening.flapEnd,
        curve: Curves.easeInOutCubic,
      ).transform(t);
      final extraction = const Interval(
        LetterOpening.extractionStart,
        LetterOpening.extractionEnd,
        curve: Curves.easeInOutCubic,
      ).transform(t);
      final presentation = const Interval(
        LetterOpening.extractionEnd,
        LetterOpening.presentationEnd,
        curve: Curves.easeInOutCubic,
      ).transform(t);
      final envelopeFade =
          1 -
          const Interval(
            LetterOpening.extractionEnd,
            .88,
            curve: Curves.easeInOutCubic,
          ).transform(t);
      final paperReveal = const Interval(
        .12,
        LetterOpening.extractionStart,
        curve: Curves.easeInOut,
      ).transform(t);
      final clipRelease = const Interval(
        .58,
        LetterOpening.extractionEnd,
        curve: Curves.easeInOut,
      ).transform(t);
      final extractedPaper = Rect.lerp(
        LetterOpening.initialPaperRect,
        LetterOpening.extractedPaperRect,
        extraction,
      )!;
      final paperRect = Rect.lerp(
        extractedPaper,
        LetterOpening.finalPaperRect,
        presentation,
      )!;
      final pocketBottom =
          LetterOpening.openEnvelopeRect.bottom +
          (874 - LetterOpening.openEnvelopeRect.bottom) * clipRelease;
      final paperLayer = Positioned.fill(
        key: const ValueKey('opening-paper-layer'),
        child: ClipRect(
          key: const ValueKey('envelope-pocket-clip'),
          clipper: _EnvelopePocketClipper(bottom: pocketBottom),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fromRect(
                rect: paperRect,
                child: SizedBox.expand(
                  key: const ValueKey('opening-paper'),
                  child: Opacity(
                    opacity: paperReveal,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: LetterOpening.finalPaperRect.width,
                        height: LetterOpening.finalPaperRect.height,
                        child: _LetterPaper(letter: widget.letter),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return Stack(
        key: const ValueKey('letter-opening'),
        children: [
          if (pulling && widget.departureScene != null)
            Positioned.fill(
              child: Opacity(
                opacity:
                    1 -
                    Curves.easeOut.transform(
                      ((elapsed - pressMs) / liftEndMs).clamp(0.0, 1.0),
                    ),
                child: widget.departureScene,
              ),
            ),
          if (flap < 1)
            Positioned.fromRect(
              key: const ValueKey('travelling-envelope'),
              rect: envelope,
              child: Opacity(
                opacity: 1 - flap,
                child: Transform.rotate(
                  angle: angle,
                  child: Image.asset(
                    'assets/images/mail_envelope.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          if (flap > 0)
            Positioned.fromRect(
              rect: LetterOpening.openEnvelopeRect,
              child: Opacity(
                opacity: flap * envelopeFade,
                child: const _OpenEnvelopeBacking(),
              ),
            ),
          if (paperReveal > 0 && extraction < 1) paperLayer,
          if (flap > 0 && envelopeFade > 0)
            Positioned.fromRect(
              rect: LetterOpening.openEnvelopeRect,
              child: Opacity(
                opacity: flap * envelopeFade,
                child: const _OpenEnvelopeFront(),
              ),
            ),
          if (paperReveal > 0 && extraction >= 1) paperLayer,
        ],
      );
    },
  );
}

// Rasterized directly from Figma: preserve filters, texture masks and render bounds.
class _MailboxIllustration extends StatelessWidget {
  const _MailboxIllustration({required this.isNew});
  final bool isNew;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: isNew ? -5 : 0,
        top: isNew ? -5 : 0,
        width: isNew ? 400.6904 : 390.6904,
        height: isNew ? 716.0005 : 709,
        child: Image.asset(
          'assets/images/${isNew ? 'mailbox_new' : 'mailbox_house'}.png',
          fit: BoxFit.fill,
          excludeFromSemantics: true,
        ),
      ),
    ],
  );
}

class _MailboxForeground extends StatelessWidget {
  const _MailboxForeground();
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        Positioned(
          left: 0,
          top: 645.2998,
          width: 402,
          height: 228.7002,
          child: Image.asset(
            'assets/images/mailbox_foreground.png',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
      ],
    ),
  );
}

class _OpenEnvelopeBacking extends StatelessWidget {
  const _OpenEnvelopeBacking();
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      // Coordinates include each layer's effect bounds. The exports already
      // contain Figma rotations; applying them again would mirror the folds.
      for (final d in [
        ('mail_flap', 3.2634, 0.0, 289.5587, 142.4487),
        ('mail_inner', 11.648, 125.0, 272.304, 134.1519),
      ])
        Positioned(
          left: d.$2,
          top: d.$3,
          width: d.$4,
          height: d.$5,
          child: Image.asset(
            'assets/images/${d.$1}.png',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
    ],
  );
}

class _OpenEnvelopeFront extends StatelessWidget {
  const _OpenEnvelopeFront();
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final d in [
        ('mail_front', 8.0004, 115.0, 280.543, 219.085),
        ('mail_bottom', 6.2012, 234.8208, 283.7218, 106.2622),
      ])
        Positioned(
          key: ValueKey('open-envelope-${d.$1}'),
          left: d.$2,
          top: d.$3,
          width: d.$4,
          height: d.$5,
          child: Image.asset(
            'assets/images/${d.$1}.png',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
    ],
  );
}

class _EnvelopePocketClipper extends CustomClipper<Rect> {
  const _EnvelopePocketClipper({required this.bottom});
  final double bottom;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width, bottom.clamp(0, size.height).toDouble());

  @override
  bool shouldReclip(_EnvelopePocketClipper oldClipper) =>
      bottom != oldClipper.bottom;
}

class _LetterPaper extends StatelessWidget {
  const _LetterPaper({required this.letter});
  final PlantLetter letter;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('opened-letter'),
    decoration: BoxDecoration(
      color: kPaleYellow,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 13,
          top: 10,
          right: 13,
          bottom: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        Positioned(
          left: 39,
          top: 24,
          right: 40,
          child: Text(
            'TO. ${letter.recipient}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kBodyStyle.copyWith(fontSize: 15.467, color: Colors.black),
          ),
        ),
        Positioned(
          left: 40,
          right: 40,
          top: 70,
          bottom: 60,
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                letter.body,
                textAlign: TextAlign.center,
                style: kBodyStyle.copyWith(
                  fontSize: 19.886,
                  height: 1.445,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 110,
          right: 47,
          bottom: 25,
          child: Text(
            'From. ${letter.sender}',
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kBodyStyle.copyWith(fontSize: 13.258, color: Colors.black),
          ),
        ),
        for (final d in [
          (0, 25.4, 202.6, 35.4, 35.4),
          (1, 57.4, 211.0, 22.5, 26.6),
          (2, 302.6, 211.6, 23.9, 25.8),
          (3, 298.6, 30.1, 34.7, 34.7),
          (4, 7.0, 169.4, 29.2, 29.2),
          (5, 277.3, 15.5, 26.7, 26.7),
        ])
          Positioned(
            left: d.$2,
            top: d.$3,
            width: d.$4,
            height: d.$5,
            child: SvgPicture.asset(
              'assets/images/mail_decoration_${d.$1}.svg',
            ),
          ),
      ],
    ),
  );
}
