import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';

/// منصّة الجهاز كما يعرفها الخادم (DevicePlatformEnum).
enum DevicePlatform {
  android(1),
  ios(2),
  web(3);

  const DevicePlatform(this.code);
  final int code;
}

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepository(ref.watch(apiClientProvider)),
);

// تسجيل جهاز الإشعارات. الجهة تُحدَّد ببادئة المسار: `/auth/devices`
// للصيدلية و`/warehouse/auth/devices` للمستودع — والخادم يخزّنها في صفٍّ
// واحد لكل رمز FCM مع نوع المالك، فأجهزة المستودعات منفصلة عن أجهزة
// الصيدليات ولو كان الجهاز نفسه.
//
// الرمز الواحد ينتقل ملكيّته عند تسجيل دخول حساب آخر على الجهاز نفسه
// (upsert في الخادم) فلا تذهب إشعارات الحساب الجديد إلى السابق.
class DeviceRepository {
  DeviceRepository(this._api);
  final ApiClient _api;

  Future<void> register({
    required bool isWarehouse,
    required String token,
    required DevicePlatform platform,
    required String deviceId,
  }) =>
      _api.post(ApiEndpoints.devices(isWarehouse), data: {
        'token': token,
        'platform': platform.code,
        'deviceId': deviceId,
      });

  Future<void> unregister({
    required bool isWarehouse,
    required String token,
  }) =>
      _api.delete(ApiEndpoints.deviceByToken(isWarehouse, token));
}
