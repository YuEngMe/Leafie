import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yeso_plant/models/plant_letter.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/onboarding_overlays.dart';

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
  String? _detailError;
  final Set<String> _savingRead = {};
  final Set<String> _deleting = {};
  final _canvasKey = GlobalKey();
  final _newEnvelopeKey = GlobalKey();
  Rect? _openingSource;
  PlantLetter? _pendingLetter;
  Rect? _pendingBounds;
  int _detailEpoch = 0;
  bool _loadingDetail = false;
  String? _scheduledAutoOpenLetterId;
  _MailView _openingOrigin = _MailView.newLetter;
  bool _motionImagesLoaded = false;
  bool get _isPreview => kDebugMode && widget.debugPreview;

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
    if (widget.plantId == null) {
      setState(() {
        _view = _MailView.list;
        _error = '먼저 식물을 등록해 주세요.';
      });
      return;
    }
    if (repository == null) {
      setState(() {
        _view = _MailView.list;
        _error = '편지 서비스에 연결할 수 없어요.';
      });
      return;
    }
    _detailEpoch++;
    _scheduledAutoOpenLetterId = null;
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
      final unread = letters
          .where((letter) => !letter.isRead && !_read.contains(letter.id))
          .firstOrNull;
      setState(() {
        _letters = List.of(letters);
        _selected = unread;
        _view = unread == null ? _MailView.list : _MailView.newLetter;
      });
      if (unread != null) _scheduleUnreadOpening(unread);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _view = _MailView.list;
        _error = '편지를 불러오지 못했어요.';
      });
    }
  }

  Rect _newLetterGlobalBounds() {
    final box = _newEnvelopeKey.currentContext!.findRenderObject() as RenderBox;
    return Rect.fromPoints(
      box.localToGlobal(const Offset(14.43, 20)),
      box.localToGlobal(const Offset(138.43, 116)),
    );
  }

  void _scheduleUnreadOpening(PlantLetter letter) {
    if (_isPreview || _scheduledAutoOpenLetterId == letter.id) return;
    _scheduledAutoOpenLetterId = letter.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _view != _MailView.newLetter ||
          _selected?.id != letter.id ||
          _loadingDetail ||
          _detailError != null) {
        return;
      }
      final envelopeContext = _newEnvelopeKey.currentContext;
      if (envelopeContext == null) {
        _scheduledAutoOpenLetterId = null;
        _scheduleUnreadOpening(letter);
        return;
      }
      _open(letter, _newLetterGlobalBounds());
    });
  }

  Future<void> _open(PlantLetter letter, Rect globalBounds) async {
    if (_view == _MailView.opening || _loadingDetail) return;
    _pendingLetter = letter;
    _pendingBounds = globalBounds;
    _detailError = null;
    if (letter.contentLoaded || _isPreview) {
      _beginOpening(letter, globalBounds);
      return;
    }
    final request = ++_detailEpoch;
    setState(() => _loadingDetail = true);
    try {
      final detail = await widget.repository!.getLetter(
        widget.plantId!,
        letter.id,
      );
      if (!mounted || request != _detailEpoch) return;
      if (detail.id != letter.id || !detail.contentLoaded) {
        throw StateError('invalid letter detail');
      }
      final index = _letters.indexWhere((item) => item.id == detail.id);
      if (index >= 0) _letters[index] = detail;
      _loadingDetail = false;
      _beginOpening(detail, globalBounds);
    } catch (_) {
      if (!mounted || request != _detailEpoch) return;
      setState(() {
        _loadingDetail = false;
        _detailError = '편지 내용을 불러오지 못했어요.';
      });
    }
  }

  void _beginOpening(PlantLetter letter, Rect globalBounds) {
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
      _detailError = null;
      _pendingLetter = null;
      _pendingBounds = null;
    });
  }

  void _cancelDetailRequest() {
    _detailEpoch++;
    _loadingDetail = false;
    _detailError = null;
    _pendingLetter = null;
    _pendingBounds = null;
  }

  void _retryDetail() {
    final letter = _pendingLetter;
    final bounds = _pendingBounds;
    if (letter != null && bounds != null) _open(letter, bounds);
  }

  Future<bool> _deleteLetter(String letterId) async {
    if (_isPreview || _deleting.contains(letterId)) return false;
    final repository = widget.repository;
    final plantId = widget.plantId;
    if (repository == null || plantId == null) return false;
    _deleting.add(letterId);
    try {
      await repository.deleteLetter(plantId, letterId);
      if (!mounted) return false;
      setState(() {
        _letters.removeWhere((letter) => letter.id == letterId);
        _read.remove(letterId);
        if (_selected?.id == letterId) _selected = null;
      });
      return true;
    } catch (_) {
      return false;
    } finally {
      _deleting.remove(letterId);
    }
  }

  Widget _departureScene() => IgnorePointer(
    child: Stack(
      children: [
        Positioned(
          left: 6,
          top: 165,
          width: 390.69,
          height: 709,
          child: const _MailboxIllustration(),
        ),
        const Positioned.fill(child: _MailboxForeground()),
        if (_openingOrigin == _MailView.list) ...[
          const Positioned.fill(child: ColoredBox(color: Color(0x33000000))),
          Positioned(
            left: 26,
            top: 228,
            width: 349,
            height: 417.5718,
            child: _LetterList(
              letters: _letters,
              onOpen: (_, bounds) {},
              onClose: () {},
              onDelete: (_) async => false,
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
  Widget build(BuildContext context) => Material(
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
                  top: 165,
                  width: 390.69,
                  height: 709,
                  child: const _MailboxIllustration(),
                ),
                const Positioned.fill(child: _MailboxForeground()),
              ],
              if (_view == _MailView.loading)
                const Center(
                  child: CircularProgressIndicator(color: kOrangeMain),
                ),
              if (_view == _MailView.newLetter)
                Positioned(
                  left: 125.57,
                  top: 292,
                  width: 151.85,
                  height: 116,
                  child: Semantics(
                    key: _newEnvelopeKey,
                    button: true,
                    label: '새 편지 열기',
                    child: GestureDetector(
                      key: const ValueKey('mail-new-letter'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _open(_selected!, _newLetterGlobalBounds()),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              if (_view == _MailView.newLetter)
                Positioned(
                  left: 195.2847,
                  top: 349.8887,
                  width: 9.4666,
                  height: 31.5112,
                  child: IgnorePointer(
                    child: SvgPicture.asset(
                      'assets/images/mail_unread.svg',
                      fit: BoxFit.fill,
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
                  height: 417.5718,
                  child: _LetterList(
                    letters: _letters,
                    error: _error,
                    onOpen: _open,
                    onClose: () => setState(() => _view = _MailView.house),
                    onRetry: widget.repository == null || widget.plantId == null
                        ? null
                        : _load,
                    onDelete: _deleteLetter,
                    registerPlant: widget.plantId == null
                        ? () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => const PlantRegisterNameScreen(),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ],
              if (_loadingDetail || _detailError != null)
                Positioned.fill(
                  child: _DetailLoadOverlay(
                    loading: _loadingDetail,
                    message: _detailError,
                    onRetry: _retryDetail,
                    onCancel: () => setState(_cancelDetailRequest),
                  ),
                ),
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
                    if (_loadingDetail || _detailError != null) {
                      setState(_cancelDetailRequest);
                      return;
                    }
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
              if (_isPreview)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '개발용 미리보기 · 서버 저장 없음',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton(
                            key: const ValueKey('mail-preview-replay'),
                            onPressed: () => setState(() {
                              _view = _MailView.newLetter;
                              _selected = _letters.first;
                              _error = null;
                            }),
                            child: const Text('처음부터'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            key: const ValueKey('mail-preview-exit'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('미리보기 종료'),
                          ),
                        ],
                      ),
                    ],
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

class _LetterList extends StatefulWidget {
  const _LetterList({
    required this.letters,
    required this.onOpen,
    required this.onClose,
    required this.onDelete,
    this.error,
    this.onRetry,
    this.registerPlant,
  });
  final List<PlantLetter> letters;
  final void Function(PlantLetter, Rect) onOpen;
  final VoidCallback onClose;
  final Future<bool> Function(String) onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? registerPlant;
  final String? error;

  @override
  State<_LetterList> createState() => _LetterListState();
}

class _LetterListState extends State<_LetterList> {
  String? _revealedId;
  String? _deletingId;
  String? _deleteErrorId;
  bool _confirming = false;
  double _horizontalDrag = 0;

  @override
  void didUpdateWidget(covariant _LetterList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_revealedId != null &&
        !widget.letters.any((letter) => letter.id == _revealedId)) {
      _revealedId = null;
    }
    if (_deleteErrorId != null &&
        !widget.letters.any((letter) => letter.id == _deleteErrorId)) {
      _deleteErrorId = null;
    }
  }

  void _reveal(String id) {
    if (_deletingId != null || _confirming) return;
    setState(() {
      _revealedId = id;
      _deleteErrorId = null;
    });
  }

  Future<void> _confirmDelete(String id) async {
    if (_confirming || _deletingId != null) return;
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .45),
      builder: (_) =>
          const ConfirmDialog(message: '삭제하시겠습니까?', subtitle: '우편함에서 사라져요'),
    );
    _confirming = false;
    if (!mounted || confirmed != true) {
      if (mounted && confirmed == false) setState(() => _revealedId = null);
      return;
    }
    await _delete(id);
  }

  Future<void> _delete(String id) async {
    if (_deletingId != null) return;
    setState(() {
      _deletingId = id;
      _deleteErrorId = null;
    });
    final deleted = await widget.onDelete(id);
    if (!mounted) return;
    setState(() {
      _deletingId = null;
      if (deleted) {
        _revealedId = null;
      } else {
        _revealedId = id;
        _deleteErrorId = id;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('mail-list'),
    decoration: BoxDecoration(
      color: kPaleYellow,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 6,
          top: 5.786,
          width: 335.695,
          height: 402.427,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 1.35, sigmaY: 1.35),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        Positioned(
          left: 114,
          top: 34.786,
          width: 33.354,
          height: 25.563,
          child: SvgPicture.asset(
            'assets/images/mail_list_icon.svg',
            fit: BoxFit.fill,
          ),
        ),
        Positioned(
          left: 157,
          top: 31.171,
          width: 66,
          height: 29.979,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '우편함',
              key: const ValueKey('mail-list-title-text'),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: kTitleStyle.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF444444),
                height: 29.979 / 25,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        Positioned(
          left: 302,
          top: 10.785,
          width: 36.77,
          height: 36.77,
          child: IconButton(
            tooltip: '닫기',
            padding: EdgeInsets.zero,
            onPressed: widget.onClose,
            icon: SvgPicture.asset(
              'assets/images/mail_list_close.svg',
              width: 36.77,
              height: 36.77,
            ),
          ),
        ),
        Positioned(
          left: 7,
          top: 91.786,
          width: 332.135,
          bottom: 5.8,
          child: widget.error != null
              ? _ListMessage(
                  message: widget.error!,
                  actionLabel: widget.registerPlant != null
                      ? '식물 등록하기'
                      : widget.onRetry != null
                      ? '다시 시도'
                      : null,
                  onAction: widget.registerPlant ?? widget.onRetry,
                )
              : widget.letters.isEmpty
              ? const _ListMessage(message: '아직 도착한 편지가 없어요.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 11, 10, 10),
                  itemCount: widget.letters.length,
                  separatorBuilder: (_, index) =>
                      const SizedBox(height: 18.8994),
                  itemBuilder: (context, index) {
                    final letter = widget.letters[index];
                    return _buildRow(letter);
                  },
                ),
        ),
        if (widget.error == null && widget.letters.isNotEmpty)
          const Positioned(
            left: 5,
            top: 338.786,
            width: 339,
            height: 73,
            child: IgnorePointer(child: _ListBottomFade()),
          ),
        if (_deleteErrorId case final id?)
          Positioned(
            left: 36,
            right: 36,
            bottom: 4,
            height: 44,
            child: Material(
              color: Colors.white.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(22),
              child: TextButton(
                key: ValueKey('mail-delete-retry-$id'),
                onPressed: _deletingId == null ? () => _delete(id) : null,
                child: const Text('삭제하지 못했어요. 다시 시도'),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _buildRow(PlantLetter letter) {
    final date = letter.createdAt.toLocal();
    final revealed = _revealedId == letter.id;
    final deleting = _deletingId == letter.id;
    final deleteAction = CustomSemanticsAction(label: '삭제 옵션 보기');
    return SizedBox(
      height: 51,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (revealed)
            Positioned(
              left: 266,
              top: 2.5,
              width: 46,
              height: 46,
              child: IconButton(
                key: ValueKey('mail-delete-${letter.id}'),
                tooltip: '편지 삭제',
                padding: EdgeInsets.zero,
                onPressed: deleting ? null : () => _confirmDelete(letter.id),
                icon: deleting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : SvgPicture.asset(
                        'assets/images/mail_delete.svg',
                        width: 46,
                        height: 46,
                      ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            left: revealed ? 6 : 0,
            top: 0,
            width: revealed ? 248 : 312.135,
            height: 51,
            child: Semantics(
              button: true,
              label: '편지: ${letter.preview}',
              customSemanticsActions: {deleteAction: () => _reveal(letter.id)},
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _horizontalDrag = 0,
                onHorizontalDragUpdate: (details) {
                  _horizontalDrag += details.delta.dx;
                  if (_horizontalDrag < -36 && !revealed) {
                    _reveal(letter.id);
                  }
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -200 || _horizontalDrag < -36) {
                    _reveal(letter.id);
                  } else if ((velocity > 200 || _horizontalDrag > 36) &&
                      revealed) {
                    setState(() => _revealedId = null);
                  }
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(60.258),
                    boxShadow: const [
                      BoxShadow(color: Color(0x2E000000), blurRadius: 4.821),
                    ],
                  ),
                  child: Builder(
                    builder: (rowContext) => InkWell(
                      key: ValueKey('mail-${letter.id}'),
                      borderRadius: BorderRadius.circular(60.258),
                      onLongPress: () => _reveal(letter.id),
                      onTap: deleting
                          ? null
                          : () {
                              if (revealed) {
                                setState(() => _revealedId = null);
                                return;
                              }
                              final box =
                                  rowContext.findRenderObject() as RenderBox;
                              final center = box.localToGlobal(
                                box.size.center(Offset.zero),
                              );
                              final size =
                                  box.localToGlobal(const Offset(64, 48)) -
                                  box.localToGlobal(Offset.zero);
                              widget.onOpen(
                                letter,
                                Rect.fromCenter(
                                  center: center,
                                  width: size.dx,
                                  height: size.dy,
                                ),
                              );
                            },
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 18,
                          right: revealed ? 15.696 : 14.831,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                letter.preview.replaceAll('\n', ' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: kFontFamily,
                                  fontSize: 14.462,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 90.146,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${date.year}. ${date.month}. ${date.day} ${'월화수목금토일'[date.weekday - 1]}',
                                  key: ValueKey('mail-date-${letter.id}'),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontFamily: kFontFamily,
                                    fontSize: 14.462,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0,
                                    color: Color(0xFFA1A1A1),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (revealed)
            const Positioned(
              left: -2,
              top: -10.786,
              width: 200,
              height: 68,
              child: IgnorePointer(child: _ListLeftFade()),
            ),
        ],
      ),
    );
  }
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({required this.message, this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: kSmallStyle, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

class _ListBottomFade extends StatelessWidget {
  const _ListBottomFade();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(17),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00FFFCE5), Color(0xFFFFF9E3)],
        stops: [.50359, .99577],
      ),
    ),
  );
}

class _ListLeftFade extends StatelessWidget {
  const _ListLeftFade();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white, Color(0x00FFFFFF)],
        stops: [.17212, .84],
      ),
    ),
  );
}

class _DetailLoadOverlay extends StatelessWidget {
  const _DetailLoadOverlay({
    required this.loading,
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });
  final bool loading;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x59000000),
    child: Center(
      child: Container(
        width: 270,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const CircularProgressIndicator(color: kOrangeMain),
              const SizedBox(height: 14),
              const Text('편지를 펼치고 있어요.', style: kSmallStyle),
            ] else ...[
              Text(message!, style: kSmallStyle, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              TextButton(
                key: const ValueKey('mail-detail-retry'),
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ],
            TextButton(onPressed: onCancel, child: const Text('취소')),
          ],
        ),
      ),
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
  const _MailboxIllustration();
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/mailbox_house_v2.png',
    fit: BoxFit.fill,
    excludeFromSemantics: true,
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
          left: 10.0171,
          top: 7.0171,
          width: 327.9658,
          height: 238.9658,
          child: Image.asset(
            'assets/images/mail_paper_texture.png',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
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
