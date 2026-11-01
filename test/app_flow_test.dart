import 'dart:convert';

import 'package:fc_leads/data/geo.dart';
import 'package:fc_leads/logic/audit_builder.dart';
import 'package:fc_leads/main.dart';
import 'package:fc_leads/models/lead.dart';
import 'package:fc_leads/screens/home_shell.dart';
import 'package:fc_leads/services/notifications.dart';
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

const _token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _teamUser = {'id': 7, 'name': 'Rina Akter', 'email': 'rina@example.com', 'role': 'team', 'canManage': false};
const _adminUser = {'id': 1, 'name': 'Saiful Islam', 'email': 'saiful@example.com', 'role': 'admin', 'canManage': true};
const _config = {
  'dailyTarget': 20,
  'agencyName': 'FansConnector',
  'agencyWebsite': 'fansconnector.com',
  'agencyWhatsapp': '',
  'agencyEmail': '',
  'searchReady': true,
};

/// Stands in for the FC Leads Server plugin on fansconnector.agency.
class FakeServer {
  FakeServer({this.user = _teamUser});
  Map<String, Object> user;
  final requests = <http.Request>[];
  Map<String, dynamic>? lastSearch;
  Map<String, dynamic>? lastAdd;

  http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  MockClient get client => MockClient((r) async {
        requests.add(r);
        expect(r.url.host, 'fansconnector.agency');
        final path = r.url.path.replaceFirst('/wp-json/fcleads/v1', '');
        if (path == '/auth/login') {
          final b = jsonDecode(r.body) as Map;
          if (b['password'] != 'secret123') {
            return _json({'code': 'fcl_bad_login', 'message': 'Wrong email or password.'}, 403);
          }
          if (b['role'] == 'admin') user = _adminUser;
          return _json({'token': _token, 'user': user, 'config': _config});
        }
        if (r.headers['X-FCL-Token'] != _token) {
          return _json({'code': 'fcl_no_session', 'message': 'Please sign in.'}, 401);
        }
        switch (path) {
          case '/me':
            return _json({'user': user, 'config': _config});
          case '/places/search':
            lastSearch = jsonDecode(r.body) as Map<String, dynamic>;
            return _json(sampleResponse);
          case '/activity':
            return _json({'saved': 1});
          case '/leads':
            if (r.method == 'GET') return _json({'items': [], 'total': 0});
            break;
          case '/admin/report':
            return _json({
              'period': 'day',
              'label': 'Today',
              'totals': {'leads': 12, 'sent': 5, 'replies': 1, 'won': 0, 'searches': 3},
              'previous': {'leads': 8, 'sent': 4, 'replies': 0, 'won': 0, 'searches': 2},
              'bars': [
                {'label': '9', 'leads': 4, 'sent': 2},
                {'label': '10', 'leads': 8, 'sent': 3},
              ],
              'team': [
                {
                  'id': 7,
                  'name': 'Rina Akter',
                  'initials': 'RA',
                  'email': 'rina@example.com',
                  'role': 'team',
                  'disabled': false,
                  'leads': 12,
                  'sent': 5,
                  'replies': 1,
                },
              ],
              'dailyTarget': 20,
            });
          case '/admin/team':
            if (r.method == 'POST') {
              lastAdd = jsonDecode(r.body) as Map<String, dynamic>;
              return _json({
                'member': {
                  'id': 9,
                  'name': lastAdd!['name'],
                  'initials': 'TH',
                  'email': lastAdd!['email'],
                  'role': lastAdd!['access'] == 'admin' ? 'admin' : 'team',
                  'disabled': false,
                },
                'existing': false,
              });
            }
            return _json({'today': []});
        }
        if (path.startsWith('/leads/')) return _json({'ok': true});
        return _json({'code': 'rest_no_route', 'message': 'No route'}, 404);
      });
}

Map<String, Object> _signedIn([Map<String, Object> user = _teamUser, Map<String, Object> extra = const {}]) => {
      'session.token': _token,
      'session.user': jsonEncode(user),
      'session.config': jsonEncode(_config),
      ...extra,
    };

