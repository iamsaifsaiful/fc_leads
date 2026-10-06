/// A business as returned by the Google Places API (Text Search, New).
class Business {
  const Business({
    required this.id,
    required this.name,
    this.address = '',
    this.category = '',
    this.phone = '',
    this.internationalPhone = '',
    this.website = '',
    this.rating,
    this.reviewCount = 0,
    this.mapsUrl = '',
    this.status = '',
  });

  final String id;
  final String name;
  final String address;
  final String category;

  /// Phone as shown locally, e.g. "01711-234567".
  final String phone;

  /// Phone with country code, e.g. "+880 1711-234567".
  final String internationalPhone;
  final String website;
  final double? rating;
  final int reviewCount;
  final String mapsUrl;

  /// OPERATIONAL, CLOSED_TEMPORARILY or CLOSED_PERMANENTLY.
  final String status;

  bool get hasWebsite => website.trim().isNotEmpty;

  /// Parses one entry of the `places` list from the Places API.
  factory Business.fromPlacesJson(Map<String, dynamic> json) {
    String text(Object? field) {
      if (field is Map && field['text'] is String) return field['text'] as String;
      return '';
    }

    final rating = json['rating'];
    final count = json['userRatingCount'];
    return Business(
      id: (json['id'] as String?) ?? '',
      name: text(json['displayName']),
      address: (json['formattedAddress'] as String?) ?? '',
      category: text(json['primaryTypeDisplayName']),
      phone: (json['nationalPhoneNumber'] as String?) ?? '',
      internationalPhone: (json['internationalPhoneNumber'] as String?) ?? '',
      website: (json['websiteUri'] as String?) ?? '',
      rating: rating is num ? rating.toDouble() : null,
      reviewCount: count is num ? count.toInt() : 0,
      mapsUrl: (json['googleMapsUri'] as String?) ?? '',
      status: (json['businessStatus'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'category': category,
        'phone': phone,
        'internationalPhone': internationalPhone,
        'website': website,
        'rating': rating,
        'reviewCount': reviewCount,
        'mapsUrl': mapsUrl,
        'status': status,
      };

  factory Business.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'];
    final count = json['reviewCount'];
    return Business(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      internationalPhone: (json['internationalPhone'] as String?) ?? '',
      website: (json['website'] as String?) ?? '',
      rating: rating is num ? rating.toDouble() : null,
      reviewCount: count is num ? count.toInt() : 0,
      mapsUrl: (json['mapsUrl'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
    );
  }
}
