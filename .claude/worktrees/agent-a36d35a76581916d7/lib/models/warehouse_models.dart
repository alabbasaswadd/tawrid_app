class WarehousePicker {
  final String id;
  final String name;
  final String code;
  final String city;
  final String governorate;

  WarehousePicker({
    required this.id,
    required this.name,
    required this.code,
    required this.city,
    required this.governorate,
  });

  factory WarehousePicker.fromJson(Map<String, dynamic> j) => WarehousePicker(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        city: j['city'] as String,
        governorate: j['governorate'] as String,
      );
}
