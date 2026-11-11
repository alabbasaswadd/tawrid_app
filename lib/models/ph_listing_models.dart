// نماذج ميزة «صيدلي إلى صيدلي» — إعلانات بيع الأدوية الكاسدة أو القاربة انتهاء
// الصلاحية بين الصيدليات.
//
// التفاوض يجري بتعليقات علنية تحت الإعلان لا بحجزٍ ومحادثة خاصة: السؤال
// الواحد يُجاب مرة واحدة أمام الجميع، ولا يُقفَل الإعلان على أول طالب.

import 'enums.dart';

enum PhListingReason {
  slowMoving('slow_moving', 'دواء كاسد'),
  nearExpiry('near_expiry', 'قارب انتهاء الصلاحية'),
  overstocked('overstocked', 'فائض كمية'),
  other('other', 'سبب آخر');

  const PhListingReason(this.code, this.label);
  final String code;
  final String label;

  // الباك إند يُرسل PascalCase (SlowMoving) أو snake_case (slow_moving)
  static PhListingReason fromCode(String? code) {
    final normalized = code?.toLowerCase().replaceAll('_', '') ?? '';
    return switch (normalized) {
      'slowmoving' => PhListingReason.slowMoving,
      'nearexpiry' => PhListingReason.nearExpiry,
      'overstocked' => PhListingReason.overstocked,
      _ => PhListingReason.other,
    };
  }
}

enum PhListingStatus {
  available('available', 'متاح'),
  booked('booked', 'محجوز'),
  closed('closed', 'مغلق');

  const PhListingStatus(this.code, this.label);
  final String code;
  final String label;

  // الباك إند يُرسل PascalCase (Available, Booked) أو lowercase
  static PhListingStatus fromCode(String? code) => switch (code?.toLowerCase()) {
        'available' => PhListingStatus.available,
        'booked' => PhListingStatus.booked,
        _ => PhListingStatus.closed,
      };
}

/// إعلان بيع دواء كما يظهر في قائمة التصفح.
class PhListingSummary {
  final String id;
  final String medicineName;
  final String? manufacturer;
  final int quantity;
  final double pricePerUnit;
  final DateTime? expiryDate;
  final PhListingReason reason;
  final String? notes;
  final String governorate;
  final String city;
  final String pharmacyId;
  final String pharmacyName;
  final PhListingStatus status;
  final DateTime createdOn;
  final int pendingBookingsCount;
  /// تاريخ انتهاء الإعلان تلقائياً (3 أيام من الإنشاء إن لم يُحدَّد من الخادم).
  final DateTime listingExpiresAt;

  const PhListingSummary({
    required this.id,
    required this.medicineName,
    this.manufacturer,
    required this.quantity,
    required this.pricePerUnit,
    this.expiryDate,
    required this.reason,
    this.notes,
    required this.governorate,
    required this.city,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.status,
    required this.createdOn,
    this.pendingBookingsCount = 0,
    required this.listingExpiresAt,
  });

  /// الإعلان منتهي إذا تجاوز تاريخ الانتهاء وما زال بحالة «متاح».
  bool get isListingExpired =>
      status == PhListingStatus.available &&
      listingExpiresAt.isBefore(DateTime.now());

  factory PhListingSummary.fromJson(Map<String, dynamic> j) {
    final createdOn = DateTime.parse(j['createdOn'] as String);
    return PhListingSummary(
      id: j['id'] as String,
      medicineName: j['medicineName'] as String,
      manufacturer: j['manufacturer'] as String?,
      quantity: j['quantity'] as int,
      pricePerUnit: (j['pricePerUnit'] as num).toDouble(),
      expiryDate: j['expiryDate'] == null
          ? null
          : DateTime.tryParse(j['expiryDate'] as String),
      reason: PhListingReason.fromCode(j['reason'] as String?),
      notes: j['notes'] as String?,
      governorate: j['governorate'] as String? ?? '',
      city: j['city'] as String? ?? '',
      pharmacyId: j['pharmacyId'] as String,
      pharmacyName: j['pharmacyName'] as String,
      status: PhListingStatus.fromCode(j['status'] as String?),
      createdOn: createdOn,
      pendingBookingsCount: j['pendingBookingsCount'] as int? ?? 0,
      listingExpiresAt: j['listingExpiresAt'] != null
          ? DateTime.parse(j['listingExpiresAt'] as String)
          : createdOn.add(const Duration(days: 3)),
    );
  }
}

/// تعليق تحت إعلان — يحمل اسم الصيدلية المعلِّقة ومدينتها، فالتعليق المجهول
/// لا يُبنى عليه قرار بيع.
class PhListingComment {
  final String id;
  final CommentAuthorType authorType;
  final String authorId;
  final String authorName;
  final String authorCity;
  final String authorGovernorate;
  /// معرّف التعليق الأب — إن وُجد فهذا التعليق ردٌّ على غيره.
  final String? parentId;
  final String content;
  final DateTime createdOn;

