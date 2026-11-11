abstract final class StorageKeys {
  // Pharmacy session
  static const String pharmacyToken = 'pharmacy_access_token';
  static const String pharmacyUserId = 'pharmacy_user_id';
  static const String pharmacyTenantId = 'pharmacy_tenant_id';
  static const String pharmacyAccountStatus = 'pharmacy_account_status';
  static const String hasPharmacySession = 'has_pharmacy_session';

  // Warehouse session
  static const String warehouseToken = 'warehouse_access_token';
  static const String warehouseUserId = 'warehouse_user_id';
  static const String warehouseId = 'warehouse_id';
  static const String warehouseAccountStatus = 'warehouse_account_status';
  static const String hasWarehouseSession = 'has_warehouse_session';

  // ── الإشعارات الفورية ─────────────────────────────────────────────
  // آخر رمز FCM سُجّل، ولأي جهة سُجّل. نحتفظ بالاثنين معاً لأن الرمز
  // الواحد قد ينتقل بين حساب صيدلية وحساب مستودع على الجهاز نفسه،
  // فنعرف متى نُعيد التسجيل ومن أي مسار نُلغيه عند الخروج.
  static const String fcmToken = 'fcm_token';
  static const String fcmTokenOwner = 'fcm_token_owner';

  /// معرّف ثابت للجهاز يُولَّد مرة ويبقى — يميّز أجهزة الحساب الواحد.
  static const String deviceId = 'device_id';
}
