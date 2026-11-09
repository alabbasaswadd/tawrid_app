class City {
  final String id;
  final String name;

  City({required this.id, required this.name});

  factory City.fromJson(Map<String, dynamic> j) => City(
        id: j['id'] as String,
        name: j['name'] as String,
      );
}

class Governorate {
  final String id;
  final String name;

  /// عملة التعامل السائدة في المحافظة — منها تُشتقّ عملة تسعير كل مستودع
  /// وصيدلية تُسجَّل فيها (إدلب بالدولار، والباقي بالليرة).
  final String defaultCurrency;

  final List<City> cities;

  Governorate({
    required this.id,
    required this.name,
    this.defaultCurrency = 'SYP',
    required this.cities,
  });

  factory Governorate.fromJson(Map<String, dynamic> j) => Governorate(
        id: j['id'] as String,
        name: j['name'] as String,
        defaultCurrency: j['defaultCurrency'] as String? ?? 'SYP',
        cities: ((j['cities'] as List?) ?? [])
            .map((e) => City.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
