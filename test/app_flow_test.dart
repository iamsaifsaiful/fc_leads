import 'dart:convert';

import 'package:fc_leads/main.dart';
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

import 'places_api_test.dart' show sampleResponse;

Widget _app({PlacesApi? places}) => FcLeadsApp(
      settings: SettingsController(SettingsStore()),
      services: AppServices(places: places),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first launch asks for an API key', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Find clients'), findsOneWidget);
    expect(find.textContaining('Add your Google Places API key'), findsOneWidget);
  });

  testWidgets('settings are saved on the phone', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'API key'), 'abc123');
    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Saiful');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.apiKey'), 'abc123');
    expect(prefs.getString('settings.senderName'), 'Saiful');
    expect(prefs.getString('settings.agencyName'), 'FansConnector');
  });

  testWidgets('search, open a business and see its audit graphic', (tester) async {
    SharedPreferences.setMockInitialValues({'settings.apiKey': 'KEY'});
    final places = PlacesApi(
      client: MockClient((_) async => http.Response(jsonEncode(sampleResponse), 200)),
    );
    await tester.pumpWidget(_app(places: places));
    await tester.pumpAndSettle();
    expect(find.textContaining('Add your Google Places API key'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'cafes in Dhanmondi');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Rahim Tea House'), findsOneWidget);
    expect(find.text('Green Leaf Dental'), findsOneWidget);
    expect(find.text('No website'), findsOneWidget);

    await tester.tap(find.text('No website only'));
    await tester.pumpAndSettle();
    expect(find.text('Green Leaf Dental'), findsNothing);

    await tester.tap(find.text('Rahim Tea House'));
    await tester.pumpAndSettle();

    expect(find.byType(AuditGraphic), findsOneWidget);
    expect(find.text('Missing'), findsWidgets);
    expect(find.text('Few reviews'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Send on WhatsApp'), findsOneWidget);
    final phone = tester.widget<TextField>(find.widgetWithText(TextField, 'WhatsApp number (with country code)'));
    expect(phone.controller!.text, '8801711234567');

    // The lead was saved.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leads'));
    await tester.pumpAndSettle();
    expect(find.text('Rahim Tea House'), findsWidgets);
    expect(find.text('Not contacted yet'), findsOneWidget);
  });

  testWidgets('changing a row updates the graphic', (tester) async {
    SharedPreferences.setMockInitialValues({'settings.apiKey': 'KEY'});
    final places = PlacesApi(
      client: MockClient((_) async => http.Response(jsonEncode(sampleResponse), 200)),
    );
    await tester.pumpWidget(_app(places: places));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'cafes');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rahim Tea House'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social media').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Inactive'));
    await tester.pumpAndSettle();

    // Shown in the audit list and on the graphic.
    expect(find.text('Inactive'), findsNWidgets(2));
  });
}
