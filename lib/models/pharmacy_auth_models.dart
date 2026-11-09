import 'package:tawrid_app/core/session/session_state.dart';

// الصيدلية الحالية كما يُرجعها `GET /auth/me` (TenantMeDto).
class PharmacyMe {
  final String tenantId;
  final String pharmacyName;
  final String email;
  final String phone;
  final String governorate;
  final String city;
  final String address;

  /// عملة أسعار صيدليتي فيما أعرضه أنا (عروض الفائض) — من محافظتي.
  final String pricingCurrency;

  /// كلمة المرور ما زالت الافتراضية — يحجب الموجِّه كل شيء عدا شاشة
  /// تغييرها.
  final bool mustChangePassword;

  final AccountStatus accountStatus;

  const PharmacyMe({
    required this.tenantId,
    required this.pharmacyName,
    required this.email,
    required this.phone,
    required this.governorate,
    required this.city,
    required this.address,
    this.pricingCurrency = 'SYP',
    this.mustChangePassword = false,
    this.accountStatus = AccountStatus.approved,
  });

  /// «إدلب - سراقب» — منطقة الصيدلية كما تُعرض في الواجهة.
  String get areaLabel => city.isEmpty ? governorate : '$governorate - $city';

  factory PharmacyMe.fromJson(Map<String, dynamic> j) => PharmacyMe(
        tenantId: j['tenantId'] as String,
        pharmacyName: j['pharmacyName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        governorate: j['governorate'] as String? ?? '',
        city: j['city'] as String? ?? '',
        address: j['address'] as String? ?? '',
        pricingCurrency: j['pricingCurrency'] as String? ?? 'SYP',
        mustChangePassword: j['mustChangePassword'] as bool? ?? false,
        accountStatus: AccountStatus.fromApi(j['accountStatus']),
      );
}
