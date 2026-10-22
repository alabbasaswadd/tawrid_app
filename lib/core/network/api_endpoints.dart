abstract final class ApiEndpoints {
  static const String _ph = '/tawrid-api';
  static const String _wh = '/tawrid-api/warehouse';

  // ── Pharmacy Auth ──────────────────────────────────────────────────────────
  static const String phLogin    = '$_ph/auth/login';
  static const String phRegister = '$_ph/auth/register';
  static const String phMe       = '$_ph/auth/me';

  // ── Warehouse Auth ─────────────────────────────────────────────────────────
  static const String whLogin    = '$_wh/auth/login';
  static const String whRegister = '$_wh/auth/register';
  static const String whMe       = '$_wh/auth/me';

  // ── Supply Warehouses list (pharmacy side) ─────────────────────────────────
  static const String supplyWarehouses = '$_ph/supply-warehouses';

  // ── Geo (محافظات/مدن — عام، بلا توكن) ───────────────────────────────────────
  static const String geoGovernorates = '$_ph/geo/governorates';

  // ── Warehouse: Service Areas (مناطق التخديم) ───────────────────────────────
  static const String whServiceAreas = '$_wh/service-areas';

  // ── Medicine Catalog (كاتالوج عام — بلا توكن للقراءة) ──────────────────────
  static const String catalogSearch = '$_ph/catalog';
  static String catalogById(String id) => '$_ph/catalog/$id';

  // ── Warehouse: My Medicines (أدوية المستودع — بلا ربط مخزون) ───────────────
  static const String whMedicines = '$_wh/medicines';
  static String whMedicineById(String id) => '$_wh/medicines/$id';

  // ── Pharmacy: Supply Orders ────────────────────────────────────────────────
  static const String phOrders = '$_ph/supply-orders';
  static String phOrderById(String id)        => '$_ph/supply-orders/$id';
  static String phOrderCancel(String id)      => '$_ph/supply-orders/$id/cancel';
  static String phOrderHistory(String id)     => '$_ph/supply-orders/$id/history';
  static String phOrderGenerateInvoice(String id) => '$_ph/supply-orders/$id/generate-invoice';

  // ── Pharmacy: Tenders ─────────────────────────────────────────────────────
  static const String phTenders = '$_ph/tenders';
  static String phTenderById(String id)    => '$_ph/tenders/$id';
  static String phTenderCancel(String id)  => '$_ph/tenders/$id/cancel';
  static String phTenderSelectOffer(String tid, String oid) => '$_ph/tenders/$tid/select-offer/$oid';

  // ── Pharmacy: Browse Offers ───────────────────────────────────────────────
  static const String phOffers = '$_ph/offers';
  static String phOfferById(String id)        => '$_ph/offers/$id';
  static String phOfferComments(String id)    => '$_ph/offers/$id/comments';
  static String phOfferCommentById(String id, String commentId) => '$_ph/offers/$id/comments/$commentId';

  // ── Pharmacy: Listings ────────────────────────────────────────────────────
  static const String phMyListings     = '$_ph/listings/mine';
  static const String phPublicListings = '$_ph/listings';
  static String phListingById(String id)       => '$_ph/listings/$id';
  static String phListingSold(String id)       => '$_ph/listings/$id/sold';
  static String phListingCancel(String id)     => '$_ph/listings/$id/cancel';
  static String phListingComments(String id)   => '$_ph/listings/$id/comments';
  static String phListingCommentById(String id, String commentId) => '$_ph/listings/$id/comments/$commentId';

  // ── Warehouse: Orders ─────────────────────────────────────────────────────
  static const String whOrders = '$_wh/orders';
  static String whOrderById(String id)     => '$_wh/orders/$id';
  static String whOrderStatus(String id)   => '$_wh/orders/$id/status';
  static String whOrderHistory(String id)  => '$_wh/orders/$id/history';

  // ── Warehouse: Tenders ────────────────────────────────────────────────────
  static const String whTendersOpen = '$_wh/tenders/open';
  static const String whMyOffers    = '$_wh/tenders/my-offers';
  static String whTenderById(String id)         => '$_wh/tenders/$id';
  static String whTenderSubmit(String tenderId) => '$_wh/tenders/$tenderId/offers';

  // ── Warehouse: Sales Offers ───────────────────────────────────────────────
  static const String whSalesOffers = '$_wh/offers';
  static String whSalesOfferById(String id)      => '$_wh/offers/$id';
  static String whSalesOfferPublish(String id)   => '$_wh/offers/$id/publish';
  static String whSalesOfferCancel(String id)    => '$_wh/offers/$id/cancel';
  static String whSalesOfferTargets(String id)   => '$_wh/offers/$id/targets';
  static String whSalesOfferComments(String id)  => '$_wh/offers/$id/comments';
  static String whSalesOfferCommentById(String id, String commentId) => '$_wh/offers/$id/comments/$commentId';

  // ── Warehouse: Listings (browse pharmacy listings) ────────────────────────
  static const String whListings = '$_wh/listings';
  static String whListingById(String id)     => '$_wh/listings/$id';
  static String whListingComments(String id) => '$_wh/listings/$id/comments';
  static String whListingCommentById(String id, String commentId) => '$_wh/listings/$id/comments/$commentId';
}
