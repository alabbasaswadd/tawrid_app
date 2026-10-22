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
  final List<City> cities;

  Governorate({required this.id, required this.name, required this.cities});

  factory Governorate.fromJson(Map<String, dynamic> j) => Governorate(
        id: j['id'] as String,
        name: j['name'] as String,
        cities: ((j['cities'] as List?) ?? [])
            .map((e) => City.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
