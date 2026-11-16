import 'category.dart';
import 'building.dart';

class EmployeeReference{
    final int id;
    final String name;

    const EmployeeReference({
        required this.id,
        required this.name,
});

    factory EmployeeReference.fromJson(Map<String, dynamic> json){
        return EmployeeReference(
            id: json["id"] as int,
            name: json["name"] as String,
        );
    }
}

enum Fullness{ empty, half, full }

class Box{
    final int id;
    final Category category;
    final Building building;
    final String shelfLetter;
    final int shelfLevel;
    final Fullness fullness;
    final String? notes;
    final bool isRacked;
    final DateTime rackedSince;
    final int daysStored;
    final bool storedTooLong;
    final DateTime createdAt;
    final EmployeeReference createdBy;
    final DateTime? lastUpdatedAt;
    final EmployeeReference? lastUpdatedBy;
    final DateTime? deletedAt;
    final EmployeeReference? deletedBy;
    
    const Box({
        required this.id,
        required this.category,
        required this.building,
        required this.shelfLetter,
        required this.shelfLevel,
        required this.fullness,
        required this.notes,
        required this.isRacked,
        required this.rackedSince,
        required this.daysStored,
        required this.storedTooLong,
        required this.createdAt,
        required this.createdBy,
        required this.lastUpdatedAt,
        required this.lastUpdatedBy,
        required this.deletedAt,
        required this.deletedBy,
    });

    factory Box.fromJson(Map<String, dynamic> json){
        final fullness = switch(json["fullness"]){
            "EMPTY" => Fullness.empty,
            "HALF" => Fullness.half,
            "FULL" => Fullness.full,
            _ => throw FormatException('Unknown fullness amount: ${json["fullness"]}'),
        };

        return Box(
            id: json["id"] as int,
            category: Category.fromJson(json["category"]),
            building: Building.fromJson(json["building"]),
            shelfLetter: json["shelfLetter"] as String,
            shelfLevel: json["shelfLevel"] as int,
            fullness: fullness,
            notes: json["notes"] as String?,
            isRacked: json["isRacked"] as bool,
            rackedSince: DateTime.parse(json["rackedSince"]),
            daysStored: json["daysStored"] as int,
            storedTooLong: json["storedTooLong"] as bool,
            createdAt: DateTime.parse(json["createdAt"]),
            createdBy: EmployeeReference.fromJson(json["createdBy"]),
            lastUpdatedAt: json["lastUpdatedAt"] == null ? null : DateTime.parse(json["lastUpdatedAt"]),
            lastUpdatedBy: json["lastUpdatedBy"] == null ? null : EmployeeReference.fromJson(json["lastUpdatedBy"]),
            deletedAt: json["deletedAt"] == null ? null : DateTime.parse(json["deletedAt"]),
            deletedBy: json["deletedBy"] == null ? null : EmployeeReference.fromJson(json["deletedBy"]),
        );
    }
}