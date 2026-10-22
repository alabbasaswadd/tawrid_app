// تطابق تماماً قيم الـ Enums الصحيحة في الباك إند (Tawrid.Domain.Enums) —
// System.Text.Json يُسلسلها كأعداد صحيحة (لا نصوص) لعدم وجود
// JsonStringEnumConverter في Program.cs.

enum TenderStatus {
  open(1),
  closed(2),
  awarded(3),
  cancelled(4);

  const TenderStatus(this.code);
  final int code;

  static TenderStatus fromCode(int code) =>
      TenderStatus.values.firstWhere((e) => e.code == code, orElse: () => TenderStatus.open);

  String get label => switch (this) {
        TenderStatus.open => 'مفتوحة',
        TenderStatus.closed => 'منتهية',
        TenderStatus.awarded => 'تم الترسية',
        TenderStatus.cancelled => 'ملغاة',
      };
}

enum SupplyOrderStatus {
  pending(1),
  confirmed(2),
  processing(3),
  shipped(4),
  delivered(5),
  completed(6),
  cancelled(7);

  const SupplyOrderStatus(this.code);
  final int code;

  static SupplyOrderStatus fromCode(int code) => SupplyOrderStatus.values
      .firstWhere((e) => e.code == code, orElse: () => SupplyOrderStatus.pending);

  String get label => switch (this) {
        SupplyOrderStatus.pending => 'بانتظار التأكيد',
        SupplyOrderStatus.confirmed => 'مؤكَّدة',
        SupplyOrderStatus.processing => 'قيد التجهيز',
        SupplyOrderStatus.shipped => 'مشحونة',
        SupplyOrderStatus.delivered => 'مسلَّمة',
        SupplyOrderStatus.completed => 'مكتملة',
        SupplyOrderStatus.cancelled => 'ملغاة',
      };

  // الانتقالات المسموحة من هذه الحالة (لبناء القائمة المنسدلة لدى المستودع).
  List<SupplyOrderStatus> get nextAllowed => switch (this) {
        SupplyOrderStatus.pending => [SupplyOrderStatus.confirmed, SupplyOrderStatus.cancelled],
        SupplyOrderStatus.confirmed => [SupplyOrderStatus.processing, SupplyOrderStatus.cancelled],
        SupplyOrderStatus.processing => [SupplyOrderStatus.shipped],
        SupplyOrderStatus.shipped => [SupplyOrderStatus.delivered],
        SupplyOrderStatus.delivered => [SupplyOrderStatus.completed],
        SupplyOrderStatus.completed => [],
        SupplyOrderStatus.cancelled => [],
      };
}

enum SalesOfferStatus {
  draft(1),
  active(2),
  expired(3),
  cancelled(4);

  const SalesOfferStatus(this.code);
  final int code;

  static SalesOfferStatus fromCode(int code) => SalesOfferStatus.values
      .firstWhere((e) => e.code == code, orElse: () => SalesOfferStatus.draft);

  String get label => switch (this) {
        SalesOfferStatus.draft => 'مسودة',
        SalesOfferStatus.active => 'نشط',
        SalesOfferStatus.expired => 'منتهي',
        SalesOfferStatus.cancelled => 'ملغى',
      };
}

enum SalesOfferType {
  targeted(1),
  consignment(2),
  open(3);

  const SalesOfferType(this.code);
  final int code;

  static SalesOfferType fromCode(int code) =>
      SalesOfferType.values.firstWhere((e) => e.code == code, orElse: () => SalesOfferType.open);

  String get label => switch (this) {
        SalesOfferType.targeted => 'موجَّه',
        SalesOfferType.consignment => 'مبيع (نسبة مقدّمة)',
        SalesOfferType.open => 'عام',
      };
}

enum TenderOfferType {
  priceBased(1),
  bonusBased(2),
  mixed(3);

  const TenderOfferType(this.code);
  final int code;

  static TenderOfferType fromCode(int code) => TenderOfferType.values
      .firstWhere((e) => e.code == code, orElse: () => TenderOfferType.priceBased);

  String get label => switch (this) {
        TenderOfferType.priceBased => 'سعري',
        TenderOfferType.bonusBased => 'بونص',
        TenderOfferType.mixed => 'مختلط',
      };
}

enum TenderOfferStatus {
  submitted(1),
  accepted(2),
  rejected(3);

  const TenderOfferStatus(this.code);
  final int code;

  static TenderOfferStatus fromCode(int code) => TenderOfferStatus.values
      .firstWhere((e) => e.code == code, orElse: () => TenderOfferStatus.submitted);

  String get label => switch (this) {
        TenderOfferStatus.submitted => 'مُقدَّم',
        TenderOfferStatus.accepted => 'مقبول',
        TenderOfferStatus.rejected => 'مرفوض',
      };
}

enum PharmacyListingStatus {
  active(1),
  sold(2),
  expired(3),
  cancelled(4);

  const PharmacyListingStatus(this.code);
  final int code;

  static PharmacyListingStatus fromCode(int code) => PharmacyListingStatus.values
      .firstWhere((e) => e.code == code, orElse: () => PharmacyListingStatus.active);

  String get label => switch (this) {
        PharmacyListingStatus.active => 'نشط',
        PharmacyListingStatus.sold => 'مباع',
        PharmacyListingStatus.expired => 'منتهي',
        PharmacyListingStatus.cancelled => 'ملغى',
      };
}

enum ListingBuyerType {
  any(1),
  warehouseOnly(2),
  pharmacyOnly(3);

  const ListingBuyerType(this.code);
  final int code;

  static ListingBuyerType fromCode(int code) =>
      ListingBuyerType.values.firstWhere((e) => e.code == code, orElse: () => ListingBuyerType.any);

  String get label => switch (this) {
        ListingBuyerType.any => 'أي مشترٍ',
        ListingBuyerType.warehouseOnly => 'مستودعات فقط',
        ListingBuyerType.pharmacyOnly => 'صيدليات فقط',
      };
}

enum CommentAuthorType {
  pharmacy(1),
  warehouse(2);

  const CommentAuthorType(this.code);
  final int code;

  static CommentAuthorType fromCode(int code) => CommentAuthorType.values
      .firstWhere((e) => e.code == code, orElse: () => CommentAuthorType.pharmacy);
}

enum WarehouseUserRole {
  admin(1),
  staff(2);

  const WarehouseUserRole(this.code);
  final int code;

  static WarehouseUserRole fromCode(int code) => WarehouseUserRole.values
      .firstWhere((e) => e.code == code, orElse: () => WarehouseUserRole.staff);

  String get label => switch (this) {
        WarehouseUserRole.admin => 'مدير',
        WarehouseUserRole.staff => 'موظف',
      };
}
