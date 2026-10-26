import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/notifications/push_service.dart';
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
    final status = AccountStatus.fromName(
      await _store.read(key: StorageKeys.pharmacyAccountStatus),
    );
    return SessionAuthenticated(
      token: token,
      userId: userId,
      tenantId: tenantId,
      accountStatus: status,
    );
  }

  Future<void> establish({
    required String token,
    String? userId,
    String? tenantId,
    AccountStatus accountStatus = AccountStatus.approved,
  }) async {
    await _store.write(key: StorageKeys.pharmacyToken, value: token);
    if (userId != null) {
      await _store.write(key: StorageKeys.pharmacyUserId, value: userId);
    }
    if (tenantId != null) {
      await _store.write(key: StorageKeys.pharmacyTenantId, value: tenantId);
    }
    await _store.write(
      key: StorageKeys.pharmacyAccountStatus,
      value: accountStatus.name,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.hasPharmacySession, true);
    state = AsyncData(
      SessionAuthenticated(
        token: token,
        userId: userId,
        tenantId: tenantId,
        accountStatus: accountStatus,
      ),
    );

    // تسجيل الجهاز بعد قيام الجلسة لا قبلها: الطلب يحتاج توكناً، ولا
    // نعرف قبلها لأي جهة نُسجّل. لا ننتظره حتى لا يؤخّر دخول المستخدم.
    unawaited(
        ref.read(pushServiceProvider).registerForSession(isWarehouse: false));
  }

  // تحديث حالة الحساب فقط (من /auth/me) دون المساس بالتوكن.
  Future<void> setAccountStatus(AccountStatus status) async {
    final current = state.value;
    if (current is! SessionAuthenticated) return;
    await _store.write(
      key: StorageKeys.pharmacyAccountStatus,
      value: status.name,
    );
    state = AsyncData(
      SessionAuthenticated(
        token: current.token,
        userId: current.userId,
        tenantId: current.tenantId,
        accountStatus: status,
      ),
    );
  }

  Future<void> clear() async {
    // إلغاء تسجيل الجهاز قبل محو التوكن — بعده يصبح الطلب بلا مصادقة.
    // بلا هذا تواصل إشعارات الحساب السابق الوصول إلى الجهاز بعد خروجه.
    await ref.read(pushServiceProvider).unregisterForSession(isWarehouse: false);

    // حذف مفاتيح الصيدلي فقط — deleteAll() كانت تمحو أيضاً جلسة
    // المستودع (نفس الـ secure storage الفعلي لكليهما).
    await _store.delete(key: StorageKeys.pharmacyToken);
    await _store.delete(key: StorageKeys.pharmacyUserId);
    await _store.delete(key: StorageKeys.pharmacyTenantId);
    await _store.delete(key: StorageKeys.pharmacyAccountStatus);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.hasPharmacySession, false);
    state = const AsyncData(SessionUnauthenticated());
  }
}
