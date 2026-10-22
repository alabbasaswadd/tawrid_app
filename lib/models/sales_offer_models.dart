import 'enums.dart';

class SalesOfferSummary {
  final String id;
  final String title;
  final SalesOfferType offerType;
  final SalesOfferStatus status;
  final String warehouseName;
  final String? targetGovernorate;
  final String? targetCity;
  final int itemCount;
  final DateTime startsAt;
  final DateTime expiresAt;
  final DateTime createdOn;

  SalesOfferSummary({
    required this.id,
    required this.title,
    required this.offerType,
    required this.status,
    required this.warehouseName,
    this.targetGovernorate,
    this.targetCity,
    required this.itemCount,
    required this.startsAt,
    required this.expiresAt,
    required this.createdOn,
  });

  factory SalesOfferSummary.fromJson(Map<String, dynamic> j) => SalesOfferSummary(
        id: j['id'] as String,
        title: j['title'] as String,
        offerType: SalesOfferType.fromCode(j['offerType'] as int),
        status: SalesOfferStatus.fromCode(j['status'] as int),
        warehouseName: j['warehouseName'] as String,
        targetGovernorate: j['targetGovernorate'] as String?,
        targetCity: j['targetCity'] as String?,
        itemCount: j['itemCount'] as int,
        startsAt: DateTime.parse(j['startsAt'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        createdOn: DateTime.parse(j['createdOn'] as String),
      );
}

class SalesOfferItem {
  final String id;
  final String medicineName;
  final String? catalogItemId;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double? discountPercentage;
  final double? bonusPercentage;

  SalesOfferItem({
    required this.id,
    required this.medicineName,
    this.catalogItemId,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.discountPercentage,
    this.bonusPercentage,
  });

  factory SalesOfferItem.fromJson(Map<String, dynamic> j) => SalesOfferItem(
        id: j['id'] as String,
        medicineName: j['medicineName'] as String,
        catalogItemId: j['catalogItemId'] as String?,
        quantity: (j['quantity'] as num).toDouble(),
        unit: j['unit'] as String,
        unitPrice: (j['unitPrice'] as num).toDouble(),
        discountPercentage: (j['discountPercentage'] as num?)?.toDouble(),
        bonusPercentage: (j['bonusPercentage'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toCreateJson() => {
        'medicineName': medicineName,
        'catalogItemId': catalogItemId,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'discountPercentage': discountPercentage,
        'bonusPercentage': bonusPercentage,
      };
}

class SalesOfferTarget {
  final String tenantId;
  final bool notificationSent;

  SalesOfferTarget({required this.tenantId, required this.notificationSent});

  factory SalesOfferTarget.fromJson(Map<String, dynamic> j) => SalesOfferTarget(
        tenantId: j['tenantId'] as String,
        notificationSent: j['notificationSent'] as bool,
      );
}

class OfferComment {
  final String id;
  final CommentAuthorType authorType;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdOn;

  OfferComment({
    required this.id,
    required this.authorType,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdOn,
  });

  factory OfferComment.fromJson(Map<String, dynamic> j) => OfferComment(
        id: j['id'] as String,
        authorType: CommentAuthorType.fromCode(j['authorType'] as int),
        authorId: j['authorId'] as String,
        authorName: j['authorName'] as String,
        content: j['content'] as String,
        createdOn: DateTime.parse(j['createdOn'] as String),
      );
}

class SalesOfferDetail {
  final String id;
  final String supplyWarehouseId;
  final String warehouseName;
  final String warehousePhone;
  final String title;
  final String? description;
  final SalesOfferType offerType;
  final SalesOfferStatus status;
  final DateTime startsAt;
  final DateTime expiresAt;
  final String? targetGovernorate;
  final String? targetCity;
  final bool isPublicInRegion;
  final double? upfrontPercentage;
  final int? paymentPeriodDays;
  final String? consignmentTerms;
  final DateTime createdOn;
  final List<SalesOfferItem> items;
  final List<SalesOfferTarget>? targets;

  SalesOfferDetail({
    required this.id,
    required this.supplyWarehouseId,
    required this.warehouseName,
    required this.warehousePhone,
    required this.title,
    this.description,
    required this.offerType,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    this.targetGovernorate,
    this.targetCity,
    required this.isPublicInRegion,
    this.upfrontPercentage,
    this.paymentPeriodDays,
    this.consignmentTerms,
    required this.createdOn,
    required this.items,
    this.targets,
  });

  factory SalesOfferDetail.fromJson(Map<String, dynamic> j) => SalesOfferDetail(
        id: j['id'] as String,
        supplyWarehouseId: j['supplyWarehouseId'] as String,
        warehouseName: j['warehouseName'] as String,
        warehousePhone: j['warehousePhone'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        offerType: SalesOfferType.fromCode(j['offerType'] as int),
        status: SalesOfferStatus.fromCode(j['status'] as int),
        startsAt: DateTime.parse(j['startsAt'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        targetGovernorate: j['targetGovernorate'] as String?,
        targetCity: j['targetCity'] as String?,
        isPublicInRegion: j['isPublicInRegion'] as bool,
        upfrontPercentage: (j['upfrontPercentage'] as num?)?.toDouble(),
        paymentPeriodDays: j['paymentPeriodDays'] as int?,
        consignmentTerms: j['consignmentTerms'] as String?,
        createdOn: DateTime.parse(j['createdOn'] as String),
        items: ((j['items'] as List?) ?? [])
            .map((e) => SalesOfferItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        targets: (j['targets'] as List?)
            ?.map((e) => SalesOfferTarget.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
