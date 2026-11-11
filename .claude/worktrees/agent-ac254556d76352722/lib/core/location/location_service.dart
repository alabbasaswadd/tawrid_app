import 'package:geolocator/geolocator.dart';

/// نتيجة محاولة التقاط الموقع — إمّا إحداثيات وإمّا سبب مفهوم للفشل.
sealed class LocationResult {
  const LocationResult();
}

class LocationCaptured extends LocationResult {
  const LocationCaptured(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class LocationFailed extends LocationResult {
  const LocationFailed(this.message, {this.openSettings = false, this.openLocationSettings = false});

  final String message;

  /// الرفض الدائم لا يُعالَج بإعادة الطلب — لا بدّ من إعدادات التطبيق.
  final bool openSettings;

  /// الـ GPS مغلق — لا بدّ من إعدادات الموقع في النظام.
  final bool openLocationSettings;
}

/// التقاط موقع الصيدلية/المستودع وقت إنشاء الحساب.
///
/// كل حالة فشل تُترجَم إلى رسالة عربية تقول ما العمل، لا إلى استثناء خام:
/// «خدمة الموقع مغلقة» و«رُفض الإذن» و«رُفض نهائياً» ثلاث مشاكل مختلفة
/// وعلاجها مختلف، وخلطها في رسالة واحدة يترك المستخدم عالقاً.
class LocationService {
  const LocationService();

  Future<LocationResult> capture() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationFailed(
          'خدمة الموقع (GPS) مغلقة على الجهاز',
          openLocationSettings: true,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationFailed(
          'إذن الموقع مرفوض نهائياً — فعّله من إعدادات التطبيق',
          openSettings: true,
        );
      }

      if (permission == LocationPermission.denied) {
        return const LocationFailed('لا يمكن حفظ موقع الصيدلية بلا إذن الوصول');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // مهلة صريحة: بلا سقف يبقى المستخدم أمام مؤشر دوّار بلا نهاية
          // داخل مبنى ضعيف الإشارة.
          timeLimit: Duration(seconds: 20),
        ),
      );

      return LocationCaptured(position.latitude, position.longitude);
    } catch (e) {
      return LocationFailed('تعذّر تحديد الموقع — حاول في مكان مكشوف ($e)');
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

const locationService = LocationService();
