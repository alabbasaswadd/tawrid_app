import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/core/realtime/conversation_hub.dart';
import 'package:tawrid_app/models/conversation_models.dart';

final phConversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) =>
      ConversationRepository(ref.watch(apiClientProvider), isWarehouse: false),
);

final whConversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) =>
      ConversationRepository(ref.watch(apiClientProvider), isWarehouse: true),
);

final phUnreadConversationsProvider =
    AsyncNotifierProvider<PhUnreadConversations, int>(
      PhUnreadConversations.new,
    );

final whUnreadConversationsProvider =
    AsyncNotifierProvider<WhUnreadConversations, int>(
      WhUnreadConversations.new,
    );

/// عدّاد الرسائل غير المقروءة — يُقرأ من الشبكة مرّة ويُحدَّث بالأحداث.
///
/// كان FutureProvider يُبطَل عند كل رسالة، فيُطلِق `unread-count` في كل
/// مرّة — طلبُ شبكة كامل ليزيد رقمٌ نعرف زيادته من الحدث نفسه. والصدفة
/// تراقبه، فالطلب يقع فعلاً لا نظرياً.
///
/// صار يستمع إلى القناة مباشرةً: رسالة واردة تزيده، ورسالتي لا تزيده،
/// وفتحُ محادثة يُنقصه بعدد ما كان فيها.
abstract class _UnreadConversationsBase extends AsyncNotifier<int> {
  bool get isWarehouse;

  ConversationRepository get _repo => ref.read(
    isWarehouse
        ? whConversationRepositoryProvider
        : phConversationRepositoryProvider,
  );

  @override
  Future<int> build() async {
    final sub = ref.read(conversationHubProvider).messages.listen((event) {
      // رسالتي أنا تعود عبر القناة لتظهر على بقية أجهزتي — ولا تُحتسب
      // غير مقروءة عندي.
      if (event.message.isFromMe) return;
      final current = state.value;
      if (current != null) state = AsyncData(current + 1);
    });
    ref.onDispose(sub.cancel);

    return _repo.getUnreadCount();
  }

  /// يُنقص العدّاد بعد قراءة محادثة — بلا إعادة سؤال الخادم.
  void reduceBy(int count) {
    if (count <= 0) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current - count < 0 ? 0 : current - count);
  }

  /// مزامنة كاملة مع الخادم — للسحب للتحديث وبعد إقلاع الشاشة.
  Future<void> refresh() async {
    state = AsyncData(await _repo.getUnreadCount());
  }
}

class PhUnreadConversations extends _UnreadConversationsBase {
  @override
  bool get isWarehouse => false;
}

class WhUnreadConversations extends _UnreadConversationsBase {
  @override
  bool get isWarehouse => true;
}

/// يُنقص العدّاد محلياً بعد فتح محادثة كان فيها [readCount] غير مقروء.
void reduceUnreadConversations(
  WidgetRef ref, {
  required bool isWarehouse,
  required int readCount,
}) => ref
    .read(
      (isWarehouse
              ? whUnreadConversationsProvider
              : phUnreadConversationsProvider)
          .notifier,
    )
    .reduceBy(readCount);

/// مزامنة كاملة — تُستعمل عند تحميل قائمة المحادثات لا عند كل رسالة.
void invalidateUnreadConversations(
  WidgetRef ref, {
  required bool isWarehouse,
}) => ref
    .read(
      (isWarehouse
              ? whUnreadConversationsProvider
              : phUnreadConversationsProvider)
          .notifier,
    )
    .refresh();

class ConversationRepository {
  ConversationRepository(this._api, {required this.isWarehouse});

  final ApiClient _api;
  final bool isWarehouse;

  Future<List<Conversation>> getConversations() async {
    final raw = await _api.get(ApiEndpoints.conversations(isWarehouse));
    final data = ApiClient.itemsOf(raw);
    return data
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final data = await _api.get(
      ApiEndpoints.conversationsUnreadCount(isWarehouse),
    );
    return (data as num).toInt();
  }

  /// رسائل المحادثة من الأقدم إلى الأحدث داخل الصفحة.
  ///
  /// [before]: يجلب ما قبل هذا الوقت حصراً — مرّر وقت أقدم رسالة معروضة
  /// للتمرير إلى الأعلى. الافتراضي (null) يجلب أحدث صفحة.
  Future<List<ConversationMessage>> getMessages(
    String conversationId, {
    DateTime? before,
    int take = 50,
  }) async {
    final raw = await _api.get(
      ApiEndpoints.conversationMessages(isWarehouse, conversationId),
      queryParameters: {
        if (before != null) 'before': before.toUtc().toIso8601String(),
        'take': take,
      },
    );
    final data = ApiClient.itemsOf(raw);
    return data
        .map((e) => ConversationMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ConversationMessage> sendMessage(
    String conversationId,
    String content,
  ) async {
    final raw = await _api.post(
      ApiEndpoints.conversationMessages(isWarehouse, conversationId),
      data: {'content': content},
    );
    return ConversationMessage.fromJson(raw as Map<String, dynamic>);
  }

  Future<void> markRead(String conversationId) =>
      _api.post(ApiEndpoints.conversationMarkRead(isWarehouse, conversationId));

  /// يفتح محادثة مع الطرف الآخر أو يُرجع القائمة إن وُجدت.
  ///
  /// المعرّف وحده يكفي: الخادم يقرأ اسمَي الطرفين من قاعدة البيانات، ولا
  /// يقبلهما من العميل. استخدم [Conversation.otherPartyName] من النتيجة
  /// عنواناً للشاشة بدل اسم محفوظ محلياً.
  Future<Conversation> openConversation({required String otherPartyId}) async {
    final raw = await _api.post(
      ApiEndpoints.conversationOpen(isWarehouse),
      data: {'otherPartyId': otherPartyId},
    );
    return Conversation.fromJson(raw as Map<String, dynamic>);
  }
}
