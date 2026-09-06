import 'package:flutter/material.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/notification_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
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

  bool _unreadOnly = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAll = false;
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
      final page = await _repository.getNotifications(unreadOnly: _unreadOnly);
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
      final page = await _repository.getNotifications(
        cursor: _nextCursor,
        unreadOnly: _unreadOnly,
      );
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
          if (index >= 0) {
            if (_unreadOnly) {
              _items.removeAt(index);
            } else {
              _items[index] = selected;
            }
          }
        });
      } on LeafieApiException catch (error) {
        _showError(error.message);
        return;
      }
    }
    widget.onNotificationSelected?.call(selected);
  }

  Future<void> _markAllRead() async {
    if (_markingAll || !_items.any((item) => !item.isRead)) return;
    setState(() => _markingAll = true);
    try {
      await _repository.markAllRead();
      if (!mounted) return;
      final readAt = DateTime.now();
      setState(() {
        if (_unreadOnly) {
          _items.clear();
        } else {
          for (var index = 0; index < _items.length; index++) {
            if (!_items[index].isRead) {
              _items[index] = _items[index].copyWith(readAt: readAt);
            }
          }
        }
      });
    } on LeafieApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
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
      appBar: YesoAppBar(
        title: '알림',
        actions: [
          TextButton(
            key: const Key('notification-read-all'),
            onPressed: _markingAll ? null : _markAllRead,
            child: Text(
              '전체 읽음',
              style: kSmallStyle.copyWith(
                color: _markingAll ? kTextLight : kOrangeMain,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _NotificationFilter(
              unreadOnly: _unreadOnly,
              onChanged: (value) {
                if (_unreadOnly == value) return;
                setState(() => _unreadOnly = value);
                _load();
              },
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kOrangeMain));
    }
    if (_errorMessage != null) {
      return _NotificationMessage(
        icon: Icons.wifi_off_rounded,
        message: _errorMessage!,
        actionLabel: '다시 시도',
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return _NotificationMessage(
        icon: Icons.notifications_none_rounded,
        message: _unreadOnly ? '읽지 않은 알림이 없어요.' : '도착한 알림이 없어요.',
      );
    }
    return RefreshIndicator(
      color: kOrangeMain,
      onRefresh: _load,
      child: ListView.separated(
        key: const Key('notification-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
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
            );
          }
          final notification = _items[index];
          return _NotificationTile(
            notification: notification,
            onTap: () => _select(notification),
          );
        },
      ),
    );
  }
}

class _NotificationFilter extends StatelessWidget {
  const _NotificationFilter({
    required this.unreadOnly,
    required this.onChanged,
  });

  final bool unreadOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Row(
        children: [
          _FilterChip(
            label: '전체',
            selected: !unreadOnly,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '안 읽음',
            selected: unreadOnly,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kOrangeMain : kBackgroundWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? kOrangeMain : kGrayLightest),
        ),
        child: Text(
          label,
          style: kSmallStyle.copyWith(
            color: selected ? Colors.white : kTextDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationData notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Material(
      color: unread ? kProfileCardYellow : kBackgroundWhite,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('notification-${notification.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unread ? const Color(0xFFFFE7A9) : const Color(0xFFF0F0F0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: unread ? Colors.white : const Color(0xFFF7F7F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconFor(notification.type),
                  color: kOrangeMain,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: kItemStyle,
                          ),
                        ),
                        if (unread)
                          Container(
                            key: Key('unread-${notification.id}'),
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: kBrightOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: kSmallStyle.copyWith(
                        color: const Color(0xFF747474),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _timeLabel(notification.createdAt),
                      style: kCaptionStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String type) {
    final normalized = type.toUpperCase();
    if (normalized.contains('WATER')) return Icons.water_drop_outlined;
    if (normalized.contains('FERTIL')) return Icons.compost_outlined;
    if (normalized.contains('DIAGNOS')) return Icons.health_and_safety_outlined;
    return Icons.notifications_none_rounded;
  }

  static String _timeLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    if (date == today) {
      final hour = local.hour == 0
          ? 12
          : (local.hour > 12 ? local.hour - 12 : local.hour);
      final minute = local.minute.toString().padLeft(2, '0');
      return '${local.hour < 12 ? '오전' : '오후'} $hour:$minute';
    }
    return '${local.month}월 ${local.day}일';
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: kGrayLightest),
          const SizedBox(height: 14),
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
