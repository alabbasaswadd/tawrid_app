import 'enums.dart';

// موظّف مستودع كما يُرجعه الخادم (WarehouseUserDto). القائمة تشمل
// الموقوفين — الإيقاف ليس حذفاً، والمدير يحتاج رؤيتهم ليُعيد تفعيلهم.
class WarehouseUser {
  final String id;
  final String firstName;
  final String lastName;
  final String userName;
  final String email;
  final String phone;
  final String? shamCashAccount;
  final WarehouseUserRole role;
  final bool isActive;
  final DateTime createdOn;

  const WarehouseUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.userName,
    required this.email,
    required this.phone,
    this.shamCashAccount,
    required this.role,
    required this.isActive,
    required this.createdOn,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory WarehouseUser.fromJson(Map<String, dynamic> j) => WarehouseUser(
        id: j['id'] as String,
        firstName: j['firstName'] as String,
        lastName: j['lastName'] as String,
        userName: j['userName'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String,
        shamCashAccount: j['shamCashAccount'] as String?,
        role: WarehouseUserRole.fromCode(j['role'] as int),
        isActive: j['isActive'] as bool,
        createdOn: DateTime.parse(j['createdOn'] as String),
      );
}
