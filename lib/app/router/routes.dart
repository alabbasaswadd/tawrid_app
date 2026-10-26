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
  static const String phMedicineSearch = '/medicines/search';
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
