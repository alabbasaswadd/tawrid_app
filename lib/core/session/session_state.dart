// حالة الحساب على المنصة — تطابق AccountStatusEnum في الباك إند
// (PendingApproval=1, Approved=2, Rejected=3). حالياً التسجيل يقبل مباشرة،
// والبنية جاهزة للموافقة اليدوية لاحقاً.
enum AccountStatus {
  pending,
  approved,
  rejected;

  // يقبل الرقم (التسلسل الافتراضي) أو الاسم النصي احتياطاً، وغيابه يعني مقبول
  // (توافقاً مع الجلسات والردود السابقة على إضافة الحقل).
  static AccountStatus fromApi(Object? value) => switch (value) {
    1 || '1' || 'pendingApproval' || 'PendingApproval' => AccountStatus.pending,
    3 || '3' || 'rejected' || 'Rejected' => AccountStatus.rejected,
    _ => AccountStatus.approved,
  };

  static AccountStatus fromName(String? name) => AccountStatus.values
      .firstWhere((s) => s.name == name, orElse: () => AccountStatus.approved);
}

sealed class SessionState {
  const SessionState();
}

class SessionLoading extends SessionState {
  const SessionLoading();
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated({
    required this.token,
    this.userId,
    this.tenantId,
    this.accountStatus = AccountStatus.approved,
  });
  final String token;
  final String? userId;
  final String? tenantId;
  final AccountStatus accountStatus;
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

sealed class WarehouseSessionState {
  const WarehouseSessionState();
}

class WarehouseSessionLoading extends WarehouseSessionState {
  const WarehouseSessionLoading();
}

class WarehouseSessionAuthenticated extends WarehouseSessionState {
  const WarehouseSessionAuthenticated({
    required this.token,
    this.warehouseUserId,
    this.warehouseId,
    this.accountStatus = AccountStatus.approved,
  });
  final String token;
  final String? warehouseUserId;
  final String? warehouseId;
  final AccountStatus accountStatus;
}

class WarehouseSessionUnauthenticated extends WarehouseSessionState {
  const WarehouseSessionUnauthenticated();
}
