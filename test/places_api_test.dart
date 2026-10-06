import 'dart:convert';

import 'package:fc_leads/services/places_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const sampleResponse = {
  'places': [
    {
      'id': 'p1',
      'displayName': {'text': 'Rahim Tea House', 'languageCode': 'en'},
      'formattedAddress': 'Road 27, Dhanmondi, Dhaka',
      'nationalPhoneNumber': '01711-234567',
      'internationalPhoneNumber': '+880 1711-234567',
      'rating': 4.4,
      'userRatingCount': 12,
      'googleMapsUri': 'https://maps.google.com/?cid=1',
      'businessStatus': 'OPERATIONAL',
      'primaryTypeDisplayName': {'text': 'Cafe'},
    },
    {
      'id': 'p2',
      'displayName': {'text': 'Closed Shop'},
      'businessStatus': 'CLOSED_PERMANENTLY',
    },
    {
      'id': 'p3',
      'displayName': {'text': 'Green Leaf Dental'},
      'websiteUri': 'https://greenleafdental.example',
      'rating': 4.7,
      'userRatingCount': 220,
    },
  ],
  'nextPageToken': 'next-1',
};

void main() {
  test('parses businesses and drops permanently closed ones', () {
    final page = PlacesApi.parseResponse(200, jsonEncode(sampleResponse));
    expect(page.businesses.map((b) => b.name), ['Rahim Tea House', 'Green Leaf Dental']);
    final first = page.businesses.first;
    expect(first.category, 'Cafe');
    expect(first.reviewCount, 12);
    expect(first.hasWebsite, isFalse);
    expect(page.businesses.last.hasWebsite, isTrue);
    expect(page.nextPageToken, 'next-1');
  });

  test('explains a refused key', () {
    final body = jsonEncode({
      'error': {'code': 403, 'message': 'API not enabled', 'status': 'PERMISSION_DENIED'},
    });
    expect(
      () => PlacesApi.parseResponse(403, body),
      throwsA(isA<PlacesException>().having((e) => e.message, 'message', contains('Places API (New)'))),
    );
  });

  test('sends the key, field mask and query', () async {
    late http.Request sent;
    final api = PlacesApi(client: MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode(sampleResponse), 200);
    }));
    final page = await api.search('cafes in Dhanmondi', apiKey: 'KEY');
    expect(sent.headers['X-Goog-Api-Key'], 'KEY');
    expect(sent.headers['X-Goog-FieldMask'], contains('places.websiteUri'));
    expect(jsonDecode(sent.body)['textQuery'], 'cafes in Dhanmondi');
    expect(page.businesses, hasLength(2));
  });

  test('asks for a key before calling Google', () {
    expect(() => PlacesApi().search('x', apiKey: ''), throwsA(isA<PlacesException>()));
  });
}
