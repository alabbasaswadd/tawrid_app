class Conversation {
  const Conversation({
    required this.id,
    required this.otherPartyId,
    required this.otherPartyName,
    required this.otherPartyType,
    this.lastMessageText,
    required this.unreadCount,
    required this.updatedAt,
  });

  final String id;
  final String otherPartyId;
  final String otherPartyName;
  // 'pharmacy' | 'warehouse'
  final String otherPartyType;
  final String? lastMessageText;
  final int unreadCount;
  final DateTime updatedAt;

  /// نسخة معدَّلة — لتحديث الكاش محلياً بلا رحلة شبكة.
  Conversation copyWith({
    String? lastMessageText,
    int? unreadCount,
    DateTime? updatedAt,
  }) => Conversation(
    id: id,
    otherPartyId: otherPartyId,
    otherPartyName: otherPartyName,
    otherPartyType: otherPartyType,
    lastMessageText: lastMessageText ?? this.lastMessageText,
    unreadCount: unreadCount ?? this.unreadCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: j['id'] as String,
    otherPartyId: j['otherPartyId'] as String,
    otherPartyName: j['otherPartyName'] as String,
    otherPartyType: j['otherPartyType'] as String? ?? 'pharmacy',
    lastMessageText: j['lastMessageText'] as String?,
    unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );
}

/// مقتطف الرسالة المردود عليها — ما يكفي لرسم الاقتباس بلا جلب ثانٍ.
class ReplyPreview {
  const ReplyPreview({
    required this.id,
    required this.senderName,
    required this.content,
  });

  final String id;
  final String senderName;
  final String content;

  factory ReplyPreview.fromJson(Map<String, dynamic> j) => ReplyPreview(
    id: j['id'] as String,
    senderName: j['senderName'] as String? ?? '',
    content: j['content'] as String? ?? '',
  );
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.content,
    required this.isFromMe,
    required this.senderName,
    required this.createdAt,
    this.replyTo,
    this.isReadByOther = false,
    this.pending = false,
    this.failed = false,
  });

  final String id;
  final String content;
  final bool isFromMe;
  final String senderName;
  final DateTime createdAt;

  /// الرسالة المُقتبَسة — تغيب حين لا تكون هذه ردّاً.
  final ReplyPreview? replyTo;

  /// هل قرأ الطرف الآخر رسالتي؟ لا معنى لها على رسائله هو.
  final bool isReadByOther;

  /// فقاعة رُسمت قبل تأكيد الخادم — معرّفها محلّي ووقتها تقديري.
  ///
  /// حالة عميل بحتة لا تأتي من الخادم: ما يصل من الشبكة مؤكَّد بالتعريف.
  final bool pending;

  /// تعذّر إرسالها — تبقى ظاهرة ليعرف المستخدم ما لم يصل.
  final bool failed;

  /// فقاعة محلّية تظهر فور الضغط، يستبدلها ردّ الخادم.
  factory ConversationMessage.optimistic({
    required String localId,
    required String content,
    required String senderName,
    ReplyPreview? replyTo,
  }) => ConversationMessage(
    id: localId,
    content: content,
    isFromMe: true,
    senderName: senderName,
    createdAt: DateTime.now(),
    replyTo: replyTo,
    pending: true,
  );

  ConversationMessage copyWith({
    bool? pending,
    bool? failed,
    bool? isReadByOther,
  }) => ConversationMessage(
    id: id,
    content: content,
    isFromMe: isFromMe,
    senderName: senderName,
    createdAt: createdAt,
    replyTo: replyTo,
    isReadByOther: isReadByOther ?? this.isReadByOther,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
  );

  factory ConversationMessage.fromJson(Map<String, dynamic> j) =>
      ConversationMessage(
        id: j['id'] as String,
        content: j['content'] as String,
        isFromMe: j['isFromMe'] as bool? ?? false,
        senderName: j['senderName'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        isReadByOther: j['isReadByOther'] as bool? ?? false,
        replyTo: j['replyTo'] == null
            ? null
            : ReplyPreview.fromJson(
                Map<String, dynamic>.from(j['replyTo'] as Map),
              ),
      );
}