  const PhListingComment({
    required this.id,
    required this.authorType,
    required this.authorId,
    required this.authorName,
    this.authorCity = '',
    this.authorGovernorate = '',
    this.parentId,
    required this.content,
    required this.createdOn,
  });

  factory PhListingComment.fromJson(Map<String, dynamic> j) {
    // الخادم قد يُرسل الاسم تحت authorName أو pharmacyName — نجرّب كليهما
    // ونرفض الفارغ فلا نعرض فقاعة بلا هوية.
    String resolveName(String key, [String? fallbackKey]) {
      final v = (j[key] as String?)?.trim();
      if (v != null && v.isNotEmpty) return v;
      if (fallbackKey != null) {
        final f = (j[fallbackKey] as String?)?.trim();
        if (f != null && f.isNotEmpty) return f;
      }
      return 'صيدلية';
    }

    return PhListingComment(
      id: j['id'] as String,
      authorType: CommentAuthorType.fromCode(j['authorType'] as int? ?? 1),
      authorId: (j['authorId'] as String?)?.trim() ?? '',
      authorName: resolveName('authorName', 'pharmacyName'),
      authorCity: (j['authorCity'] as String?)?.trim() ?? '',
      authorGovernorate: (j['authorGovernorate'] as String?)?.trim() ?? '',
      parentId: j['parentId'] as String?,
      content: (j['content'] as String?)?.trim() ?? '',
      createdOn: DateTime.parse(j['createdOn'] as String),
    );
  }
}

enum PhListingBookingStatus {
  pending('pending', 'قيد الانتظار'),
  accepted('accepted', 'مقبول'),
  rejected('rejected', 'مرفوض');

  const PhListingBookingStatus(this.code, this.label);
  final String code;
  final String label;

  static PhListingBookingStatus fromCode(String? code) => switch (code?.toLowerCase()) {
        'accepted' => PhListingBookingStatus.accepted,
        'rejected' => PhListingBookingStatus.rejected,
        _ => PhListingBookingStatus.pending,
      };
}

class PhListingBooking {
  final String id;
  final String listingId;
  final String bookerPharmacyId;
  final String bookerPharmacyName;
  final String bookerPhone;
  final String initialMessage;
  final PhListingBookingStatus status;
  final DateTime createdOn;
  final int unreadMessages;

  const PhListingBooking({
    required this.id,
    required this.listingId,
    required this.bookerPharmacyId,
    required this.bookerPharmacyName,
    required this.bookerPhone,
    required this.initialMessage,
    required this.status,
    required this.createdOn,
    this.unreadMessages = 0,
  });

  factory PhListingBooking.fromJson(Map<String, dynamic> j) => PhListingBooking(
        id: j['id'] as String,
        listingId: j['listingId'] as String,
        bookerPharmacyId: j['bookerPharmacyId'] as String,
        bookerPharmacyName: j['bookerPharmacyName'] as String? ?? '',
        bookerPhone: j['bookerPhone'] as String? ?? '',
        initialMessage: j['initialMessage'] as String? ?? '',
        status: PhListingBookingStatus.fromCode(j['status'] as String?),
        createdOn: DateTime.parse(j['createdOn'] as String),
        unreadMessages: j['unreadMessages'] as int? ?? 0,
      );
}

class PhListingMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime sentAt;

  const PhListingMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.sentAt,
  });

  factory PhListingMessage.fromJson(Map<String, dynamic> j) => PhListingMessage(
        id: j['id'] as String,
        senderId: j['senderId'] as String,
        senderName: j['senderName'] as String? ?? '',
        content: j['content'] as String,
        sentAt: DateTime.parse(j['sentAt'] as String),
      );
}

class CreatePhListingRequest {
  final String medicineName;
  final String? manufacturer;
  final int quantity;
  final double pricePerUnit;
  final DateTime? expiryDate;
  final PhListingReason reason;
  final String? notes;
  final String governorate;
  final String city;

  const CreatePhListingRequest({
    required this.medicineName,
    this.manufacturer,
    required this.quantity,
    required this.pricePerUnit,
    this.expiryDate,
    required this.reason,
    this.notes,
    required this.governorate,
    required this.city,
  });

  Map<String, dynamic> toJson() => {
        'medicineName': medicineName,
        if (manufacturer != null) 'manufacturer': manufacturer,
        'quantity': quantity,
        'pricePerUnit': pricePerUnit,
        if (expiryDate != null)
          'expiryDate': expiryDate!.toIso8601String().split('T').first,
        'reason': reason.code,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'governorate': governorate,
        'city': city,
        'listingExpiresAt': DateTime.now()
            .add(const Duration(days: 3))
            .toIso8601String()
            .split('T')
            .first,
      };
}
