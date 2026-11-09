abstract final class TRoutes {
  // Splash
  static const String splash = '/';

  // Pharmacy auth
  static const String phLogin = '/login';
  static const String phRegister = '/register';

  // حالة الحساب (قيد المراجعة/مرفوض) — تحجب التطبيق لغير المقبول
  static const String accountStatus = '/account-status';

  /// إعادة تعيين إجبارية لكلمة المرور — تحجب كل شيء ما دام الحساب بكلمته
  /// الافتراضية، كما تحجب accountStatus الحسابَ غير المقبول.
  static const String forcePasswordChange = '/force-password-change';

  // Warehouse auth
  static const String whLogin = '/wh/login';
  static const String whRegister = '/wh/register';
  static const String whServiceAreas = '/wh/service-areas';
  static const String whProfile = '/wh/profile';
  static const String whUsers = '/wh/users';

  // إعدادات الطلبيات (الحدّ الأدنى) — إعداد بائع يضبطه كل مستودع لنفسه.
  static const String whOrderSettings = '/wh/settings/orders';

  // تفاصيل عرض البيع عند المستودع (مالك العرض)
  static const String whOfferDetailPattern = '/wh/offers/:offerId';
  static String whOfferDetail(String id) => '/wh/offers/$id';

  // تفاصيل الطلب الوارد عند المستودع
  static const String whOrderDetailPattern = '/wh/orders/:orderId';
  static String whOrderDetail(String id) => '/wh/orders/$id';
  static const String phMedicineSearch = '/medicines/search';

  // بحث الأسعار المقارن (عروض + تسعير مباشر) والسلّة المبنيّة من نتائجه.
  // السلّة محفوظة على الخادم ومجمَّعة فيه حسب المستودع.
  static const String phPriceSearch = '/medicines/prices';

  /// كاتالوج المستودعات — «من يبيع هذا الدواء الآن وبكم؟». شاشة مستقلّة
  /// عن الكتالوج الوطني: سؤالٌ آخر ومجموعةُ فلاترٍ أخرى.
  static const String phWarehouseCatalog = '/medicines/warehouse-catalog';

  /// بحث الأسعار محصوراً بمستودع واحد — يُفتح من ملف المستودع.
  /// الاسم يُمرَّر للعنوان فقط؛ الخادم يفلتر بالمعرّف.
  static String phPriceSearchInWarehouse(String warehouseId, String name) =>
      '$phPriceSearch?warehouseId=$warehouseId'
      '&warehouseName=${Uri.encodeComponent(name)}';

  /// مقارنة سعر دواء بعينه عبر كل مستودعات الصيدلية — من بطاقة نتيجة بحث.
  /// catalogItemId إن وُجد يحصر المطابقة بصنف الكتالوج بعينه؛ وإلا تُستخدم
  /// اسم الدواء نصاً فقط.
  static String phPriceCompareItem({String? catalogItemId, required String name}) {
    final q = 'q=${Uri.encodeComponent(name)}';
    if (catalogItemId == null || catalogItemId.isEmpty) return '$phPriceSearch?$q';
    return '$phPriceSearch?catalogItemId=$catalogItemId&$q';
  }
  /// توفّر دواءٍ من الكتالوج في المستودعات: مطابقاته + البدائل التي تحمل
  /// تركيبه العلمي نفسه. يحتاج معرّف صنف الكتالوج ليعرف الخادم أيّ تركيب
  /// يقصد — من دونه لا بدائل، فيبقى بحثاً عادياً بالاسم.
  static String phMedicineInWarehouses({
    required String catalogItemId,
    required String name,
  }) =>
      '$phPriceSearch?catalogItemId=$catalogItemId'
      '&q=${Uri.encodeComponent(name)}'
      '&alternatives=1';

  static const String phCart = '/cart';

  // تفاصيل عرض بيع عند الصيدلي — منها تُنشأ الطلبية باختيار الأصناف
  static const String phOfferDetailPattern = '/offers/:offerId';
  static String phOfferDetail(String id) => '/offers/$id';

  // طلبات التسعير: إنشاء + مقارنة عروض الأسعار والترسية
  static const String phCreateTender = '/tenders/create';
  static const String phCompareQuotationsPattern = '/tenders/:requestId';
  static String phCompareQuotations(String id) => '/tenders/$id';

  // إنشاء طلبية توريد جديدة مباشرة (اختيار مستودع + أصناف)

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

  // الملف الشخصي للصيدلية
  static const String phProfile = '/profile';

  // تقرير مشترياتي — ملخّص إحصائي للطلبيات
  static const String phReports = '/reports';

  // تقرير طلبات التسعير — توزيع حالات + أحدث الطلبات
  static const String phTenderReports = '/reports/tenders';

  // Pharmacy shell tabs
  static const String phHome = '/home';
  static const String phOrders = '/orders';
  static const String phOffers = '/offers';
  static const String phMore = '/more';

  // طلبات التسعير — قائمة + إنشاء (top-level, بلا شريط تنقل)
  static const String phTenders = '/tenders';

  // صيدلي إلى صيدلي: تصفح + إعلاناتي + إنشاء + تفاصيل + محادثة
  static const String phListings = '/listings';
  static const String phMyListings = '/my-listings';
  static const String phListingCreate = '/listings/create';
  static const String phListingDetailPattern = '/listings/:listingId';
  static String phListingDetail(String id) => '/listings/$id';

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
