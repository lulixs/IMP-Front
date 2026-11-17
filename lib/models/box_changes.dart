import 'box.dart';

/// What the Box page sends when the employee taps Save changes. It holds every field of
/// `PUT /api/boxes/{id}` (IMP-Back docs/api/boxes.md), changed or not, so Connect can send
/// `toJson()` as the request body as it is.
class BoxChanges {
  final int categoryId;
  final int buildingId;
  final String shelfLetter;
  final int shelfLevel;
  final Fullness fullness;
  final String? notes;
  final bool isRacked;

  /// Only used when this save re-racks the box: true sets the storage timer to today.
  final bool resetRackedSince;

  /// The box's lastUpdatedAt from when the page loaded it, so the server can tell if
  /// someone else saved the box in the meantime (D-174).
  final DateTime? lastUpdatedAt;

  const BoxChanges({
    required this.categoryId,
    required this.buildingId,
    required this.shelfLetter,
    required this.shelfLevel,
    required this.fullness,
    required this.notes,
    required this.isRacked,
    required this.resetRackedSince,
    required this.lastUpdatedAt,
  });

  /// The request body, in the contract's shape.
  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'buildingId': buildingId,
      'shelfLetter': shelfLetter,
      'shelfLevel': shelfLevel,
      'fullness': switch (fullness) {
        Fullness.empty => 'EMPTY',
        Fullness.half => 'HALF',
        Fullness.full => 'FULL',
      },
      'notes': notes,
      'isRacked': isRacked,
      'resetRackedSince': resetRackedSince,
      'lastUpdatedAt': lastUpdatedAt?.toUtc().toIso8601String(),
    };
  }
}
