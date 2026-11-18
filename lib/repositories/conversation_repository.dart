import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/conversation_models.dart';

final phConversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => ConversationRepository(
    ref.watch(apiClientProvider),
    isWarehouse: false,
  ),
);

final whConversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => ConversationRepository(
    ref.watch(apiClientProvider),
    isWarehouse: true,
  ),
);

final phUnreadConversationsProvider = FutureProvider<int>(
  (ref) => ref.watch(phConversationRepositoryProvider).getUnreadCount(),
);

final whUnreadConversationsProvider = FutureProvider<int>(
  (ref) => ref.watch(whConversationRepositoryProvider).getUnreadCount(),
);

void invalidateUnreadConversations(WidgetRef ref, {required bool isWarehouse}) =>
    ref.invalidate(
      isWarehouse ? whUnreadConversationsProvider : phUnreadConversationsProvider,
    );

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
