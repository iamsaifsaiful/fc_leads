import '../models/business.dart';
import 'server.dart';

class PlacesException implements Exception {
  PlacesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PlacesPage {
  const PlacesPage(this.businesses, this.nextPageToken);
  final List<Business> businesses;

  /// Pass to [PlacesApi.search] to get the next 20 results; null at the end.
  final String? nextPageToken;
}

/// Google Places search through the agency's server. The Google key stays
/// on the server; every search is counted for the team report.
class PlacesApi {
  PlacesApi(this._api);

  final ApiClient _api;

  Future<PlacesPage> search(String query, {String? pageToken, String? regionCode}) async {
    try {
      final j = await _api.post('/places/search', {
        'textQuery': query,
        if (pageToken != null) 'pageToken': pageToken,
        if (regionCode != null && regionCode.isNotEmpty) 'regionCode': regionCode,
      });
      return parsePage(j is Map ? Map<String, dynamic>.from(j) : const {});
    } on ApiException catch (e) {
      throw PlacesException(e.message);
    }
  }

  /// Fresh details for one business.
  Future<Business> details(String placeId) async {
    try {
      final j = await _api.get('/places/${Uri.encodeComponent(placeId)}');
      return Business.fromPlacesJson(Map<String, dynamic>.from(j as Map));
    } on ApiException catch (e) {
      throw PlacesException(e.message);
    } catch (_) {
      throw PlacesException('The server sent an unexpected reply.');
    }
  }

  /// Google's searchText reply → businesses (permanently closed ones dropped).
  static PlacesPage parsePage(Map<String, dynamic> json) {
    final places = (json['places'] as List? ?? const [])
        .whereType<Map>()
        .map((p) => Business.fromPlacesJson(Map<String, dynamic>.from(p)))
        .where((b) => b.name.isNotEmpty && b.status != 'CLOSED_PERMANENTLY')
        .toList();
    return PlacesPage(places, json['nextPageToken'] as String?);
  }
}