Widget _app([FakeServer? server]) => FcLeadsApp(
      settings: SettingsController(SettingsStore()),
      services: AppServices(
        httpClient: (server ?? FakeServer()).client,
        geo: _FakeGeo(),
        notifier: FakeNotifier(),
      ),
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
  setUp(() => SharedPreferences.setMockInitialValues(_signedIn()));

  testWidgets('without a session the app asks to sign in', (tester) async {
    _bigScreen(tester);
    SharedPreferences.setMockInitialValues({});
    final server = FakeServer();
    await tester.pumpWidget(_app(server));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('fansconnector.agency'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, 'Email or username'), 'rina@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong email or password.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text("Today's target"), findsOneWidget);
    expect(find.textContaining('Rina'), findsWidgets);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session.token'), _token);
  });

  testWidgets('admin sign in opens the team report', (tester) async {
    _bigScreen(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Email or username'), 'saiful');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in as admin'));
    await tester.pumpAndSettle();
    expect(find.text('Team report'), findsOneWidget);
    expect(find.text('Rina Akter'), findsWidgets);
    expect(find.text('12'), findsWidgets);
  });

  testWidgets('an admin can add another admin', (tester) async {
    _bigScreen(tester);
    SharedPreferences.setMockInitialValues(_signedIn(_adminUser));
    final server = FakeServer(user: _adminUser);
    await tester.pumpWidget(_app(server));
    await tester.pumpAndSettle();
    await _tab(tester, 'Team');
    await tester.tap(find.text('Add person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin').last);
    await tester.pumpAndSettle();
    expect(find.text('Add an admin'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Tania Haque');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'tania@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Add admin'));
    await tester.pumpAndSettle();
    expect(server.lastAdd!['access'], 'admin');
    expect(server.lastAdd!['email'], 'tania@example.com');
    expect(find.textContaining('Tania Haque can now sign in with Team or Admin'), findsOneWidget);
  });

  testWidgets('signed-in home screen shows the daily target', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text("Today's target"), findsOneWidget);
    expect(find.text('/ 20 leads checked'), findsOneWidget);
    expect(find.text('New search'), findsOneWidget);
    expect(find.text('Pipeline'), findsOneWidget);
  });

  testWidgets('sign out returns to the login screen', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _tab(tester, 'More');
    expect(find.text('Rina Akter'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session.token'), isNull);
  });

  testWidgets('agency details are saved in Settings', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _tab(tester, 'More');
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Saiful');
    await tester.enterText(find.widgetWithText(TextField, 'Agency name'), 'Nova Studio');
    await tester.tap(find.text('Mint'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.senderName'), 'Saiful');
    expect(prefs.getString('settings.agencyName'), 'Nova Studio');
    expect(prefs.getInt('settings.accent'), 1);
  });

  testWidgets('pick a type, search a city, open a business and compose WhatsApp', (tester) async {
    _bigScreen(tester);
    final server = FakeServer();
    await tester.pumpWidget(_app(server));
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
    expect(server.lastSearch!['textQuery'], 'cafes in Dhaka, Bangladesh');
    expect(server.lastSearch!['regionCode'], 'bd');
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
    SharedPreferences.setMockInitialValues(_signedIn(_teamUser, {
      'leads.v1': jsonEncode(leads.map((l) => l.toJson()).toList()),
      'sync.owner': 7,
    }));
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
    await _tab(tester, 'More');
    await tester.tap(find.text('Message templates'));
    await tester.pumpAndSettle();

    expect(find.text('{business}'), findsOneWidget);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Preview with sample data'), findsOneWidget);
    expect(find.text('Payment reminder'), findsOneWidget);
  });

  testWidgets('add a client with a monthly fee', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _tab(tester, 'Clients');
    expect(find.textContaining('No clients yet'), findsOneWidget);

    await tester.tap(find.text('Add client'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Business name'), 'Green Leaf Dental');
    await tester.enterText(find.widgetWithText(TextFormField, 'Monthly fee'), '15000');
    await tester.tap(find.text('SEO & Growth Support'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add client'));
    await tester.pumpAndSettle();

    expect(find.text('Green Leaf Dental'), findsOneWidget);
    expect(find.text('BDT 15,000'), findsWidgets);
    expect(find.text('SEO & Growth Support'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('clients.v1'), contains('Green Leaf Dental'));
  });

  testWidgets('pull to refresh on Leads re-reads saved leads', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _tab(tester, 'Leads');
    expect(find.text('0 of 0 leads'), findsOneWidget);

    // Something else saved a lead (e.g. another screen); refresh shows it.
    SharedPreferences.setMockInitialValues(_signedIn(_teamUser, {
      'leads.v1': jsonEncode([
        Lead(business: noWebsite, items: buildAudit(noWebsite, null), savedAt: DateTime.now()).toJson(),
      ]),
      'sync.owner': 7,
    }));
    await tester.tap(find.byTooltip('Refresh').last);
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 leads'), findsOneWidget);
  });
}
