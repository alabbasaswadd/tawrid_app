import 'enums.dart';

class SupplyOrderSummary {
  final String id;
  final String orderNumber;
  final SupplyOrderStatus status;
  final String warehouseName;
  final String warehouseCity;

  /// هاتف المستودع — يُمكّن «تواصل مع المستودع» من القائمة مباشرةً.
  /// فارغ إن كان الخادم أقدم من إضافة الحقل، فيُخفى الزر بدل أن يفشل.
  final String warehousePhone;

  final int itemCount;
  final DateTime createdOn;
  final DateTime? expectedDeliveryDate;
  final bool invoiceCreated;
  final String? generatedPurchaseId;

  /// إجمالي الطلبية = مجموع (السعر المتَّفق × الكمية). يبقى null إن لم
  /// يُسعَّر أي صنف، أو إن كان الخادم أقدم من إضافة الحقل — وفي الحالتين
  /// تُخفي البطاقة سطر القيمة بدل عرض صفرٍ كاذب.
  final double? totalAmount;

  /// الصيدلية الطالبة — تصل في عرض المستودع فقط. في عرض الصيدلي تبقى
  /// null لأن الصيدلي يعرف نفسه، والمهم عنده هو المستودع.
  final String? pharmacyName;
  final String? pharmacyCity;

  /// الطرف المقابل كما يراه كل جانب: الصيدلي يرى المستودع، والمستودع
  /// يرى الصيدلية. يُغني الشاشتين عن تمرير علمٍ لمعرفة من تعرض.
  String get counterpartName => pharmacyName ?? warehouseName;
  String get counterpartCity => pharmacyCity ?? warehouseCity;

  SupplyOrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.warehouseName,
    required this.warehouseCity,
    this.warehousePhone = '',
    required this.itemCount,
    required this.createdOn,
    this.expectedDeliveryDate,
    required this.invoiceCreated,
    this.generatedPurchaseId,
    this.totalAmount,
    this.pharmacyName,
    this.pharmacyCity,
  });

  factory SupplyOrderSummary.fromJson(Map<String, dynamic> j) => SupplyOrderSummary(
        id: j['id'] as String,
        orderNumber: j['orderNumber'] as String,
        status: SupplyOrderStatus.fromCode(j['status'] as int),
        warehouseName: j['warehouseName'] as String,
        warehouseCity: j['warehouseCity'] as String,
        warehousePhone: j['warehousePhone'] as String? ?? '',
        itemCount: j['itemCount'] as int,
        createdOn: DateTime.parse(j['createdOn'] as String),
        expectedDeliveryDate: j['expectedDeliveryDate'] != null
            ? DateTime.parse(j['expectedDeliveryDate'] as String)
            : null,
        invoiceCreated: j['invoiceCreated'] as bool,
        generatedPurchaseId: j['generatedPurchaseId'] as String?,
        totalAmount: (j['totalAmount'] as num?)?.toDouble(),
        pharmacyName: j['pharmacyName'] as String?,
        pharmacyCity: j['pharmacyCity'] as String?,
      );
}

class SupplyOrderItem {
  final String id;
  final String medicineName;
  final String? catalogItemId;
  final double quantity;
  final String unit;
  final double? agreedUnitPrice;
  final double? bonusPercentage;

  SupplyOrderItem({
    required this.id,
    required this.medicineName,
    this.catalogItemId,
    required this.quantity,
    required this.unit,
    this.agreedUnitPrice,
    this.bonusPercentage,
  });

