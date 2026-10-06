import 'dart:convert';

import 'package:fc_leads/data/geo.dart';
import 'package:fc_leads/logic/audit_builder.dart';
import 'package:fc_leads/main.dart';
import 'package:fc_leads/models/lead.dart';
import 'package:fc_leads/screens/home_shell.dart';
import 'package:fc_leads/services/places_api.dart';
import 'package:fc_leads/services/settings_controller.dart';
import 'package:fc_leads/services/settings_store.dart';
import 'package:fc_leads/widgets/audit_graphic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';
import 'places_api_test.dart' show sampleResponse;

/// Country and city lists without asset loading (which needs real time
/// in widget tests). geo_test.dart checks the real bundled lists.
class _FakeGeo extends GeoRepository {
  @override
  Future<List<Country>> countries() async => const [
        Country(code: 'AE', name: 'United Arab Emirates', dialCode: '971'),
        Country(code: 'BD', name: 'Bangladesh', dialCode: '880'),
      ];

  @override
  Future<List<String>> cities(String countryCode) async =>
      countryCode == 'BD' ? const ['Dhaka', 'Chittagong', 'Khulna'] : const ['Dubai'];
}

Widget _app({PlacesApi? places}) => FcLeadsApp(
      settings: SettingsController(SettingsStore()),
      services: AppServices(places: places, geo: _FakeGeo()),
    );

/// A tall screen so every section is built without scrolling.
void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first launch shows the home screen and asks for setup', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Find your next client'), findsOneWidget);
    expect(find.textContaining('Add your Google Places API key'), findsOneWidget);
    expect(find.text('Leads saved'), findsOneWidget);
  });

  testWidgets('agency details are saved in Settings', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _tab(tester, 'Settings');

    await tester.enterText(find.widgetWithText(TextField, 'API key'), 'abc123');
    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Saiful');
    await tester.enterText(find.widgetWithText(TextField, 'Agency name'), 'Nova Studio');
    await tester.tap(find.text('Mint'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.apiKey'), 'abc123');
    expect(prefs.getString('settings.senderName'), 'Saiful');
    expect(prefs.getString('settings.agencyName'), 'Nova Studio');
    expect(prefs.getInt('settings.accent'), 1);
  });

  testWidgets('pick a type, search a city, open a business and compose WhatsApp', (tester) async {
    _bigScreen(tester);
    SharedPreferences.setMockInitialValues({'settings.apiKey': 'KEY'});
    late Map<String, dynamic> sent;
    final places = PlacesApi(
      client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(sampleResponse), 200);
      }),
    );
    await tester.pumpWidget(_app(places: places));
    await tester.pumpAndSettle();
    await _tab(tester, 'Search');

    expect(find.textContaining('Bangladesh'), findsWidgets);
    expect(find.text('Dhaka'), findsOneWidget);

    await tester.tap(find.text('Business type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cafes & coffee shops'));
    await tester.pumpAndSettle();
    expect(find.text('Searching for: cafes in Dhaka, Bangladesh'), findsOneWidget);

    await tester.tap(find.text('Search Google Maps'));
    await tester.pumpAndSettle();
    expect(sent['textQuery'], 'cafes in Dhaka, Bangladesh');
    expect(sent['regionCode'], 'bd');
    expect(find.text('Rahim Tea House'), findsOneWidget);
    expect(find.text('Green Leaf Dental'), findsOneWidget);

    await tester.tap(find.text('No website only'));
    await tester.pumpAndSettle();
    expect(find.text('Green Leaf Dental'), findsNothing);

    await tester.tap(find.text('Rahim Tea House'));
    await tester.pumpAndSettle();
    expect(find.byType(AuditGraphic), findsOneWidget);
    expect(find.text('Missing'), findsWidgets);
    expect(find.text('Pitch these services'), findsOneWidget);
    expect(find.text('Website Design'), findsOneWidget);
    expect(find.text('Find them on Google:'), findsOneWidget);

    await tester.tap(find.text('Send on WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.text('Open chat with this message'), findsOneWidget);
    expect(find.text('8801711234567'), findsOneWidget);
    expect(find.textContaining('Hi Rahim Tea House team'), findsOneWidget);
  });

  testWidgets('leads can be filtered by status', (tester) async {
    _bigScreen(tester);
    final now = DateTime.now();
    final leads = [
      Lead(business: noWebsite, items: buildAudit(noWebsite, null), savedAt: now, city: 'Dhaka'),
      Lead(
        business: withWebsite,
        items: buildAudit(withWebsite, goodSite),
        savedAt: now.subtract(const Duration(days: 1)),
        status: LeadStatus.won,
        whatsappSentAt: now,
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'leads.v1': jsonEncode(leads.map((l) => l.toJson()).toList()),
    });
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _tab(tester, 'Leads');

    expect(find.text('2 of 2 leads'), findsOneWidget);
    await tester.tap(find.text('Won 1'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 leads'), findsOneWidget);
    expect(find.text('Green Leaf Dental'), findsOneWidget);
    expect(find.text('Rahim Tea House'), findsNothing);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 leads'), findsOneWidget);
  });

  testWidgets('templates show placeholders and a preview', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _tab(tester, 'Templates');

    expect(find.text('{business}'), findsOneWidget);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Preview for a sample café'), findsOneWidget);
  });
}
