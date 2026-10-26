abstract final class TRoutes {
  // Splash
  static const String splash = '/';

  // Pharmacy auth
  static const String phLogin = '/login';
  static const String phRegister = '/register';

  // حالة الحساب (قيد المراجعة/مرفوض) — تحجب التطبيق لغير المقبول
  static const String accountStatus = '/account-status';

  // Warehouse auth
  static const String whLogin = '/wh/login';
  static const String whRegister = '/wh/register';
  static const String whServiceAreas = '/wh/service-areas';
  static const String whProfile = '/wh/profile';
  static const String whUsers = '/wh/users';

  // تفاصيل عرض البيع عند المستودع (مالك العرض)
  static const String whOfferDetailPattern = '/wh/offers/:offerId';
  static String whOfferDetail(String id) => '/wh/offers/$id';

  // تفاصيل الطلب الوارد عند المستودع
  static const String whOrderDetailPattern = '/wh/orders/:orderId';
  static String whOrderDetail(String id) => '/wh/orders/$id';
  static const String phMedicineSearch = '/medicines/search';

  // تفاصيل عرض بيع عند الصيدلي — منها تُنشأ الطلبية باختيار الأصناف
  static const String phOfferDetailPattern = '/offers/:offerId';
  static String phOfferDetail(String id) => '/offers/$id';

  // طلبات التسعير: إنشاء + مقارنة عروض الأسعار والترسية
  static const String phCreateTender = '/tenders/create';
  static const String phCompareQuotationsPattern = '/tenders/:requestId';
  static String phCompareQuotations(String id) => '/tenders/$id';

  // تفاصيل طلبية التوريد — المسار والأصناف والفاتورة ومشاركة PDF
  static const String phOrderDetailPattern = '/orders/:orderId';
  static String phOrderDetail(String id) => '/orders/$id';

  // المستودعات المتاحة للصيدلية + ملف مستودع بعينه (يُفتح أيضاً من اسم
  // المستودع في ورقة تفاصيل العرض).
  static const String phWarehouses = '/warehouses';
  static const String phWarehouseProfilePattern = '/warehouses/:warehouseId';
  static String phWarehouseProfile(String id) => '/warehouses/$id';
  static const String whMedicines = '/wh/medicines';
  static const String whMedicineCatalog = '/wh/medicines/catalog';
  static const String whCreateOffer = '/wh/offers/create';
  static const String whSubmitTenderOfferPattern =
      '/wh/tenders/:tenderId/submit-offer';
  static String whSubmitTenderOffer(String tenderId) =>
      '/wh/tenders/$tenderId/submit-offer';

  // Pharmacy shell tabs
  static const String phHome = '/home';
  static const String phOrders = '/orders';
  static const String phTenders = '/tenders';
  static const String phOffers = '/offers';
  static const String phListings = '/listings';
  static const String phMore = '/more';

  // الإشعارات — نفس الشاشة للجهتين، والبادئة هي ما يحدّد الصندوق والتوكن.
  static const String phNotifications = '/notifications';
  static const String phNotificationSettings = '/notifications/settings';
  static const String whNotifications = '/wh/notifications';
  static const String whNotificationSettings = '/wh/notifications/settings';

  // معرض نظام التصميم (للتطوير)
  static const String devGallery = '/dev/gallery';

  // Warehouse shell tabs
  static const String whHome = '/wh/home';
  static const String whOrders = '/wh/orders';
  static const String whTenders = '/wh/tenders';
  static const String whOffers = '/wh/offers';
  static const String whListings = '/wh/listings';
  static const String whMore = '/wh/more';
}
