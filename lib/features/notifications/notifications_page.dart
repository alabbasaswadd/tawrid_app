import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
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
      final list = await notificationRepositoryOf(ref, widget.isWarehouse)
          .getNotifications(unreadOnly: _unreadOnly, limit: 50);
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
  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    final before = _items;
    setState(() => _items = _items
        ?.map((e) => e.id == n.id ? e.copyWith(isRead: true, readAt: DateTime.now()) : e)
        .toList());
    try {
      await notificationRepositoryOf(ref, widget.isWarehouse).markRead(n.id);
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
      final affected =
          await notificationRepositoryOf(ref, widget.isWarehouse).markAllRead();
      if (!mounted) return;
      invalidateUnreadCount(ref, widget.isWarehouse);
      AppSnackbar.success(
          context, affected == 0 ? 'لا إشعارات غير مقروءة' : 'عُلِّم $affected إشعاراً كمقروء');
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // الوجهة تُقرأ من النوع + referenceId. ما لا وجهة له (أو لا معرّف معه)
  // يُعلَّم كمقروء فقط — أفضل من فتح شاشة خاطئة.
  void _openTarget(AppNotification n) {
    final ref0 = n.referenceId;
    if (ref0 == null) return;

    final wh = widget.isWarehouse;
    final destination = switch (n.type) {
      NotificationType.supplyOrderStatusChanged ||
      NotificationType.supplyOrderCreated =>
        wh ? TRoutes.whOrders : TRoutes.phOrders,
      NotificationType.newSupplyOrder => wh ? TRoutes.whOrders : null,
      NotificationType.quotationRequestAwarded ||
      NotificationType.newQuotationRequest =>
        wh ? TRoutes.whTenders : null,
      NotificationType.newQuotation => wh ? null : TRoutes.phTenders,
      NotificationType.newSalesOffer => wh ? TRoutes.whOffers : TRoutes.phOffers,
      NotificationType.newComment ||
      NotificationType.general ||
      NotificationType.unknown =>
        null,
    };

    if (destination != null) context.go(destination);
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
                widget.isWarehouse ? TRoutes.whNotificationSettings : TRoutes.phNotificationSettings),
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
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
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
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.x3l),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _NotificationTile(
                    notification: items[i],
                    onTap: () async {
                      await _markRead(items[i]);
                      if (mounted) _openTarget(items[i]);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
        NotificationType.supplyOrderStatusChanged ||
        NotificationType.supplyOrderCreated ||
        NotificationType.newSupplyOrder =>
          Icons.local_shipping_outlined,
        NotificationType.quotationRequestAwarded ||
        NotificationType.newQuotation ||
        NotificationType.newQuotationRequest =>
          Icons.request_quote_outlined,
        NotificationType.newSalesOffer => Icons.sell_outlined,
        NotificationType.newComment => Icons.chat_bubble_outline,
        NotificationType.general || NotificationType.unknown =>
          Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final unread = !notification.isRead;

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
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4, right: AppSpacing.xs),
                        decoration:
                            BoxDecoration(color: tk.danger, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(notification.body, style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(formatSmartTimestamp(notification.createdOn),
                    style: context.text.labelSmall?.copyWith(color: tk.hint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
