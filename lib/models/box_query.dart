/// Which boxes the Boxes list shows (the Rack filter in wireframe 04).
enum RackFilter { all, racked, unracked }

/// The order of the Boxes list. Both sort by the date the box went into storage (IMP-Back docs/api/boxes.md).
enum BoxSort { oldest, newest }

/// The search box and the three filters on the Boxes page. [path] is the request for `GET /api/boxes`.
class BoxQuery {
  /// Whatever was typed. Digits (with or without #) match box numbers, other text matches category names.
  final String search;

  /// Only boxes in this category, or null for all of them.
  final int? categoryId;
  final RackFilter rack;
  final BoxSort sort;

  const BoxQuery({
    this.search = '',
    this.categoryId,
    this.rack = RackFilter.all,
    this.sort = BoxSort.oldest,
  });

  /// A copy with some parts changed. [categoryId] is wrapped so null ("all categories") can be chosen: pass `(null,)`
  /// to clear it, or leave it out to keep the current one.
  BoxQuery copyWith({String? search, (int?,)? categoryId, RackFilter? rack, BoxSort? sort}) {
    return BoxQuery(
      search: search ?? this.search,
      categoryId: categoryId == null ? this.categoryId : categoryId.$1,
      rack: rack ?? this.rack,
      sort: sort ?? this.sort,
    );
  }

  // Two queries are the same when they would send the same request, so the page doesn't ask twice for one thing.
  @override
  bool operator ==(Object other) => other is BoxQuery && other.path == path;

  @override
  int get hashCode => path.hashCode;

  /// `/api/boxes` with the filters that are set. Uri escapes the typed text, so "#67" or "&" can't break the address.
  String get path {
    final text = search.trim();
    final params = <String, String>{
      if (text.isNotEmpty) 'search': text,
      if (categoryId != null) 'categoryId': '$categoryId',
      if (rack == RackFilter.racked) 'racked': 'true',
      if (rack == RackFilter.unracked) 'racked': 'false',
      'sort': sort == BoxSort.newest ? 'newest' : 'oldest',
    };
    return Uri(path: '/api/boxes', queryParameters: params).toString();
  }
}
