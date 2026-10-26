import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/notification_models.dart';

// صندوق الإشعارات متطابق في الجهتين، والفرق هو بادئة المسار فقط؛ لذلك
// مستودع واحد بعلم `isWarehouse` بدل نسخة لكل جهة. مُعرّفان منفصلان بدل
// family حتى تبقى مواضع الاستدعاء صريحة: من يقرأ المزوّد يعرف أي صندوق.
final phNotificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider), isWarehouse: false),
);

final whNotificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider), isWarehouse: true),
);

NotificationRepository notificationRepositoryOf(WidgetRef ref, bool isWarehouse) =>
    ref.read(isWarehouse
        ? whNotificationRepositoryProvider
        : phNotificationRepositoryProvider);

// عدّاد غير المقروء لشارة الجرس. يُبطَل (invalidate) بعد كل قراءة أو تعليم
// كمقروء بدل تمرير العدد يدوياً بين الشاشات.
final phUnreadCountProvider = FutureProvider<int>(
  (ref) => ref.watch(phNotificationRepositoryProvider).getUnreadCount(),
);

final whUnreadCountProvider = FutureProvider<int>(
  (ref) => ref.watch(whNotificationRepositoryProvider).getUnreadCount(),
);

void invalidateUnreadCount(WidgetRef ref, bool isWarehouse) =>
    ref.invalidate(isWarehouse ? whUnreadCountProvider : phUnreadCountProvider);

class NotificationRepository {
  NotificationRepository(this._api, {required this.isWarehouse});

  final ApiClient _api;
  final bool isWarehouse;

  Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 30,
    int offset = 0,
  }) async {
    final raw = await _api.get(
      ApiEndpoints.notifications(isWarehouse),
      queryParameters: {
        'unreadOnly': unreadOnly,
        'limit': limit,
        'offset': offset,
      },
    );
    final data = ApiClient.itemsOf(raw);
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final data = await _api.get(ApiEndpoints.notificationsUnreadCount(isWarehouse));
    return (data as num).toInt();
  }

  Future<void> markRead(String id) =>
      _api.post(ApiEndpoints.notificationRead(isWarehouse, id));

  /// يُرجع عدد ما تأثّر فعلياً.
  Future<int> markAllRead() async {
    final data = await _api.post(ApiEndpoints.notificationsReadAll(isWarehouse));
    return (data as num?)?.toInt() ?? 0;
  }

  // ── الإعدادات ────────────────────────────────────────────────────────
  // القائمة تُبنى من كتالوج الخادم (العنوان والوصف يأتيان منه)، فنوع إشعار
  // جديد يظهر في الشاشة بلا تحديث للتطبيق.

  Future<List<NotificationSetting>> getSettings() async {
    final raw = await _api.get(ApiEndpoints.notificationSettings(isWarehouse));
    final data = ApiClient.itemsOf(raw);
    return data
        .map((e) => NotificationSetting.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// تعديل دفعةً واحدة — يُرجع القائمة كاملةً بعد التعديل.
  Future<List<NotificationSetting>> updateSettings(
      Map<int, bool> pushByTypeCode) async {
    final raw = await _api.put(
      ApiEndpoints.notificationSettings(isWarehouse),
      data: {
        'settings': pushByTypeCode.entries
            .map((e) => {'type': e.key, 'pushEnabled': e.value})
            .toList(),
      },
    );
    final data = ApiClient.itemsOf(raw);
    return data
        .map((e) => NotificationSetting.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
