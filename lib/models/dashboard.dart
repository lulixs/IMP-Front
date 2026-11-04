class DashboardData {
  final int alertThresholdDays;
  final List<DashboardCategory> categories;

  // constructor
  const DashboardData({required this.alertThresholdDays, required this.categories});

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final rawCategories = json["categories"] as List; // raw list of categories as json

    final categories = <DashboardCategory>[];  // list of actual category objects

    for (final cat in rawCategories) {
      categories.add(DashboardCategory.fromJson(cat));
    }

    return DashboardData(
      alertThresholdDays: json["alertThresholdDays"] as int,
      categories: categories,
    );
  }
}

class DashboardCategory {
  final int id;
  final String name;
  final String? symbol; // the symbol can be null
  final int fullCount;
  final int halfCount;
  final int emptyCount;
  final int storedTooLongCount;

  const DashboardCategory({
    required this.id,
    required this.name,
    required this.symbol,
    required this.fullCount,
    required this.halfCount,
    required this.emptyCount,
    required this.storedTooLongCount,
  });

  factory DashboardCategory.fromJson(Map<String, dynamic> json) {
    return DashboardCategory(
      id: json["id"] as int,
      name: json["name"] as String,
      symbol: json["symbol"] as String?,
      fullCount: json["full"] as int,
      halfCount: json["half"] as int,
      emptyCount: json["empty"] as int,
      storedTooLongCount: json["storedTooLong"] as int,
    );
  }

  // get total method. weird syntax
  int get total => fullCount + halfCount + emptyCount;
}