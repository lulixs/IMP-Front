// one employee
class Employee {
  final int id;
  final String name;

  const Employee({required this.id, required this.name});

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(id: json["id"] as int, name: json["name"] as String);
  }
}
