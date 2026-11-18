import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/notifications/notification_routing.dart';
import 'package:tawrid_app/models/notification_models.dart';
import 'package:tawrid_app/repositories/notification_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// صندوق الإشعارات — شاشة واحدة للجهتين، يفرّق بينهما `isWarehouse` فقط
// (يحدّد بادئة المسار، ومعها يختار الـinterceptor التوكن الصحيح).
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({required this.isWarehouse, super.key});

  final bool isWarehouse;

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  List<AppNotification>? _items;
  bool _loading = true;
  bool _busy = false;
  bool _unreadOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await notificationRepositoryOf(
        ref,
        widget.isWarehouse,
      ).getNotifications(unreadOnly: _unreadOnly, limit: 50);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
      // كل زيارة للصندوق تُعيد مزامنة شارة الجرس مع الواقع، فلا تبقى
      // الشارة معلّقة على عدد قديم إن وصلت إشعارات والتطبيق مفتوح.
      invalidateUnreadCount(ref, widget.isWarehouse);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  // التعليم كمقروء يُطبَّق محلياً فوراً ثم يُرسل — الشبكة لا تؤخّر إحساس
  // الاستجابة، وفشلها يُعيد الحالة إلى ما كانت عليه.
  /// يُعلّم إشعارات المجموعة كلها مقروءة لا الأحدث وحدها: المستخدم فتح
  /// المحادثة فقرأ ما فيها جميعاً، وإبقاء البقية غير مقروءة يُبقي العدّاد
  /// منتفخاً على رسائل رآها.
  Future<void> _markRead(Iterable<AppNotification> group) async {
    final unread = group.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    final ids = unread.map((n) => n.id).toSet();
    final before = _items;
    final now = DateTime.now();

    setState(
      () => _items = _items
          ?.map(
            (e) =>
                ids.contains(e.id) ? e.copyWith(isRead: true, readAt: now) : e,
          )
          .toList(),
    );

    try {
      final repo = notificationRepositoryOf(ref, widget.isWarehouse);
      await Future.wait(ids.map(repo.markRead));
      if (mounted) invalidateUnreadCount(ref, widget.isWarehouse);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = before);
      AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _busy = true);
    try {
      final affected = await notificationRepositoryOf(
        ref,
        widget.isWarehouse,
      ).markAllRead();
      if (!mounted) return;
      invalidateUnreadCount(ref, widget.isWarehouse);
      AppSnackbar.success(
        context,
        affected == 0
            ? 'لا إشعارات غير مقروءة'
            : 'عُلِّم $affected إشعاراً كمقروء',
      );
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // الوجهة تُقرأ من النوع + referenceId. ما لا وجهة له (أو لا معرّف معه)
  // يُعلَّم كمقروء فقط — أفضل من فتح شاشة خاطئة.
  //
  // الوجهة هي الكيان نفسه لا قائمته: الإشعار يحمل referenceId للطلبية
  // المعنيّة، وإنزال المستخدم في قائمة ليبحث فيها عمّا أُشعِر به يُهدر
  // المعلومة التي أرسلها الخادم أصلاً.
  void _openTarget(AppNotification n) {
    final destination = notificationDestination(
      type: n.type,
      referenceId: n.referenceId,
      isWarehouse: widget.isWarehouse,
      // عنوان إشعار الرسالة هو اسم المُرسِل — يصلح عنواناً لشاشة المحادثة.
      title: n.title,
    );
    if (destination != null) context.push(destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'تعليم الكل كمقروء',
            onPressed: _loading || _busy ? null : _markAllRead,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'إعدادات الإشعارات',
            onPressed: () => context.push(
              widget.isWarehouse
                  ? TRoutes.whNotificationSettings
                  : TRoutes.phNotificationSettings,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final items = _items ?? const <AppNotification>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('الكل'),
                selected: !_unreadOnly,
                onSelected: (_) {
                  if (!_unreadOnly) return;
                  setState(() => _unreadOnly = false);
                  _load();
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(
                label: const Text('غير المقروء'),
                selected: _unreadOnly,
                onSelected: (_) {
                  if (_unreadOnly) return;
                  setState(() => _unreadOnly = true);
                  _load();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: AppSpacing.x3l),
                    EmptyState(
                      icon: Icons.notifications_none,
                      message: _unreadOnly
                          ? 'لا إشعارات غير مقروءة'
                          : 'لا إشعارات بعد — ستصلك هنا تحديثات الطلبيات '
                                'وطلبات التسعير والعروض',
                    ),
                  ],
                )
              : Builder(
                  builder: (_) {
                    final groups = _groupByThread(items);
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xs,
                        AppSpacing.lg,
                        AppSpacing.x3l,
                      ),
                      itemCount: groups.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final g = groups[i];
                        return _NotificationTile(
                          notification: g.latest,
                          count: g.items.length,
                          groupUnread: g.hasUnread,
                          onTap: () async {
                            await _markRead(g.items);
                            if (mounted) _openTarget(g.latest);
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// صفٌّ واحد في الشاشة: إشعار مفرد، أو عدّة إشعارات لخيط واحد.
class _NotificationGroup {
  _NotificationGroup(AppNotification first) : items = [first];

  /// مرتَّبة كما وصلت — الأحدث أولاً، فالأول هو ما يُعرَض.
  final List<AppNotification> items;

  AppNotification get latest => items.first;
  bool get hasUnread => items.any((n) => !n.isRead);
}

/// يجمع إشعارات الرسائل الواردة من الطرف نفسه في صفّ واحد.
///
/// المفتاح `referenceId` وهو معرّف المحادثة (أو الطلبية). والمحادثة علاقة
/// بين طرفين، فالتجميع به هو بعينه التجميع حسب الصيدلية أو المستودع — بلا
/// حقل إضافي ولا تغيير في قاعدة البيانات.
///
/// التجميع عرضٌ لا تخزين: الصفوف تبقى في الخادم كما هي، فلا يضيع «متى وصلت
/// كل رسالة». وبقية الأنواع تمرّ مفردة — خمس طلبيات تغيّرت حالاتها خمسة
/// أحداث مستقلة لا حدثٌ مكرّر.
List<_NotificationGroup> _groupByThread(List<AppNotification> items) {
  const groupable = {
    NotificationType.newDirectMessage,
    NotificationType.newOrderMessage,
  };

  final byKey = <String, _NotificationGroup>{};
  final out = <_NotificationGroup>[];

  for (final n in items) {
    final id = n.referenceId;
    final canGroup = groupable.contains(n.type) && id != null && id.isNotEmpty;

    if (!canGroup) {
      out.add(_NotificationGroup(n));
      continue;
    }

    // النوع جزء من المفتاح: رسالة طلبية ورسالة محادثة قد تتشاركان معرّفاً
    // دون أن تكونا الخيط نفسه.
    final key = '${n.typeCode}:$id';
    final existing = byKey[key];

    if (existing == null) {
      // موضع المجموعة في القائمة يحدّده أحدثُ إشعاراتها — وهو أوّل ما يُرى.
      final group = _NotificationGroup(n);
      byKey[key] = group;
      out.add(group);
    } else {
      existing.items.add(n);
    }
  }

  return out;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    this.count = 1,
    this.groupUnread,
  });

  /// الإشعار المُمثِّل للصفّ — أحدث ما في المجموعة.
  final AppNotification notification;
  final VoidCallback onTap;

  /// عدد إشعارات الخيط المُجمَّعة في هذا الصفّ.
  final int count;

  /// حالة المجموعة لا الإشعار المفرد: صفٌّ فيه رسالة غير مقروءة واحدة
  /// يبقى غير مقروء ولو قُرئت بقيّته.
  final bool? groupUnread;

  IconData get _icon => switch (notification.type) {
    NotificationType.supplyOrderStatusChanged ||
    NotificationType.supplyOrderCreated ||
    NotificationType.newSupplyOrder => Icons.local_shipping_outlined,
    NotificationType.quotationRequestAwarded ||
    NotificationType.newQuotation ||
    NotificationType.newQuotationRequest => Icons.request_quote_outlined,
    NotificationType.newSalesOffer => Icons.sell_outlined,
    NotificationType.warehouseAnnouncement => Icons.campaign_outlined,
    NotificationType.newComment ||
    NotificationType.newOrderMessage ||
    NotificationType.newDirectMessage => Icons.chat_bubble_outline,
    NotificationType.general ||
    NotificationType.unknown => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final unread = groupUnread ?? !notification.isRead;

    return AppCard(
      onTap: onTap,
      // غير المقروء يُميَّز بالسطح والنقطة معاً، لا باللون وحده.
      color: unread ? tk.brandSurface : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surface,
              shape: BoxShape.circle,
              border: Border.all(color: cs.outline),
            ),
            child: Icon(_icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: context.text.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // عدد رسائل الخيط — يسبق نقطة «غير مقروء» فيُقرأ معها.
                    if (count > 1)
                      Container(
                        margin: const EdgeInsets.only(right: AppSpacing.xs),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        constraints: const BoxConstraints(minWidth: 20),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: context.text.labelSmall?.copyWith(
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(
                          top: 4,
                          right: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: tk.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(notification.body, style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatSmartTimestamp(notification.createdOn),
                  style: context.text.labelSmall?.copyWith(color: tk.hint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
