import 'package:flutter/material.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/notification_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/notification_tile.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

typedef NotificationSelected = void Function(NotificationData notification);

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    this.repository,
    this.onNotificationSelected,
  });

  final NotificationRepository? repository;
  final NotificationSelected? onNotificationSelected;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final NotificationRepository _repository =
      widget.repository ?? NotificationApi();
  final ScrollController _scrollController = ScrollController();
  final List<NotificationData> _items = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = false;
  String? _nextCursor;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearEnd);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final page = await _repository.getNotifications();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
      });
    } on LeafieApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadMoreNearEnd() {
    if (_scrollController.position.extentAfter < 160) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNext || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repository.getNotifications(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        final knownIds = _items.map((item) => item.id).toSet();
        _items.addAll(page.items.where((item) => knownIds.add(item.id)));
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
      });
    } on LeafieApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _select(NotificationData notification) async {
    var selected = notification;
    if (!notification.isRead) {
      try {
        selected = await _repository.markRead(notification.id);
        if (!mounted) return;
        setState(() {
          final index = _items.indexWhere((item) => item.id == notification.id);
          if (index >= 0) _items[index] = selected;
        });
      } on LeafieApiException catch (error) {
        _showError(error.message);
        return;
      }
    }
    widget.onNotificationSelected?.call(selected);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '알림'),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kOrangeMain));
    }
    if (_errorMessage != null) {
      return _NotificationMessage(
        message: _errorMessage!,
        actionLabel: '다시 시도',
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return const _NotificationMessage(message: '도착한 알림이 없어요.');
    }

    // 시안 3448:2는 오늘/지난 두 절이다. API에 절 구분이 없으므로
    // createdAt이 오늘(로컬)인지로 나눈다.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayItems = <NotificationData>[];
    final pastItems = <NotificationData>[];
    for (final item in _items) {
      final local = item.createdAt.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      (date == today ? todayItems : pastItems).add(item);
    }

    return RefreshIndicator(
      color: kOrangeMain,
      onRefresh: _load,
      child: ListView(
        key: const Key('notification-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (todayItems.isNotEmpty) ..._section('오늘의 알림', todayItems),
          if (pastItems.isNotEmpty)
            ..._section(
              '지난 알림',
              pastItems,
              // 시안: 마지막 오늘 타일 바닥 373.196 → "지난 알림" 잉크 413.196.
              topGap: todayItems.isEmpty ? kNotificationSectionTop : 40,
            ),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kOrangeMain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _section(
    String title,
    List<NotificationData> items, {
    double topGap = kNotificationSectionTop,
  }) {
    return [
      SizedBox(height: topGap),
      // 시안 3448:49 / 3456:4904: x=34, Paperlogy 16 w600 #444.
      Padding(
        padding: const EdgeInsets.only(left: 34),
        child: Text(title, style: kItemStyle),
      ),
      // 시안: 헤더 잉크 top 140 → 첫 타일 top 169.
      const SizedBox(height: kNotificationHeaderToTile),
      for (var index = 0; index < items.length; index++) ...[
        if (index > 0) const SizedBox(height: kNotificationTileGap),
        NotificationTile(
          notification: items[index],
          onTap: () => _select(items[index]),
        ),
      ],
    ];
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: kBodyStyle.copyWith(color: kTextLight)),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: kSmallStyle.copyWith(color: kOrangeMain),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
