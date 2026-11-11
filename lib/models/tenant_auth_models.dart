import 'package:tawrid_app/core/session/session_state.dart';

class TenantAuthResponse {
  final String token;
  final String tenantId;
  final String pharmacyName;
  final String email;
  final AccountStatus accountStatus;
  final bool mustChangePassword;

  TenantAuthResponse({
    required this.token,
    required this.tenantId,
    required this.pharmacyName,
    required this.email,
    this.accountStatus = AccountStatus.approved,
    this.mustChangePassword = false,
  });

  factory TenantAuthResponse.fromJson(Map<String, dynamic> j) => TenantAuthResponse(
        token: j['token'] as String,
        tenantId: j['tenantId'] as String,
        pharmacyName: j['pharmacyName'] as String,
        email: j['email'] as String,
        accountStatus: AccountStatus.fromApi(j['accountStatus']),
        mustChangePassword: j['mustChangePassword'] as bool? ?? false,
      );
}

class TenantMe {
  final String tenantId;
  final String pharmacyName;
  final String email;
  final String phone;
  final String governorate;
  final String? city;
  final String? address;
  final String pricingCurrency;
  final bool mustChangePassword;

  TenantMe({
    required this.tenantId,
    required this.pharmacyName,
    required this.email,
    required this.phone,
    required this.governorate,
    this.city,
    this.address,
    this.pricingCurrency = 'SYP',
    this.mustChangePassword = false,
  });

  factory TenantMe.fromJson(Map<String, dynamic> j) => TenantMe(
        tenantId: j['tenantId'] as String,
        pharmacyName: j['pharmacyName'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String,
        governorate: j['governorate'] as String,
        city: j['city'] as String?,
        address: j['address'] as String?,
        pricingCurrency: j['pricingCurrency'] as String? ?? 'SYP',
        mustChangePassword: j['mustChangePassword'] as bool? ?? false,
      );
}
