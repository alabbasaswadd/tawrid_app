// نماذج الإشعارات — تقابل NotificationDto و NotificationSettingDto في الخادم.
//
// ملاحظة مقصودة: النوع يُقرأ كرقم **ويُحتفظ به كما هو** حتى لو كان مجهولاً،
// فنوع إشعار جديد في الخادم لا يُسقِط الصندوق ولا يختفي من الشاشة — يظهر
// بنصّه القادم من الخادم. الخادم هو مصدر العناوين والأوصاف في الإعدادات،
// فإضافة نوع هناك تظهر هنا بلا تحديث للتطبيق.

// الأنواع المعروفة للتطبيق — تُستخدم للتوجيه عند النقر فقط، لا للعرض.
enum NotificationType {
  supplyOrderStatusChanged(1),
  supplyOrderCreated(2),
  quotationRequestAwarded(3),
  newSalesOffer(4),
  newSupplyOrder(5),
  newQuotation(6),
  newQuotationRequest(7),
  newComment(8),
  general(99),
  unknown(-1);

  const NotificationType(this.code);
  final int code;

  static NotificationType fromCode(int code) => NotificationType.values
      .firstWhere((e) => e.code == code, orElse: () => NotificationType.unknown);
}

class AppNotification {
  final String id;
  final NotificationType type;
  final int typeCode;
  final String title;
  final String body;

  /// معرّف الكيان المقصود — يُقرأ مع [type] لفتح الشاشة الصحيحة.
  final String? referenceId;

  final bool isRead;
  final DateTime? readAt;
  final DateTime createdOn;

  const AppNotification({
    required this.id,
    required this.type,
    required this.typeCode,
    required this.title,
    required this.body,
    this.referenceId,
    required this.isRead,
    this.readAt,
    required this.createdOn,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final code = j['type'] as int;
    return AppNotification(
      id: j['id'] as String,
      type: NotificationType.fromCode(code),
      typeCode: code,
      title: j['title'] as String,
      body: j['body'] as String,
      referenceId: j['referenceId'] as String?,
      isRead: j['isRead'] as bool,
      readAt: j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String),
      createdOn: DateTime.parse(j['createdOn'] as String),
    );
  }

  AppNotification copyWith({bool? isRead, DateTime? readAt}) => AppNotification(
        id: id,
        type: type,
        typeCode: typeCode,
        title: title,
        body: body,
        referenceId: referenceId,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
        createdOn: createdOn,
      );
}

class NotificationSetting {
  final int typeCode;

  /// اسم النوع النصّي من الخادم — أثبت من الرقم عند المطابقة.
  final String code;
  final String label;
  final String description;

  /// هل يصل تنبيه فوري؟ (الصندوق يُكتب دائماً مهما كانت القيمة)
  final bool pushEnabled;

  /// false لأنواع النظام التي لا تُعطَّل — تُعرض مقفلة.
  final bool configurable;

  const NotificationSetting({
    required this.typeCode,
    required this.code,
    required this.label,
    required this.description,
    required this.pushEnabled,
    required this.configurable,
  });

  factory NotificationSetting.fromJson(Map<String, dynamic> j) => NotificationSetting(
        typeCode: j['type'] as int,
        code: j['code'] as String? ?? '',
        label: j['label'] as String? ?? '',
        description: j['description'] as String? ?? '',
        pushEnabled: j['pushEnabled'] as bool,
        configurable: j['configurable'] as bool? ?? true,
      );

  NotificationSetting copyWith({bool? pushEnabled}) => NotificationSetting(
        typeCode: typeCode,
        code: code,
        label: label,
        description: description,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        configurable: configurable,
      );
}
