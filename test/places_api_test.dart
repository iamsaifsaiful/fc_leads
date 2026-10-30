import 'dart:convert';

import 'package:fc_leads/services/places_api.dart';
import 'package:fc_leads/services/server.dart';
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
    final page = PlacesApi.parsePage(sampleResponse);
    expect(page.businesses.map((b) => b.name), ['Rahim Tea House', 'Green Leaf Dental']);
    final first = page.businesses.first;
    expect(first.category, 'Cafe');
    expect(first.reviewCount, 12);
    expect(first.hasWebsite, isFalse);
    expect(page.businesses.last.hasWebsite, isTrue);
    expect(page.nextPageToken, 'next-1');
  });

  test('searches through the agency server with the session token', () async {
    late http.Request sent;
    final client = ApiClient(client: MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode(sampleResponse), 200);
    }))
      ..token = 'T0K';
    final page = await PlacesApi(client).search('cafes in Dhanmondi', regionCode: 'bd');
    expect(sent.url.toString(), 'https://fansconnector.agency/wp-json/fcleads/v1/places/search');
    expect(sent.headers['X-FCL-Token'], 'T0K');
    expect(sent.headers.containsKey('X-Goog-Api-Key'), isFalse);
    expect(jsonDecode(sent.body)['textQuery'], 'cafes in Dhanmondi');
    expect(jsonDecode(sent.body)['regionCode'], 'bd');
    expect(page.businesses, hasLength(2));
  });

  test('shows the server message when search is not set up', () {
    final client = ApiClient(client: MockClient((_) async => http.Response(
          jsonEncode({'code': 'fcl_no_key', 'message': 'Search is not set up yet.'}),
          503,
        )));
    expect(
      () => PlacesApi(client).search('x'),
      throwsA(isA<PlacesException>().having((e) => e.message, 'message', 'Search is not set up yet.')),
    );
  });

  test('falls back to ?rest_route when pretty links are off', () async {
    final urls = <Uri>[];
    final client = ApiClient(client: MockClient((r) async {
      urls.add(r.url);
      if (r.url.path.startsWith('/wp-json')) return http.Response('', 404);
      return http.Response(jsonEncode(sampleResponse), 200);
    }));
    final page = await PlacesApi(client).search('x');
    expect(page.businesses, hasLength(2));
    expect(urls.last.queryParameters['rest_route'], '/fcleads/v1/places/search');
  });
}
