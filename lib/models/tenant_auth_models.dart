class TenantAuthResponse {
  final String token;
  final String tenantId;
  final String pharmacyName;
  final String email;

  TenantAuthResponse({
    required this.token,
    required this.tenantId,
    required this.pharmacyName,
    required this.email,
  });

  factory TenantAuthResponse.fromJson(Map<String, dynamic> j) => TenantAuthResponse(
        token: j['token'] as String,
        tenantId: j['tenantId'] as String,
        pharmacyName: j['pharmacyName'] as String,
        email: j['email'] as String,
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

  /// عملة أسعار صيدليتي فيما أعرضه أنا (عروض الفائض) — مشتقّة من محافظتي.
  /// لا أثر لها على ما أشتريه: سعر المستودع يُعرَض بعملة المستودع.
  final String pricingCurrency;

  TenantMe({
    required this.tenantId,
    required this.pharmacyName,
    required this.email,
    required this.phone,
    required this.governorate,
    this.city,
    this.address,
    this.pricingCurrency = 'SYP',
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
      );
}
