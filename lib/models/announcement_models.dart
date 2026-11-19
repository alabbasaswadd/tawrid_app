class WarehouseAnnouncement {
  final String id;
  final String title;
  final String? body;
  final int discountType;
  final double discountValue;
  final DateTime validUntil;
  final bool isActive;
  final DateTime createdOn;

  WarehouseAnnouncement({
    required this.id,
    required this.title,
    this.body,
    required this.discountType,
    required this.discountValue,
    required this.validUntil,
    required this.isActive,
    required this.createdOn,
  });

  factory WarehouseAnnouncement.fromJson(Map<String, dynamic> j) =>
      WarehouseAnnouncement(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        discountType: j['discountType'] as int,
        discountValue: (j['discountValue'] as num).toDouble(),
        validUntil: DateTime.parse(j['validUntil'] as String),
        isActive: j['isActive'] as bool,
        createdOn: DateTime.parse(j['createdOn'] as String),
      );

  String get discountLabel => 'خصم ${discountValue.toStringAsFixed(0)}٪ على الفاتورة';
}
