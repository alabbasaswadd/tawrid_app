class WarehousePicker {
  final String id;
  final String name;
  final String code;
  final String city;
  final String governorate;
  final String phone;

  /// عدد مدن الخدمة المصرَّح بها. صفر مع [servesAllAreas] يعني أن المستودع
  /// لم يحدّد مدناً أصلاً.
  final int serviceAreaCount;

  /// مستودع لم يحدّد مدن خدمته يُعدّ خادماً للجميع — يظهر في القائمة لكن
  /// بلا التزام صريح بمدينة الصيدلية، وهذا فرق يهمّ الصيدلي.
  final bool servesAllAreas;

  final double? minimumOrderAmount;
  final String pricingCurrency;

  /// null = لا بيانات بعد (مستودع جديد)
  final double? avgAcceptanceDays;
  final double? avgDeliveryDays;

  WarehousePicker({
    required this.id,
    required this.name,
    required this.code,
    required this.city,
    required this.governorate,
    this.phone = '',
    this.serviceAreaCount = 0,
    this.servesAllAreas = false,
    this.minimumOrderAmount,
    this.pricingCurrency = 'SYP',
    this.avgAcceptanceDays,
    this.avgDeliveryDays,
  });

  factory WarehousePicker.fromJson(Map<String, dynamic> j) => WarehousePicker(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        city: j['city'] as String,
        governorate: j['governorate'] as String,
        phone: j['phone'] as String? ?? '',
        serviceAreaCount: j['serviceAreaCount'] as int? ?? 0,
        servesAllAreas: j['servesAllAreas'] as bool? ?? false,
        minimumOrderAmount: (j['minimumOrderAmount'] as num?)?.toDouble(),
        pricingCurrency: j['pricingCurrency'] as String? ?? 'SYP',
        avgAcceptanceDays: (j['avgAcceptanceDays'] as num?)?.toDouble(),
        avgDeliveryDays: (j['avgDeliveryDays'] as num?)?.toDouble(),
      );
}

// ملف المستودع كما تراه الصيدلية (WarehouseProfileDto). عام بحت: لا موظفين
// ولا طلبيات ولا بيانات حساب — ومستودع موقوف يردّ الخادم عنه «غير موجود».
class WarehouseProfile {
  final String id;
  final String name;
  final String code;
  final String phone;
  final String governorate;
  final String city;
  final String? logoUrl;
  final DateTime createdOn;

  /// بصيغة «محافظة - مدينة».
  final List<String> serviceAreas;

  /// مستودع بلا مناطق محددة يخدم الجميع.
  final bool servesAllAreas;

  final int activeOffersCount;
  final double? minimumOrderAmount;
  final String pricingCurrency;
  final double? avgAcceptanceDays;
  final double? avgDeliveryDays;

  const WarehouseProfile({
    required this.id,
    required this.name,
    required this.code,
    required this.phone,
    required this.governorate,
    required this.city,
    this.logoUrl,
    required this.createdOn,
    required this.serviceAreas,
    required this.servesAllAreas,
    required this.activeOffersCount,
    this.minimumOrderAmount,
    this.pricingCurrency = 'SYP',
    this.avgAcceptanceDays,
    this.avgDeliveryDays,
  });

  factory WarehouseProfile.fromJson(Map<String, dynamic> j) => WarehouseProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        phone: j['phone'] as String,
        governorate: j['governorate'] as String,
        city: j['city'] as String,
        logoUrl: j['logoUrl'] as String?,
        createdOn: DateTime.parse(j['createdOn'] as String),
        serviceAreas:
            ((j['serviceAreas'] as List?) ?? const []).cast<String>(),
        servesAllAreas: j['servesAllAreas'] as bool? ?? false,
        activeOffersCount: j['activeOffersCount'] as int? ?? 0,
        minimumOrderAmount: (j['minimumOrderAmount'] as num?)?.toDouble(),
        pricingCurrency: j['pricingCurrency'] as String? ?? 'SYP',
        avgAcceptanceDays: (j['avgAcceptanceDays'] as num?)?.toDouble(),
        avgDeliveryDays: (j['avgDeliveryDays'] as num?)?.toDouble(),
      );
}

class WarehouseAnnouncement {
  final String id;
  final String title;
  final String? body;
  final int discountType; // 1 = InvoicePercentage
  final double discountValue;
  final DateTime validUntil;
  final bool isActive;
  final DateTime createdOn;

  const WarehouseAnnouncement({
    required this.id,
    required this.title,
    this.body,
    required this.discountType,
    required this.discountValue,
    required this.validUntil,
    required this.isActive,
    required this.createdOn,
  });

  factory WarehouseAnnouncement.fromJson(Map<String, dynamic> j) =>
      WarehouseAnnouncement(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        discountType: j['discountType'] as int? ?? 1,
        discountValue: (j['discountValue'] as num).toDouble(),
        validUntil: DateTime.parse(j['validUntil'] as String),
        isActive: j['isActive'] as bool? ?? true,
        createdOn: DateTime.parse(j['createdOn'] as String),
      );
}
