import 'enums.dart';

class TenderSummary {
  final String id;
  final String tenderNumber;
  final String title;
  final TenderStatus status;
  final int itemCount;
  final int offerCount;
  final DateTime expiresAt;
  final DateTime createdOn;
  final bool isExpired;
  final String? tenantGovernorate;
  final String? tenantCity;

  TenderSummary({
    required this.id,
    required this.tenderNumber,
    required this.title,
    required this.status,
    required this.itemCount,
    required this.offerCount,
    required this.expiresAt,
    required this.createdOn,
    required this.isExpired,
    this.tenantGovernorate,
    this.tenantCity,
  });

  // مفاتيح الـ JSON تتبع تسمية الباك إند بعد إعادة التسمية:
  // tenderNumber → requestNumber، offerCount → quotationCount،
  // tenderItemId → quotationRequestItemId، offerType → quotationType.
  factory TenderSummary.fromJson(Map<String, dynamic> j) => TenderSummary(
        id: j['id'] as String,
        tenderNumber: j['requestNumber'] as String,
        title: j['title'] as String,
        status: TenderStatus.fromCode(j['status'] as int),
        itemCount: j['itemCount'] as int,
        offerCount: j['quotationCount'] as int,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        createdOn: DateTime.parse(j['createdOn'] as String),
        isExpired: j['isExpired'] as bool,
        tenantGovernorate: j['tenantGovernorate'] as String?,
        tenantCity: j['tenantCity'] as String?,
      );
}

class TenderItem {
  final String id;
  final String medicineName;
  final String? catalogItemId;
  final double quantity;
  final String unit;
  final String? notes;

  TenderItem({
    required this.id,
    required this.medicineName,
    this.catalogItemId,
    required this.quantity,
    required this.unit,
    this.notes,
  });

  factory TenderItem.fromJson(Map<String, dynamic> j) => TenderItem(
        id: j['id'] as String,
        medicineName: j['medicineName'] as String,
        catalogItemId: j['catalogItemId'] as String?,
        quantity: (j['quantity'] as num).toDouble(),
        unit: j['unit'] as String,
        notes: j['notes'] as String?,
      );

  Map<String, dynamic> toCreateJson() => {
        'medicineName': medicineName,
        'catalogItemId': catalogItemId,
        'quantity': quantity,
        'unit': unit,
        'notes': notes,
      };
}

class TenderOfferItem {
  final String id;
  final String tenderItemId;
  final String medicineName;
  final double? unitPrice;
  final double? bonusPercentage;
  final double? extraBonus;
  final String? notes;

  TenderOfferItem({
    required this.id,
    required this.tenderItemId,
    required this.medicineName,
    this.unitPrice,
    this.bonusPercentage,
    this.extraBonus,
    this.notes,
  });

