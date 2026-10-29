import 'enums.dart';

// دواء ضمن قائمة المستودع — مُدمَج ببيانات الكاتلوغ للعرض المباشر.
class WarehouseMedicine {
  final String id;
  final String catalogItemId;

  /// كود ساكو من الكتالوج الوطني — مرجع الصنف المعتمد.
  /// فارغ إن كان الخادم أقدم من إضافة الحقل، فيُخفى سطره بدل أن يظهر فارغاً.
  final String sakoCode;
  final String brandName;
  final String brandNameArabic;
  final String genericName;
  final double strength;
  final DosageForm dosageForm;
  final String manufacturerName;

  /// سعر المستودع لهذا الصنف — null يعني «لم يُحدَّد سعر»، فلا يظهر الصنف
  /// في البحث المقارن عند الصيدليات ويبقى في القائمة الداخلية.
  final double? price;

  final DateTime createdOn;

  WarehouseMedicine({
    required this.id,
    required this.catalogItemId,
    this.sakoCode = '',
    required this.brandName,
    required this.brandNameArabic,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.manufacturerName,
    this.price,
    required this.createdOn,
  });

  factory WarehouseMedicine.fromJson(Map<String, dynamic> j) => WarehouseMedicine(
        id: j['id'] as String,
        catalogItemId: j['catalogItemId'] as String,
        sakoCode: j['sakoCode'] as String? ?? '',
        brandName: j['brandName'] as String? ?? '',
        brandNameArabic: j['brandNameArabic'] as String? ?? '',
        genericName: j['genericName'] as String? ?? '',
        strength: (j['strength'] as num?)?.toDouble() ?? 0,
        dosageForm: DosageForm.fromCode(j['dosageForm'] as int? ?? 1),
        manufacturerName: j['manufacturerName'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble(),
        createdOn: DateTime.parse(j['createdOn'] as String),
      );

  String get displayName => brandNameArabic.isNotEmpty ? brandNameArabic : brandName;
}
