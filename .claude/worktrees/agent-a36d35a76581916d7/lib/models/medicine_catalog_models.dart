import 'enums.dart';

class MedicineCatalogItem {
  final String id;
  final String sakoCode;
  final String genericName;
  final String brandName;
  final String brandNameArabic;
  final String foreignName;
  final double strength;
  final String barcode;
  final DosageForm dosageForm;
  final String manufacturerName;
  final double pricePharmacist;
  final double pricePublic;
  final String currency;

  MedicineCatalogItem({
    required this.id,
    required this.sakoCode,
    required this.genericName,
    required this.brandName,
    required this.brandNameArabic,
    required this.foreignName,
    required this.strength,
    required this.barcode,
    required this.dosageForm,
    required this.manufacturerName,
    required this.pricePharmacist,
    required this.pricePublic,
    required this.currency,
  });

  factory MedicineCatalogItem.fromJson(Map<String, dynamic> j) => MedicineCatalogItem(
        id: j['id'] as String,
        sakoCode: j['sakoCode'] as String? ?? '',
        genericName: j['genericName'] as String? ?? '',
        brandName: j['brandName'] as String? ?? '',
        brandNameArabic: j['brandNameArabic'] as String? ?? '',
        foreignName: j['foreignName'] as String? ?? '',
        strength: (j['strength'] as num?)?.toDouble() ?? 0,
        barcode: j['barcode'] as String? ?? '',
        dosageForm: DosageForm.fromCode(j['dosageForm'] as int? ?? 1),
        manufacturerName: j['manufacturerName'] as String? ?? '',
        pricePharmacist: (j['pricePharmacist'] as num?)?.toDouble() ?? 0,
        pricePublic: (j['pricePublic'] as num?)?.toDouble() ?? 0,
        currency: j['currency'] as String? ?? 'SYP',
      );

  String get displayName => brandNameArabic.isNotEmpty ? brandNameArabic : brandName;
}
