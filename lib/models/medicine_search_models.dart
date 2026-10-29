import 'enums.dart';

// نتائج البحث المقارن عن دواء (`GET /tawrid-api/medicines/search`).
//
// الصفّ الواحد إمّا صنف ضمن عرض بيع ساري وإمّا سعر مباشر من قائمة أدوية
// مستودع. الصنف نفسه قد يظهر مرتين — من المصدرين — وهذا مقصود: شروط العرض
// (بونص، حسم، صلاحية) تجعله خياراً مختلفاً عن السعر المباشر ولو تساوى
// الرقمان.

enum MedicineSearchSource {
  all(1, 'الكل'),
  offersOnly(2, 'العروض فقط');

  const MedicineSearchSource(this.code, this.label);
  final int code;
  final String label;
}

enum MedicineSearchSort {
  // المصدر أولاً (العروض ثم التسعير المباشر) ثم السعر ضمن كل مجموعة.
  byDefault(1, 'الافتراضي'),
  priceLowToHigh(2, 'الأقل سعراً'),
  // يتطلّب موقعاً مسجَّلاً للصيدلية، وإلا ردّ الخادم برسالة صريحة.
  nearest(3, 'الأقرب');

  const MedicineSearchSort(this.code, this.label);
  final int code;
  final String label;
}

enum MedicineResultType {
  offer(1),
  warehouseListing(2);

  const MedicineResultType(this.code);
  final int code;

  static MedicineResultType fromCode(int? code) =>
      MedicineResultType.values.firstWhere(
        (e) => e.code == code,
        orElse: () => MedicineResultType.warehouseListing,
      );
}

class MedicineSearchResult {
  final MedicineResultType resultType;

  // ── مصدر العروض فقط ────────────────────────────────────────────────
  final String? salesOfferId;
  final String? salesOfferTitle;
  final String? salesOfferItemId;
  final DateTime? offerExpiresAt;
  final double? discountPercentage;
  final double? bonusPercentage;
  final double? availableQuantity;

  // ── التسعير المباشر فقط ────────────────────────────────────────────
  final String? warehouseMedicineId;

  // ── المستودع ───────────────────────────────────────────────────────
  final String supplyWarehouseId;
  final String warehouseName;
  final String city;
  final String governorate;
  final double? distanceKm;

  /// حدّ المستودع الأدنى للطلبية الواحدة — تعرضه السلّة قبل الإتمام.
  final double? minimumOrderAmount;

  // ── السعر ──────────────────────────────────────────────────────────
  /// null في نتائج التسعير المباشر وحدها: المستودع يتعامل بالصنف ولم يضع
  /// له سعراً بعد — يُعرَض ليُعرَف أنه متوفّر لديه، ولا يُضاف إلى السلّة.
  final double? unitPrice;

  /// السعر بعد الحسم — هو ما يُثبَّت في السلّة وما رتّب به الخادم.
  final double? netUnitPrice;

  /// هل للصنف سعر يصلح للإضافة إلى السلّة؟ نتائج العروض دائماً نعم.
  final bool hasPrice;

  /// السعر مشتقٌّ تلقائياً (٧٤٪ من سعر المستهلك) لأن المستودع لم يُدخله
  /// يدوياً. سعرٌ فعلي يُشترى به، لكن تمييزه يهمّ الصيدلي.
  final bool isDerivedPrice;
  final String currency;
  final String unit;

  // ── الدواء ─────────────────────────────────────────────────────────
  final String medicineName;
  final String? catalogItemId;
  final String brandName;
  final String brandNameArabic;
  final String genericName;
  final DosageForm? dosageForm;
  final double? strength;
  final String manufacturerName;

  const MedicineSearchResult({
    required this.resultType,
    this.salesOfferId,
    this.salesOfferTitle,
    this.salesOfferItemId,
    this.offerExpiresAt,
    this.discountPercentage,
    this.bonusPercentage,
    this.availableQuantity,
    this.warehouseMedicineId,
    required this.supplyWarehouseId,
    required this.warehouseName,
    required this.city,
    required this.governorate,
    this.distanceKm,
    this.minimumOrderAmount,
    this.unitPrice,
    this.netUnitPrice,
    this.hasPrice = true,
    this.isDerivedPrice = false,
    required this.currency,
    required this.unit,
    required this.medicineName,
    this.catalogItemId,
    this.brandName = '',
    this.brandNameArabic = '',
    this.genericName = '',
    this.dosageForm,
    this.strength,
    this.manufacturerName = '',
  });

  factory MedicineSearchResult.fromJson(Map<String, dynamic> j) {
    double? d(String key) => (j[key] as num?)?.toDouble();
    return MedicineSearchResult(
      resultType: MedicineResultType.fromCode(j['resultType'] as int?),
      salesOfferId: j['salesOfferId'] as String?,
      salesOfferTitle: j['salesOfferTitle'] as String?,
      salesOfferItemId: j['salesOfferItemId'] as String?,
      offerExpiresAt: j['offerExpiresAt'] == null
          ? null
          : DateTime.parse(j['offerExpiresAt'] as String),
      discountPercentage: d('discountPercentage'),
      bonusPercentage: d('bonusPercentage'),
      availableQuantity: d('availableQuantity'),
      warehouseMedicineId: j['warehouseMedicineId'] as String?,
      supplyWarehouseId: j['supplyWarehouseId'] as String,
      warehouseName: j['warehouseName'] as String? ?? '',
      city: j['city'] as String? ?? '',
      governorate: j['governorate'] as String? ?? '',
      distanceKm: d('distanceKm'),
      minimumOrderAmount: d('minimumOrderAmount'),
      unitPrice: d('unitPrice'),
      // خادم أقدم من إضافة الحقل: نعود إلى السعر المعلن بدل صفر صامت.
      netUnitPrice: d('netUnitPrice') ?? d('unitPrice'),
      // خادم أقدم لا يرسل العلَم: وجود سعر هو الدليل.
      hasPrice: j['hasPrice'] as bool? ?? (j['netUnitPrice'] ?? j['unitPrice']) != null,
      isDerivedPrice: j['isDerivedPrice'] as bool? ?? false,
      currency: j['currency'] as String? ?? 'SYP',
      unit: j['unit'] as String? ?? 'عبوة',
      medicineName: j['medicineName'] as String? ?? '',
      catalogItemId: j['catalogItemId'] as String?,
      brandName: j['brandName'] as String? ?? '',
      brandNameArabic: j['brandNameArabic'] as String? ?? '',
      genericName: j['genericName'] as String? ?? '',
      dosageForm: j['dosageForm'] == null
          ? null
          : DosageForm.fromCode(j['dosageForm'] as int),
      strength: d('strength'),
      manufacturerName: j['manufacturerName'] as String? ?? '',
    );
  }

  bool get isOffer => resultType == MedicineResultType.offer;

  /// صنف يتعامل به المستودع بلا سعر معلن — يُعرَض ولا يُضاف إلى السلّة.
  bool get isUnpriced => !hasPrice || netUnitPrice == null;

  /// «أموكسيسيلين · كبسولات ٥٠٠» — السطر الثانوي تحت اسم الدواء.
  String get specLine => [
    if (genericName.isNotEmpty) genericName,
    if (dosageForm != null)
      strength != null && strength! > 0
          ? '${dosageForm!.label} ${strength!.toStringAsFixed(0)}'
          : dosageForm!.label,
  ].join(' · ');

  /// «مستودع الشفاء — دمشق».
  String get warehouseLabel =>
      city.isEmpty ? warehouseName : '$warehouseName — $city';
}
