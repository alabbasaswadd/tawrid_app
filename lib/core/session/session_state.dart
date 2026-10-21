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
  });
  final String token;
  final String? userId;
  final String? tenantId;
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
  });
  final String token;
  final String? warehouseUserId;
  final String? warehouseId;
}

class WarehouseSessionUnauthenticated extends WarehouseSessionState {
  const WarehouseSessionUnauthenticated();
}
