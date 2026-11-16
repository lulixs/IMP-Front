class Category{
    final int id;
    final String name;
    final String? symbol;

    const Category({
        required this.id,
        required this.name,
        required this.symbol
    });

    factory Category.fromJson(Map<String, dynamic> json){
        return Category(
            id:json["id"] as int,
            name: json["name"] as String,
            symbol: json["symbol"] as String?,
        );
    }
}