import 'enums.dart';

class WarehouseAuthResponse {
  final String token;
  final String warehouseUserId;
  final String warehouseId;
  final String warehouseName;
  final String userName;
  final WarehouseUserRole role;

  WarehouseAuthResponse({
    required this.token,
    required this.warehouseUserId,
    required this.warehouseId,
    required this.warehouseName,
    required this.userName,
    required this.role,
  });

  factory WarehouseAuthResponse.fromJson(Map<String, dynamic> j) => WarehouseAuthResponse(
        token: j['token'] as String,
        warehouseUserId: j['warehouseUserId'] as String,
        warehouseId: j['warehouseId'] as String,
        warehouseName: j['warehouseName'] as String,
        userName: j['userName'] as String,
        role: WarehouseUserRole.fromCode(j['role'] as int),
      );
}

class WarehouseMe {
  final String warehouseUserId;
  final String warehouseId;
  final String firstName;
  final String lastName;
  final String userName;
  final String email;
  final String phone;
  final WarehouseUserRole role;
  final String warehouseName;
  final String warehouseCode;
  final String city;
  final String governorate;
  final String? logoUrl;

  WarehouseMe({
    required this.warehouseUserId,
    required this.warehouseId,
    required this.firstName,
    required this.lastName,
    required this.userName,
    required this.email,
    required this.phone,
    required this.role,
    required this.warehouseName,
    required this.warehouseCode,
    required this.city,
    required this.governorate,
    this.logoUrl,
  });

  factory WarehouseMe.fromJson(Map<String, dynamic> j) => WarehouseMe(
        warehouseUserId: j['warehouseUserId'] as String,
        warehouseId: j['warehouseId'] as String,
        firstName: j['firstName'] as String,
        lastName: j['lastName'] as String,
        userName: j['userName'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String,
        role: WarehouseUserRole.fromCode(j['role'] as int),
        warehouseName: j['warehouseName'] as String,
        warehouseCode: j['warehouseCode'] as String,
        city: j['city'] as String,
        governorate: j['governorate'] as String,
        logoUrl: j['logoUrl'] as String?,
      );
}
