// نماذج ميزة «صيدلي إلى صيدلي» — إعلانات بيع الأدوية الكاسدة أو القاربة انتهاء
// الصلاحية بين الصيدليات.

enum PhListingReason {
  slowMoving('slow_moving', 'دواء كاسد'),
  nearExpiry('near_expiry', 'قارب انتهاء الصلاحية'),
  overstocked('overstocked', 'فائض كمية'),
  other('other', 'سبب آخر');

  const PhListingReason(this.code, this.label);
  final String code;
  final String label;

  static PhListingReason fromCode(String? code) => switch (code) {
        'slow_moving' => PhListingReason.slowMoving,
        'near_expiry' => PhListingReason.nearExpiry,
        'overstocked' => PhListingReason.overstocked,
        _ => PhListingReason.other,
      };
}

enum PhListingStatus {
  available('available', 'متاح'),
  booked('booked', 'محجوز'),
  closed('closed', 'مغلق');

  const PhListingStatus(this.code, this.label);
  final String code;
  final String label;

  static PhListingStatus fromCode(String? code) => switch (code) {
        'available' => PhListingStatus.available,
        'booked' => PhListingStatus.booked,
        _ => PhListingStatus.closed,
      };
}

enum PhBookingStatus {
  pending('pending', 'قيد الانتظار'),
  accepted('accepted', 'مقبول'),
  rejected('rejected', 'مرفوض'),
  cancelled('cancelled', 'ملغى');

  const PhBookingStatus(this.code, this.label);
  final String code;
  final String label;

  static PhBookingStatus fromCode(String? code) => switch (code) {
        'pending' => PhBookingStatus.pending,
        'accepted' => PhBookingStatus.accepted,
        'rejected' => PhBookingStatus.rejected,
        _ => PhBookingStatus.cancelled,
      };
}

/// إعلان بيع دواء كما يظهر في قائمة التصفح.
class PhListingSummary {
  final String id;
  final String medicineName;
  final String? genericName;
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

  const PhListingSummary({
    required this.id,
    required this.medicineName,
    this.genericName,
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
  });

  factory PhListingSummary.fromJson(Map<String, dynamic> j) => PhListingSummary(
        id: j['id'] as String,
        medicineName: j['medicineName'] as String,
        genericName: j['genericName'] as String?,
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
        createdOn: DateTime.parse(j['createdOn'] as String),
        pendingBookingsCount: j['pendingBookingsCount'] as int? ?? 0,
      );
}

/// حجز على إعلان — يراه صاحب الإعلان في لوحة إعلاناته.
class PhListingBooking {
  final String id;
  final String listingId;
  final String bookerPharmacyId;
  final String bookerPharmacyName;
  final String bookerPhone;
  final String initialMessage;
  final PhBookingStatus status;
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
        bookerPharmacyName: j['bookerPharmacyName'] as String,
        bookerPhone: j['bookerPhone'] as String? ?? '',
        initialMessage: j['initialMessage'] as String? ?? '',
        status: PhBookingStatus.fromCode(j['status'] as String?),
        createdOn: DateTime.parse(j['createdOn'] as String),
        unreadMessages: j['unreadMessages'] as int? ?? 0,
      );
}

/// رسالة في محادثة حجز.
class PhListingMessage {
  final String id;
  final String senderId;
  final String senderName;
  final bool isMine;
  final String content;
  final DateTime sentAt;

  const PhListingMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.isMine,
    required this.content,
    required this.sentAt,
  });

  factory PhListingMessage.fromJson(Map<String, dynamic> j, String myId) =>
      PhListingMessage(
        id: j['id'] as String,
        senderId: j['senderId'] as String,
        senderName: j['senderName'] as String,
        isMine: j['senderId'] == myId,
        content: j['content'] as String,
        sentAt: DateTime.parse(j['sentAt'] as String),
      );
}

/// طلب إنشاء إعلان جديد.
class CreatePhListingRequest {
  final String medicineName;
  final String? genericName;
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
    this.genericName,
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
        if (genericName != null) 'genericName': genericName,
        if (manufacturer != null) 'manufacturer': manufacturer,
        'quantity': quantity,
        'pricePerUnit': pricePerUnit,
        if (expiryDate != null)
          'expiryDate': expiryDate!.toIso8601String().split('T').first,
        'reason': reason.code,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'governorate': governorate,
        'city': city,
      };
}
