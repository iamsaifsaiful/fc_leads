import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/business.dart';

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

/// Google Places API (New) Text Search.
///
/// Needs the "Places API (New)" enabled on the key's Google Cloud project.
class PlacesApi {
  PlacesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final _endpoint = Uri.parse('https://places.googleapis.com/v1/places:searchText');

  static const fieldMask = 'places.id,places.displayName,places.formattedAddress,'
      'places.nationalPhoneNumber,places.internationalPhoneNumber,'
      'places.websiteUri,places.rating,places.userRatingCount,'
      'places.googleMapsUri,places.businessStatus,'
      'places.primaryTypeDisplayName,nextPageToken';

  Future<PlacesPage> search(
    String query, {
    required String apiKey,
    String? pageToken,
    String? regionCode,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw PlacesException('Add your Google Places API key in Settings first.');
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey.trim(),
              'X-Goog-FieldMask': fieldMask,
            },
            body: jsonEncode({
              'textQuery': query,
              'pageSize': 20,
              if (pageToken != null) 'pageToken': pageToken,
              if (regionCode != null && regionCode.isNotEmpty) 'regionCode': regionCode.toLowerCase(),
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw PlacesException('Could not reach Google. Check the internet connection.');
    }
    return parseResponse(response.statusCode, response.body);
  }

  /// Fresh details for one place (rating, reviews, phone, website…).
  Future<Business> details(String placeId, {required String apiKey}) async {
    if (apiKey.trim().isEmpty) {
      throw PlacesException('Add your Google Places API key in Settings first.');
    }
    final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('https://places.googleapis.com/v1/places/${Uri.encodeComponent(placeId)}'),
        headers: {
          'X-Goog-Api-Key': apiKey.trim(),
          'X-Goog-FieldMask': fieldMask
              .split(',')
              .where((f) => f.startsWith('places.'))
              .map((f) => f.substring('places.'.length))
              .join(','),
        },
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw PlacesException('Could not reach Google. Check the internet connection.');
    }
    return parseDetails(response.statusCode, response.body);
  }

  static Business parseDetails(int statusCode, String body) {
    if (statusCode != 200) {
      // Reuse the error messages of the search parser.
      parseResponse(statusCode, body);
      throw PlacesException('Google sent an unexpected reply (HTTP $statusCode).');
    }
    try {
      return Business.fromPlacesJson(Map<String, dynamic>.from(jsonDecode(body) as Map));
    } catch (_) {
      throw PlacesException('Google sent an unexpected reply.');
    }
  }

  /// Split out so tests can feed it saved responses.
  static PlacesPage parseResponse(int statusCode, String body) {
    Map<String, dynamic> json;
    try {
      json = body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw PlacesException('Google sent an unexpected reply (HTTP $statusCode).');
    }
    if (statusCode != 200) {
      final error = json['error'];
      final message = error is Map ? (error['message'] as String? ?? '') : '';
      final status = error is Map ? (error['status'] as String? ?? '') : '';
      if (status == 'PERMISSION_DENIED' || statusCode == 403) {
        throw PlacesException(
          'The API key was refused. Check that "Places API (New)" is enabled '
          'and billing is on. ($message)',
        );
      }
      throw PlacesException(message.isEmpty ? 'Search failed (HTTP $statusCode).' : message);
    }
    final places = (json['places'] as List? ?? const [])
        .whereType<Map>()
        .map((p) => Business.fromPlacesJson(Map<String, dynamic>.from(p)))
        .where((b) => b.name.isNotEmpty && b.status != 'CLOSED_PERMANENTLY')
        .toList();
    return PlacesPage(places, json['nextPageToken'] as String?);
  }
}
