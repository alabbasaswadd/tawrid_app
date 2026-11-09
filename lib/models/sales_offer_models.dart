import 'package:tawrid_app/models/bonus_tier.dart';

import 'enums.dart';

/// نوع عرض البيع — مشتقٌّ في الخادم من وجود تاريخ الانتهاء من عدمه.
enum SalesOfferKind {
  /// عرض دائم بلا تاريخ انتهاء — نشرة أسعار سارية حتى يُلغيها المستودع.
  standing(1),

  /// عرض لفترة محدّدة — ينتهي تلقائياً عند تاريخه.
  timeLimited(2);

  const SalesOfferKind(this.code);
  final int code;

  static SalesOfferKind fromCode(int? code) => SalesOfferKind.values.firstWhere(
        (e) => e.code == code,
        orElse: () => SalesOfferKind.timeLimited,
      );

  String get label => switch (this) {
        SalesOfferKind.standing => 'عرض ثابت',
        SalesOfferKind.timeLimited => 'لفترة محدّدة',
      };
}

// منطقة مستهدفة (محافظة، مع مدينة اختيارية = كل مدن المحافظة) — عرض واحد
// قد يستهدف أكثر من محافظة وأكثر من مدينة.
class TargetRegion {
  final String governorate;
  final String? city;

  TargetRegion({required this.governorate, this.city});

  factory TargetRegion.fromJson(Map<String, dynamic> j) => TargetRegion(
        governorate: j['governorate'] as String,
        city: j['city'] as String?,
      );

  Map<String, dynamic> toJson() => {'governorate': governorate, 'city': city};

  String get label => city != null && city!.isNotEmpty ? '$governorate - $city' : governorate;
}

// ملاحظة: حُذف offerType من الباك إند — من يرى العرض تحدّده المناطق
// المستهدَفة ومدن خدمة المستودع، لا تصنيف نوع للعرض.
class SalesOfferSummary {
  final String id;
  final String title;
  final SalesOfferStatus status;
  final String warehouseName;
  final String currency;
  final List<TargetRegion> targetRegions;
  final int itemCount;
  final List<String> itemNames;
  final DateTime startsAt;
  /// null = عرض ثابت لا ينتهي.
  final DateTime? expiresAt;

  /// نوع العرض — ثابت أو لفترة محدّدة.
  final SalesOfferKind kind;
  final DateTime createdOn;

  // البونص على مستويين: على أصناف بعينها، وعلى العرض كاملاً (دواء يُهدى مع
  // الطلبية). تُقرأ متساهلةً: خادم لم يُحدَّث بعد لا يرسلها فتبقى false
  // ولا تظهر الشارة الذهبية — تدهور لطيف بدل انكسار القائمة.
  final bool hasItemBonus;
  final bool hasOfferBonus;
  final String? offerBonusMedicineName;

  bool get hasAnyBonus => hasItemBonus || hasOfferBonus;

  SalesOfferSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.warehouseName,
    required this.currency,
    required this.targetRegions,
    required this.itemCount,
    required this.itemNames,
    required this.startsAt,
    required this.expiresAt,
    this.kind = SalesOfferKind.timeLimited,
    required this.createdOn,
    this.hasItemBonus = false,
    this.hasOfferBonus = false,
    this.offerBonusMedicineName,
  });

  factory SalesOfferSummary.fromJson(Map<String, dynamic> j) => SalesOfferSummary(
        id: j['id'] as String,
        title: j['title'] as String,
        status: SalesOfferStatus.fromCode(j['status'] as int),
        warehouseName: j['warehouseName'] as String,
        currency: j['currency'] as String? ?? 'SYP',
        targetRegions: ((j['targetRegions'] as List?) ?? [])
            .map((e) => TargetRegion.fromJson(e as Map<String, dynamic>))
            .toList(),
        itemCount: j['itemCount'] as int,
        itemNames: ((j['itemNames'] as List?) ?? []).map((e) => e as String).toList(),
        startsAt: DateTime.parse(j['startsAt'] as String),
        expiresAt: j['expiresAt'] == null
            ? null
            : DateTime.parse(j['expiresAt'] as String),
        kind: SalesOfferKind.fromCode(j['kind'] as int?),
        createdOn: DateTime.parse(j['createdOn'] as String),
        hasItemBonus: j['hasItemBonus'] as bool? ?? false,
        hasOfferBonus: j['hasOfferBonus'] as bool? ?? false,
        offerBonusMedicineName: j['offerBonusMedicineName'] as String?,
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

  /// نسبة البونص — الشكل القديم؛ فارغة في العروض ذات الشرائح.
  final double? bonusPercentage;

  /// شرائح البونص الكمّي مرتَّبة تنازلياً بكمية الشراء — «(10+5) (5+2) (3+1)».
  /// فارغة = لا بونص كمّي على هذا الصنف.
  final List<BonusTier> bonusTiers;

  SalesOfferItem({
    required this.id,
    required this.medicineName,
    this.catalogItemId,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.discountPercentage,
    this.bonusPercentage,
    this.bonusTiers = const [],
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
        bonusTiers: BonusTier.listFromJson(j['bonusTiers']),
      );

  Map<String, dynamic> toCreateJson() => {
        'medicineName': medicineName,
        'catalogItemId': catalogItemId,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'discountPercentage': discountPercentage,
        // الخادم يُهمل النسبة متى وصلت شرائح — مصدر حقيقة واحد للبونص.
        'bonusPercentage': bonusTiers.isEmpty ? bonusPercentage : null,
        'bonusTiers': bonusTiers.map((t) => t.toCreateJson()).toList(),
      };

  /// هل على هذا الصنف بونص بأي شكل؟
  bool get hasBonus => bonusTiers.isNotEmpty || (bonusPercentage ?? 0) > 0;

  /// نصّ الشارة: سلّم الشرائح إن وُجد، وإلا النسبة القديمة.
  /// «10 + 5 · 5 + 2 · 3 + 1» أو «بونص 20٪».
  String? get bonusLabel {
    if (bonusTiers.isNotEmpty) {
      return bonusTiers.map((t) => t.label).join(' · ');
    }
    if ((bonusPercentage ?? 0) > 0) {
      return 'بونص ${bonusPercentage!.toStringAsFixed(0)}٪';
    }
    return null;
  }
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
  final SalesOfferStatus status;
  final DateTime startsAt;
  /// null = عرض ثابت لا ينتهي.
  final DateTime? expiresAt;

  /// نوع العرض — ثابت أو لفترة محدّدة.
  final SalesOfferKind kind;
  final String currency;
  final List<TargetRegion> targetRegions;
  final bool isPublicInRegion;
  final double? upfrontPercentage;
  final int? paymentPeriodDays;
  final String? consignmentTerms;
  final String? bonusMedicineName;
  final double? bonusMedicineQuantity;
  final String? bonusMedicineUnit;
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
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    this.kind = SalesOfferKind.timeLimited,
    required this.currency,
    required this.targetRegions,
    required this.isPublicInRegion,
    this.upfrontPercentage,
    this.paymentPeriodDays,
    this.consignmentTerms,
    this.bonusMedicineName,
    this.bonusMedicineQuantity,
    this.bonusMedicineUnit,
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
        status: SalesOfferStatus.fromCode(j['status'] as int),
        startsAt: DateTime.parse(j['startsAt'] as String),
        expiresAt: j['expiresAt'] == null
            ? null
            : DateTime.parse(j['expiresAt'] as String),
        kind: SalesOfferKind.fromCode(j['kind'] as int?),
        currency: j['currency'] as String? ?? 'SYP',
        targetRegions: ((j['targetRegions'] as List?) ?? [])
            .map((e) => TargetRegion.fromJson(e as Map<String, dynamic>))
            .toList(),
        isPublicInRegion: j['isPublicInRegion'] as bool,
        upfrontPercentage: (j['upfrontPercentage'] as num?)?.toDouble(),
        paymentPeriodDays: j['paymentPeriodDays'] as int?,
        consignmentTerms: j['consignmentTerms'] as String?,
        bonusMedicineName: j['bonusMedicineName'] as String?,
        bonusMedicineQuantity: (j['bonusMedicineQuantity'] as num?)?.toDouble(),
        bonusMedicineUnit: j['bonusMedicineUnit'] as String?,
        createdOn: DateTime.parse(j['createdOn'] as String),
        items: ((j['items'] as List?) ?? [])
            .map((e) => SalesOfferItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        targets: (j['targets'] as List?)
            ?.map((e) => SalesOfferTarget.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
