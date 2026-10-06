/// What the user asked Google Maps for: picked from lists, or typed.
class SearchSpec {
  const SearchSpec({
    this.category = '',
    this.categoryQuery = '',
    this.countryCode = '',
    this.countryName = '',
    this.city = '',
    this.area = '',
    this.freeText = '',
  });

  /// Display label, e.g. "Dental clinics".
  final String category;

  /// Words sent to Google, e.g. "dental clinics".
  final String categoryQuery;
  final String countryCode;
  final String countryName;
  final String city;

  /// Optional neighbourhood, e.g. "Dhanmondi".
  final String area;

  /// When set, sent to Google as it is instead of the picked values.
  final String freeText;

  bool get isFree => freeText.trim().isNotEmpty;

  bool get isComplete => isFree || (categoryQuery.trim().isNotEmpty && (city.isNotEmpty || countryName.isNotEmpty));

  /// The text sent to Google Maps, e.g. "dental clinics in Dhanmondi, Dhaka, Bangladesh".
  String get query {
    if (isFree) return freeText.trim();
    final place = [area.trim(), city.trim(), countryName.trim()].where((p) => p.isNotEmpty).join(', ');
    return place.isEmpty ? categoryQuery.trim() : '${categoryQuery.trim()} in $place';
  }

  /// Short text for the recent-searches list.
  String get title {
    if (isFree) return freeText.trim();
    final place = [area.trim(), city.trim()].where((p) => p.isNotEmpty).join(', ');
    return place.isEmpty ? '$category · $countryName' : '$category · $place';
  }

  SearchSpec copyWith({
    String? category,
    String? categoryQuery,
    String? countryCode,
    String? countryName,
    String? city,
    String? area,
    String? freeText,
  }) =>
      SearchSpec(
        category: category ?? this.category,
        categoryQuery: categoryQuery ?? this.categoryQuery,
        countryCode: countryCode ?? this.countryCode,
        countryName: countryName ?? this.countryName,
        city: city ?? this.city,
        area: area ?? this.area,
        freeText: freeText ?? this.freeText,
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'categoryQuery': categoryQuery,
        'countryCode': countryCode,
        'countryName': countryName,
        'city': city,
        'area': area,
        'freeText': freeText,
      };

  factory SearchSpec.fromJson(Map<String, dynamic> j) => SearchSpec(
        category: (j['category'] as String?) ?? '',
        categoryQuery: (j['categoryQuery'] as String?) ?? '',
        countryCode: (j['countryCode'] as String?) ?? '',
        countryName: (j['countryName'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        area: (j['area'] as String?) ?? '',
        freeText: (j['freeText'] as String?) ?? '',
      );

  @override
  bool operator ==(Object other) => other is SearchSpec && other.query == query;

  @override
  int get hashCode => query.hashCode;
}
