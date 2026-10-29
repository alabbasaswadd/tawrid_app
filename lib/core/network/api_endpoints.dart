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

  // ── Supply Warehouses (pharmacy side) ──────────────────────────────────────
  // القائمة = المستودعات النشطة للاختيار؛ والتفاصيل = ملف المستودع العام
  // (بيانات تعريفية + مدن الخدمة + عدد العروض السارية، بلا شيء داخلي).
  static const String supplyWarehouses = '$_ph/supply-warehouses';
  static String supplyWarehouseById(String id) => '$_ph/supply-warehouses/$id';

  // ── Warehouse: Users (إدارة الموظّفين — للمدير فقط) ────────────────────────
  // الخادم يفرض سياسة Warehouse.Admin؛ الواجهة تُخفي المدخل عن الموظّف
  // بدل أن تتركه يصطدم بـ403.
  static const String whUsers = '$_wh/users';
  static String whUserById(String id)       => '$_wh/users/$id';
  static String whUserActive(String id)     => '$_wh/users/$id/active';
  static String whUserPassword(String id)   => '$_wh/users/$id/password';

  // ── Geo (محافظات/مدن — عام، بلا توكن) ───────────────────────────────────────
  static const String geoGovernorates = '$_ph/geo/governorates';

  // ── Warehouse: Service Areas (مناطق التخديم) ───────────────────────────────
  static const String whServiceAreas = '$_wh/service-areas';

  // ── Medicine Catalog (كاتالوج عام — بلا توكن للقراءة) ──────────────────────
  static const String catalogSearch = '$_ph/catalog';
  static const String catalogManufacturers = '$_ph/catalog/manufacturers';
  static String catalogById(String id) => '$_ph/catalog/$id';

  // ── Warehouse: My Medicines (أدوية المستودع — بلا ربط مخزون) ───────────────
  // السعر اختياري: صنف بلا سعر يبقى في القائمة الداخلية ولا يظهر في البحث
  // المقارن عند الصيدليات.
  static const String whMedicines = '$_wh/medicines';
  static String whMedicineById(String id) => '$_wh/medicines/$id';
  static String whMedicinePrice(String id) => '$_wh/medicines/$id/price';

  // ── Warehouse: Settings (إعدادات الطلبيات — الحدّ الأدنى) ──────────────────
  static const String whSettings = '$_wh/settings';

  // ── Pharmacy: Medicine price search (البحث المقارن) ───────────────────────
  // يدمج أصناف العروض السارية مع التسعير المباشر من المستودعات في قائمة
  // واحدة مُرقَّمة. السلّة تُبنى من نتائجه محلياً ثم تُتمّ عبر phOrders.
  static const String phMedicinePriceSearch = '$_ph/medicines/search';

  // ── Pharmacy: Cart (السلّة — محفوظة على الخادم ومجمَّعة حسب المستودع) ─────
  // كل مسار هنا يُعيد السلّة كاملةً بعد التعديل، فتُرسم الشاشة من الاستجابة
  // بلا طلب ثانٍ. والإضافة ترسل مرجع الصنف وكميته فقط — السعر يُشتقّ في
  // الخادم من المصدر فلا يُسعّر العميل ما يشتريه.
  static const String phCart = '$_ph/cart';
  static const String phCartItems = '$_ph/cart/items';
  static String phCartItemById(String id) => '$_ph/cart/items/$id';
  static String phCartWarehouse(String warehouseId) =>
      '$_ph/cart/warehouses/$warehouseId';
  static String phCartCheckout(String warehouseId) =>
      '$_ph/cart/warehouses/$warehouseId/checkout';

  // ── Pharmacy: Supply Orders ────────────────────────────────────────────────
  static const String phOrders = '$_ph/supply-orders';
  static String phOrderById(String id)        => '$_ph/supply-orders/$id';
  static String phOrderCancel(String id)      => '$_ph/supply-orders/$id/cancel';
  static String phOrderHistory(String id)     => '$_ph/supply-orders/$id/history';
  static String phOrderGenerateInvoice(String id) => '$_ph/supply-orders/$id/generate-invoice';

  // ── Pharmacy: Quotation Requests (طلبات التسعير — كانت tenders) ───────────
  // أُعيدت التسمية في الباك إند إلى quotation-requests. أسماء الثوابت هنا
  // مُبقاة بصيغة Tender* عمداً حتى لا يُعاد تسمية كل الصفحات دفعةً واحدة،
  // والمسارات نفسها هي المصدر الذي يجب أن يطابق الخادم.
  static const String phTenders = '$_ph/quotation-requests';
  static String phTenderById(String id)    => '$_ph/quotation-requests/$id';
  static String phTenderCancel(String id)  => '$_ph/quotation-requests/$id/cancel';
  static String phTenderPublish(String id) => '$_ph/quotation-requests/$id/publish';
  static String phTenderSelectOffer(String tid, String oid) =>
      '$_ph/quotation-requests/$tid/select-quotation/$oid';

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

  // ── Warehouse: Quotation Requests (طلبات التسعير) ─────────────────────────
  static const String whTendersOpen = '$_wh/quotation-requests/open';
  static const String whMyOffers    = '$_wh/quotation-requests/my-quotations';
  static String whTenderById(String id)         => '$_wh/quotation-requests/$id';
  static String whTenderSubmit(String tenderId) => '$_wh/quotation-requests/$tenderId/quotations';

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

  // ── Notifications ─────────────────────────────────────────────────────────
  // الصندوق والإعدادات متطابقان في الجهتين؛ ما يختلف هو البادئة فقط، لذلك
  // تُبنى المسارات من جذر يُمرَّر إليه (`_ph` للصيدلية، `_wh` للمستودع) بدل
  // نسخ ثمانية ثوابت مرّتين. انتبه: `_AuthInterceptor` يختار التوكن بوجود
  // «/warehouse/» في المسار، فبادئة المستودع تُلزِم توكنه تلقائياً.
  static String _notifRoot(bool warehouse) =>
      '${warehouse ? _wh : _ph}/notifications';

  static String notifications(bool warehouse) => _notifRoot(warehouse);
  static String notificationsUnreadCount(bool warehouse) =>
      '${_notifRoot(warehouse)}/unread-count';
  static String notificationRead(bool warehouse, String id) =>
      '${_notifRoot(warehouse)}/$id/read';
  static String notificationsReadAll(bool warehouse) =>
      '${_notifRoot(warehouse)}/read-all';
  static String notificationSettings(bool warehouse) =>
      '${_notifRoot(warehouse)}/settings';

  // ── Device tokens (تسجيل جهاز الإشعارات) ─────────────────────────────────
  // تحت مسار المصادقة لا الإشعارات — الجهاز يُسجَّل باسم الحساب.
  static String devices(bool warehouse) =>
      '${warehouse ? _wh : _ph}/auth/devices';
  static String deviceByToken(bool warehouse, String token) =>
      '${warehouse ? _wh : _ph}/auth/devices/$token';
}
