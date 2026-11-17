class Building{
  final int id;
  final String name;

  const Building({
    required this.id,
    required this.name,
  });

  factory Building.fromJson(Map<String, dynamic> json){
    return Building(
      id: json["id"] as int,
      name: json["name"] as String
    );
  }
}