  factory TenderOfferItem.fromJson(Map<String, dynamic> j) => TenderOfferItem(
        id: j['id'] as String,
        tenderItemId: j['quotationRequestItemId'] as String,
        medicineName: j['medicineName'] as String,
        unitPrice: (j['unitPrice'] as num?)?.toDouble(),
        bonusPercentage: (j['bonusPercentage'] as num?)?.toDouble(),
        extraBonus: (j['extraBonus'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
      );
}

class TenderOffer {
  final String id;
  final String supplyWarehouseId;
  final String warehouseName;
  final TenderOfferType offerType;
  final TenderOfferStatus status;
  final String? notes;
  final bool isSelectedByPharmacy;
  final DateTime createdOn;
  final List<TenderOfferItem> items;

  TenderOffer({
    required this.id,
    required this.supplyWarehouseId,
    required this.warehouseName,
    required this.offerType,
    required this.status,
    this.notes,
    required this.isSelectedByPharmacy,
    required this.createdOn,
    required this.items,
  });

  factory TenderOffer.fromJson(Map<String, dynamic> j) => TenderOffer(
        id: j['id'] as String,
        supplyWarehouseId: j['supplyWarehouseId'] as String,
        warehouseName: j['warehouseName'] as String,
        offerType: TenderOfferType.fromCode(j['quotationType'] as int),
        status: TenderOfferStatus.fromCode(j['status'] as int),
        notes: j['notes'] as String?,
        isSelectedByPharmacy: j['isSelectedByPharmacy'] as bool,
        createdOn: DateTime.parse(j['createdOn'] as String),
        items: ((j['items'] as List?) ?? [])
            .map((e) => TenderOfferItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TenderDetail {
  final String id;
  final String tenderNumber;
  final String title;
  final String? description;
  final TenderStatus status;
  final DateTime expiresAt;
  final DateTime createdOn;
  final String? winnerNotes;
  final bool offersVisible;
  final int offerCount;
  final List<TenderItem> items;
  final List<TenderOffer>? offers;
  final String? tenantGovernorate;
  final String? tenantCity;

  TenderDetail({
    required this.id,
    required this.tenderNumber,
    required this.title,
    this.description,
    required this.status,
    required this.expiresAt,
    required this.createdOn,
    this.winnerNotes,
    required this.offersVisible,
    required this.offerCount,
    required this.items,
    this.offers,
    this.tenantGovernorate,
    this.tenantCity,
  });

  factory TenderDetail.fromJson(Map<String, dynamic> j) => TenderDetail(
        id: j['id'] as String,
        tenderNumber: j['requestNumber'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        status: TenderStatus.fromCode(j['status'] as int),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        createdOn: DateTime.parse(j['createdOn'] as String),
        winnerNotes: j['winnerNotes'] as String?,
        // الخادم يخفي عروض الأسعار حتى انتهاء المهلة: quotationsVisible
        offersVisible: j['quotationsVisible'] as bool,
        offerCount: j['quotationCount'] as int,
        items: ((j['items'] as List?) ?? [])
            .map((e) => TenderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        offers: (j['quotations'] as List?)
            ?.map((e) => TenderOffer.fromJson(e as Map<String, dynamic>))
            .toList(),
        tenantGovernorate: j['tenantGovernorate'] as String?,
        tenantCity: j['tenantCity'] as String?,
      );
}

class MyTenderOfferSummary {
  final String offerId;
  final String tenderId;
  final String tenderNumber;
  final String tenderTitle;
  final TenderOfferType offerType;
  final TenderOfferStatus status;
  final bool isSelectedByPharmacy;
  final DateTime tenderExpiresAt;
  final DateTime createdOn;

  MyTenderOfferSummary({
    required this.offerId,
    required this.tenderId,
    required this.tenderNumber,
    required this.tenderTitle,
    required this.offerType,
    required this.status,
    required this.isSelectedByPharmacy,
    required this.tenderExpiresAt,
    required this.createdOn,
  });

  factory MyTenderOfferSummary.fromJson(Map<String, dynamic> j) => MyTenderOfferSummary(
        offerId: j['quotationId'] as String,
        tenderId: j['quotationRequestId'] as String,
        tenderNumber: j['requestNumber'] as String,
        tenderTitle: j['quotationRequestTitle'] as String,
        offerType: TenderOfferType.fromCode(j['quotationType'] as int),
        status: TenderOfferStatus.fromCode(j['status'] as int),
        isSelectedByPharmacy: j['isSelectedByPharmacy'] as bool,
        tenderExpiresAt: DateTime.parse(j['quotationRequestExpiresAt'] as String),
        createdOn: DateTime.parse(j['createdOn'] as String),
      );
}

class SelectOfferResult {
  final String tenderId;
  final String offerId;
  final String supplyOrderId;
  final String supplyOrderNumber;
  final String message;

  SelectOfferResult({
    required this.tenderId,
    required this.offerId,
    required this.supplyOrderId,
    required this.supplyOrderNumber,
    required this.message,
  });

  factory SelectOfferResult.fromJson(Map<String, dynamic> j) => SelectOfferResult(
        tenderId: j['quotationRequestId'] as String,
        offerId: j['quotationId'] as String,
        supplyOrderId: j['supplyOrderId'] as String,
        supplyOrderNumber: j['supplyOrderNumber'] as String,
        message: j['message'] as String,
      );
}
