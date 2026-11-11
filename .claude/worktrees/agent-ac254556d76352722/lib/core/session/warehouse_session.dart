import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawrid_app/core/constants/storage_keys.dart';
import 'package:tawrid_app/core/notifications/push_service.dart';
import 'package:tawrid_app/core/storage/app_secure_storage.dart';

import 'session_state.dart';

final warehouseSessionProvider =
    AsyncNotifierProvider<WarehouseSessionNotifier, WarehouseSessionState>(
      WarehouseSessionNotifier.new,
    );

class WarehouseSessionNotifier extends AsyncNotifier<WarehouseSessionState> {
  static const _store = appSecureStorage;

  @override
  Future<WarehouseSessionState> build() async {
    final prefs = await SharedPreferences.getInstance();
    var hasSession = prefs.getBool(StorageKeys.hasWarehouseSession);
    if (hasSession == null) {
      final token = await _store.read(key: StorageKeys.warehouseToken);
      hasSession = token != null && token.isNotEmpty;
      await prefs.setBool(StorageKeys.hasWarehouseSession, hasSession);
    }
    if (!hasSession) return const WarehouseSessionUnauthenticated();
    final token = await _store.read(key: StorageKeys.warehouseToken) ?? '';
    final userId = await _store.read(key: StorageKeys.warehouseUserId);
    final whId = await _store.read(key: StorageKeys.warehouseId);
    final status = AccountStatus.fromName(
      await _store.read(key: StorageKeys.warehouseAccountStatus),
    );
    return WarehouseSessionAuthenticated(
      token: token,
      warehouseUserId: userId,
      warehouseId: whId,
      accountStatus: status,
    );
  }

  Future<void> establish({
    required String token,
    String? warehouseUserId,
    String? warehouseId,
    AccountStatus accountStatus = AccountStatus.approved,
  }) async {
    await _store.write(key: StorageKeys.warehouseToken, value: token);
    if (warehouseUserId != null) {
      await _store.write(
        key: StorageKeys.warehouseUserId,
        value: warehouseUserId,
      );
    }
    if (warehouseId != null) {
      await _store.write(key: StorageKeys.warehouseId, value: warehouseId);
    }
    await _store.write(
      key: StorageKeys.warehouseAccountStatus,
      value: accountStatus.name,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.hasWarehouseSession, true);
    state = AsyncData(
      WarehouseSessionAuthenticated(
        token: token,
        warehouseUserId: warehouseUserId,
        warehouseId: warehouseId,
        accountStatus: accountStatus,
      ),
    );

    // تسجيل الجهاز بعد قيام الجلسة لا قبلها: الطلب يحتاج توكناً، ولا
    // نعرف قبلها لأي جهة نُسجّل. لا ننتظره حتى لا يؤخّر دخول المستخدم.
    unawaited(
        ref.read(pushServiceProvider).registerForSession(isWarehouse: true));
  }

  // تحديث حالة الحساب فقط (من /warehouse/auth/me) دون المساس بالتوكن.
  Future<void> setAccountStatus(AccountStatus status) async {
    final current = state.value;
    if (current is! WarehouseSessionAuthenticated) return;
    await _store.write(
      key: StorageKeys.warehouseAccountStatus,
      value: status.name,
    );
    state = AsyncData(
      WarehouseSessionAuthenticated(
        token: current.token,
        warehouseUserId: current.warehouseUserId,
        warehouseId: current.warehouseId,
        accountStatus: status,
      ),
    );
  }

  Future<void> clear() async {
    // إلغاء تسجيل الجهاز قبل محو التوكن — بعده يصبح الطلب بلا مصادقة.
    await ref.read(pushServiceProvider).unregisterForSession(isWarehouse: true);

    const store = appSecureStorage;
    await store.delete(key: StorageKeys.warehouseToken);
    await store.delete(key: StorageKeys.warehouseUserId);
    await store.delete(key: StorageKeys.warehouseId);
    await store.delete(key: StorageKeys.warehouseAccountStatus);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.hasWarehouseSession, false);
    state = const AsyncData(WarehouseSessionUnauthenticated());
  }
}
