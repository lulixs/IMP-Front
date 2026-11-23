import 'box.dart';

/// What the New Box page sends when the employee taps Save box. It holds every field of `POST /api/boxes`
/// (IMP-Back docs/api/boxes.md), so Connect can send `toJson()` as the request body as it is.
class NewBox {
  final int categoryId;
  final int buildingId;

  /// One to three capital letters. The page makes them capitals as they are typed.
  final String shelfLetter;
  final int shelfLevel;
  final Fullness fullness;

  /// Trimmed, and null when blank.
  final String? notes;

  /// The day the box went into storage, a date with no time. Today, or earlier for a box that was already stored.
  final DateTime rackedSince;

  const NewBox({
    required this.categoryId,
    required this.buildingId,
    required this.shelfLetter,
    required this.shelfLevel,
    required this.fullness,
    required this.notes,
    required this.rackedSince,
  });

  /// The request body, in the contract's shape (`categoryID` and `buildingID` are spelled that way there).
  Map<String, dynamic> toJson() {
    String two(int n) => n.toString().padLeft(2, '0');
    return {
      'categoryID': categoryId,
      'buildingID': buildingId,
      'shelfLetter': shelfLetter,
      'shelfLevel': shelfLevel,
      'fullness': switch (fullness) {
        Fullness.empty => 'EMPTY',
        Fullness.half => 'HALF',
        Fullness.full => 'FULL',
      },
      'notes': notes,
      'rackedSince': '${rackedSince.year.toString().padLeft(4, '0')}-${two(rackedSince.month)}-${two(rackedSince.day)}',
    };
  }
}
