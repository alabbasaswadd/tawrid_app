import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/warehouse_user_models.dart';

final warehouseUserRepositoryProvider = Provider<WarehouseUserRepository>(
  (ref) => WarehouseUserRepository(ref.watch(apiClientProvider)),
);

// إدارة موظّفي المستودع. كل نقطة هنا محميّة بسياسة Warehouse.Admin في
// الخادم، والمستودع يُؤخذ من التوكن لا من الجسم — فلا يصل مدير إلى موظّفي
// مستودع آخر حتى لو عرف معرّفه.
class WarehouseUserRepository {
  WarehouseUserRepository(this._api);
  final ApiClient _api;

  Future<List<WarehouseUser>> getUsers() async {
    final raw = await _api.get(ApiEndpoints.whUsers);
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => WarehouseUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WarehouseUser> createUser({
    required String firstName,
    required String lastName,
    required String userName,
    required String email,
    required String phone,
    required String password,
    required WarehouseUserRole role,
    String? shamCashAccount,
  }) async {
    final data = await _api.post(ApiEndpoints.whUsers, data: {
      'firstName': firstName,
      'lastName': lastName,
      'userName': userName,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role.code,
      'shamCashAccount': shamCashAccount,
    }) as Map<String, dynamic>;
    return WarehouseUser.fromJson(data);
  }

  /// تعديل جزئي: ما يُترك `null` لا يُمسّ في الخادم.
  Future<WarehouseUser> updateUser(
    String id, {
    String? firstName,
    String? lastName,
    String? phone,
    String? shamCashAccount,
    WarehouseUserRole? role,
  }) async {
    final data = await _api.put(ApiEndpoints.whUserById(id), data: {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'shamCashAccount': shamCashAccount,
      'role': role?.code,
    }) as Map<String, dynamic>;
    return WarehouseUser.fromJson(data);
  }

  /// الإيقاف يسري على توكن الموظّف فوراً (الخادم يُبطل مخبّأ AccountGate).
  Future<void> setActive(String id, bool isActive) =>
      _api.patch(ApiEndpoints.whUserActive(id), data: {'isActive': isActive});

  /// تعيين كلمة مرور جديدة. تنبيه: التوكن القائم للموظّف يبقى صالحاً بعدها —
  /// لقطع وصوله فوراً يجب إيقاف حسابه.
  Future<void> resetPassword(String id, String newPassword) =>
      _api.post(ApiEndpoints.whUserPassword(id), data: {'newPassword': newPassword});
}
