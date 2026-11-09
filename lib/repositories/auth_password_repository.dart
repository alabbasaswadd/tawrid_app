import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';

final authPasswordRepositoryProvider = Provider<AuthPasswordRepository>((ref) {
  return AuthPasswordRepository(ref.watch(apiClientProvider));
});

/// تغيير كلمة المرور لجهتَي الصيدلية والمستودع.
///
/// مستودعٌ واحد لا اثنان: الطلب واحد الشكل، ولا يختلف إلا المسار — والجهة
/// تُعرَف من التوكن في الخادم لا من جسم الطلب.
class AuthPasswordRepository {
  AuthPasswordRepository(this._api);
  final ApiClient _api;

  /// [currentPassword] اختيارية: الخادم يُسقِط اشتراطها في حالة إعادة
  /// التعيين الإجبارية وحدها (<c>MustChangePassword</c>) — التوكن هناك صادرٌ
  /// عن دخولٍ بالكلمة نفسها قبل لحظات. أما التغيير الاختياري لاحقاً فيشترطها.
  Future<void> changePassword({
    required bool isWarehouse,
    String? currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      isWarehouse
          ? ApiEndpoints.whChangePassword
          : ApiEndpoints.phChangePassword,
      data: {
        if (currentPassword != null) 'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }
}
