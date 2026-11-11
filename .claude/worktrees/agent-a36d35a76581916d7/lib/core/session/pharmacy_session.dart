import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/storage/app_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawrid_app/core/constants/storage_keys.dart';
import 'session_state.dart';

final pharmacySessionProvider =
    AsyncNotifierProvider<PharmacySessionNotifier, SessionState>(
  PharmacySessionNotifier.new,
);

class PharmacySessionNotifier extends AsyncNotifier<SessionState> {
  static const _store = appSecureStorage;

  @override
  Future<SessionState> build() async {
    final prefs = await SharedPreferences.getInstance();
    var hasSession = prefs.getBool(StorageKeys.hasPharmacySession);
    if (hasSession == null) {
      final token = await _store.read(key: StorageKeys.pharmacyToken);
      hasSession = token != null && token.isNotEmpty;
      await prefs.setBool(StorageKeys.hasPharmacySession, hasSession);
    }
    if (!hasSession) return const SessionUnauthenticated();
    final token = await _store.read(key: StorageKeys.pharmacyToken) ?? '';
    final userId = await _store.read(key: StorageKeys.pharmacyUserId);
    final tenantId = await _store.read(key: StorageKeys.pharmacyTenantId);
    return SessionAuthenticated(token: token, userId: userId, tenantId: tenantId);
  }

  Future<void> establish({
    required String token,
    String? userId,
    String? tenantId,
  }) async {
    await _store.write(key: StorageKeys.pharmacyToken, value: token);
    if (userId != null) await _store.write(key: StorageKeys.pharmacyUserId, value: userId);
    if (tenantId != null) await _store.write(key: StorageKeys.pharmacyTenantId, value: tenantId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.hasPharmacySession, true);
    state = AsyncData(SessionAuthenticated(token: token, userId: userId, tenantId: tenantId));
  }

  Future<void> clear() async {
    // حذف مفاتيح الصيدلي فقط — deleteAll() كانت تمحو أيضاً جلسة
    // المستودع (نفس الـ secure storage الفعلي لكليهما).
    await _store.delete(key: StorageKeys.pharmacyToken);
    await _store.delete(key: StorageKeys.pharmacyUserId);
    await _store.delete(key: StorageKeys.pharmacyTenantId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.hasPharmacySession, false);
    state = const AsyncData(SessionUnauthenticated());
  }
}
