import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawrid_app/core/constants/storage_keys.dart';
import 'session_state.dart';

final warehouseSessionProvider =
    AsyncNotifierProvider<WarehouseSessionNotifier, WarehouseSessionState>(
  WarehouseSessionNotifier.new,
);

class WarehouseSessionNotifier extends AsyncNotifier<WarehouseSessionState> {
  static const _store = FlutterSecureStorage();

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
    return WarehouseSessionAuthenticated(token: token, warehouseUserId: userId, warehouseId: whId);
  }

  Future<void> establish({
    required String token,
    String? warehouseUserId,
    String? warehouseId,
  }) async {
    await _store.write(key: StorageKeys.warehouseToken, value: token);
    if (warehouseUserId != null) await _store.write(key: StorageKeys.warehouseUserId, value: warehouseUserId);
    if (warehouseId != null) await _store.write(key: StorageKeys.warehouseId, value: warehouseId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.hasWarehouseSession, true);
    state = AsyncData(WarehouseSessionAuthenticated(
      token: token, warehouseUserId: warehouseUserId, warehouseId: warehouseId));
  }

  Future<void> clear() async {
    const store = FlutterSecureStorage();
    await store.delete(key: StorageKeys.warehouseToken);
    await store.delete(key: StorageKeys.warehouseUserId);
    await store.delete(key: StorageKeys.warehouseId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.hasWarehouseSession, false);
    state = const AsyncData(WarehouseSessionUnauthenticated());
  }
}
