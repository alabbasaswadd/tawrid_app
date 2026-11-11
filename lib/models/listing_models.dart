import 'enums.dart';

class ListingSummary {
  final String id;
  final String medicineName;
  final double quantity;
  final String unit;
  final double askingPrice;
  final PharmacyListingStatus status;
  final ListingBuyerType buyerType;
  final DateTime expiresAt;
  final DateTime createdOn;

  ListingSummary({
    required this.id,
    required this.medicineName,
    required this.quantity,
    required this.unit,
    required this.askingPrice,
    required this.status,
    required this.buyerType,
    required this.expiresAt,
    required this.createdOn,
  });

  factory ListingSummary.fromJson(Map<String, dynamic> j) => ListingSummary(
        id: j['id'] as String,
        medicineName: j['medicineName'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        unit: j['unit'] as String,
        askingPrice: (j['askingPrice'] as num).toDouble(),
        status: PharmacyListingStatus.fromCode(j['status'] as int),
        buyerType: ListingBuyerType.fromCode(j['buyerType'] as int),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        createdOn: DateTime.parse(j['createdOn'] as String),
      );
}

class ListingDetail {
  final String id;
  final String medicineName;
  final String? catalogItemId;
  final double quantity;
  final String unit;
  final double askingPrice;
  final String? description;
  final PharmacyListingStatus status;
  final ListingBuyerType buyerType;
  final DateTime expiresAt;
  final DateTime createdOn;

  ListingDetail({
    required this.id,
    required this.medicineName,
    this.catalogItemId,
    required this.quantity,
    required this.unit,
    required this.askingPrice,
    this.description,
    required this.status,
    required this.buyerType,
    required this.expiresAt,
    required this.createdOn,
  });

  factory ListingDetail.fromJson(Map<String, dynamic> j) => ListingDetail(
        id: j['id'] as String,
        medicineName: j['medicineName'] as String,
        catalogItemId: j['catalogItemId'] as String?,
        quantity: (j['quantity'] as num).toDouble(),
        unit: j['unit'] as String,
        askingPrice: (j['askingPrice'] as num).toDouble(),
        description: j['description'] as String?,
        status: PharmacyListingStatus.fromCode(j['status'] as int),
        buyerType: ListingBuyerType.fromCode(j['buyerType'] as int),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        createdOn: DateTime.parse(j['createdOn'] as String),
      );
}