  factory SupplyOrderItem.fromJson(Map<String, dynamic> j) => SupplyOrderItem(
        id: j['id'] as String,
        medicineName: j['medicineName'] as String,
        catalogItemId: j['catalogItemId'] as String?,
        quantity: (j['quantity'] as num).toDouble(),
        unit: j['unit'] as String,
        agreedUnitPrice: (j['agreedUnitPrice'] as num?)?.toDouble(),
        bonusPercentage: (j['bonusPercentage'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toCreateJson() => {
        'medicineName': medicineName,
        'catalogItemId': catalogItemId,
        'quantity': quantity,
        'unit': unit,
        'agreedUnitPrice': agreedUnitPrice,
        'bonusPercentage': bonusPercentage,
      };
}

class SupplyOrderDetail {
  final String id;
  final String orderNumber;
  final SupplyOrderStatus status;
  final String supplyWarehouseId;
  final String warehouseName;
  final String warehousePhone;
  final String warehouseCity;
  final String warehouseGovernorate;
  final String? notes;
  final DateTime? expectedDeliveryDate;
  final DateTime? deliveredAt;
  final bool invoiceCreated;
  final String? generatedPurchaseId;
  final DateTime createdOn;
  final List<SupplyOrderItem> items;

  /// الصيدلية الطالبة — تصل في عرض المستودع فقط.
  final String? pharmacyName;
  final String? pharmacyPhone;
  final String? pharmacyCity;
  final String? pharmacyGovernorate;
  final String? pharmacyAddress;

  SupplyOrderDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.supplyWarehouseId,
    required this.warehouseName,
    required this.warehousePhone,
    required this.warehouseCity,
    required this.warehouseGovernorate,
    this.notes,
    this.expectedDeliveryDate,
    this.deliveredAt,
    required this.invoiceCreated,
    this.generatedPurchaseId,
    required this.createdOn,
    required this.items,
    this.pharmacyName,
    this.pharmacyPhone,
    this.pharmacyCity,
    this.pharmacyGovernorate,
    this.pharmacyAddress,
  });

  factory SupplyOrderDetail.fromJson(Map<String, dynamic> j) => SupplyOrderDetail(
        id: j['id'] as String,
        orderNumber: j['orderNumber'] as String,
        status: SupplyOrderStatus.fromCode(j['status'] as int),
        supplyWarehouseId: j['supplyWarehouseId'] as String,
        warehouseName: j['warehouseName'] as String,
        warehousePhone: j['warehousePhone'] as String,
        warehouseCity: j['warehouseCity'] as String,
        warehouseGovernorate: j['warehouseGovernorate'] as String,
        notes: j['notes'] as String?,
        expectedDeliveryDate: j['expectedDeliveryDate'] != null
            ? DateTime.parse(j['expectedDeliveryDate'] as String)
            : null,
        deliveredAt:
            j['deliveredAt'] != null ? DateTime.parse(j['deliveredAt'] as String) : null,
        invoiceCreated: j['invoiceCreated'] as bool,
        generatedPurchaseId: j['generatedPurchaseId'] as String?,
        createdOn: DateTime.parse(j['createdOn'] as String),
        items: ((j['items'] as List?) ?? [])
            .map((e) => SupplyOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pharmacyName: j['pharmacyName'] as String?,
        pharmacyPhone: j['pharmacyPhone'] as String?,
        pharmacyCity: j['pharmacyCity'] as String?,
        pharmacyGovernorate: j['pharmacyGovernorate'] as String?,
        pharmacyAddress: j['pharmacyAddress'] as String?,
      );
}

class StatusHistoryItem {
  final String id;
  final SupplyOrderStatus oldStatus;
  final SupplyOrderStatus newStatus;
  final String? comment;
  final String changedByName;
  final DateTime changedAt;

  StatusHistoryItem({
    required this.id,
    required this.oldStatus,
    required this.newStatus,
    this.comment,
    required this.changedByName,
    required this.changedAt,
  });

  factory StatusHistoryItem.fromJson(Map<String, dynamic> j) => StatusHistoryItem(
        id: j['id'] as String,
        oldStatus: SupplyOrderStatus.fromCode(j['oldStatus'] as int),
        newStatus: SupplyOrderStatus.fromCode(j['newStatus'] as int),
        comment: j['comment'] as String?,
        changedByName: j['changedByName'] as String,
        changedAt: DateTime.parse(j['changedAt'] as String),
      );
}

class GenerateInvoiceResult {
  final String purchaseId;
  final String message;

  GenerateInvoiceResult({required this.purchaseId, required this.message});

  factory GenerateInvoiceResult.fromJson(Map<String, dynamic> j) => GenerateInvoiceResult(
        purchaseId: j['purchaseId'] as String,
        message: j['message'] as String,
      );
}
