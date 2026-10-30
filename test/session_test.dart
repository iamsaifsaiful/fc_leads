import 'dart:convert';

import 'package:fc_leads/services/lead_store.dart';
import 'package:fc_leads/services/server.dart';
import 'package:fc_leads/services/session.dart';
import 'package:fc_leads/services/sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('login saves the session and a 401 signs out', () async {
    var meStatus = 200;
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/auth/login')) {
        expect(jsonDecode(r.body)['role'], 'admin');
        return http.Response(
            jsonEncode({
              'token': 'tok',
              'user': {'id': 1, 'name': 'Saiful Islam', 'email': 's@x.com', 'role': 'admin', 'canManage': true},
              'config': {'dailyTarget': 30, 'searchReady': false},
            }),
            200);
      }
      return http.Response(jsonEncode({'code': 'fcl_no_session', 'message': 'Please sign in.'}), meStatus);
    }));
    final s = SessionController(api);
    await s.login(' saiful ', 'pw', LoginRole.admin);
    expect(s.signedIn, isTrue);
    expect(s.showAdmin, isTrue);
    expect(s.user!.initials, 'SI');
    expect(s.config.dailyTarget, 30);
    expect(s.config.searchReady, isFalse);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('session.token'), 'tok');

    s.setAdminView(false);
    expect(s.showAdmin, isFalse);

    meStatus = 401;
    try {
      await api.get('/leads');
    } on ApiException catch (e) {
      expect(e.signedOut, isTrue);
    }
    await Future<void>.delayed(Duration.zero);
    expect(s.signedIn, isFalse);
    expect(s.expired, isTrue);
  });

  test('work is queued offline and sent once with ids', () async {
    var online = false;
    final batches = <List>[];
    final api = ApiClient(client: MockClient((r) async {
      if (!online) throw Exception('offline');
      if (r.url.path.endsWith('/activity')) batches.add(jsonDecode(r.body)['events'] as List);
      return http.Response(jsonEncode({'ok': true}), 200);
    }))
      ..token = 'tok';
    final sync = SyncService(api, LeadStore());
    await sync.record(Work.audit, placeId: 'p1', name: 'Rahim Tea House');
    await sync.record(Work.whatsapp, placeId: 'p1', name: 'Rahim Tea House', meta: 'chat');
    await sync.flush();
    expect(sync.pending, greaterThan(0));
    final today = await sync.today();
    expect(today.leads, 1);
    expect(today.sent, 1);

    online = true;
    await sync.flush();
    expect(sync.pending, 0);
    final events = batches.expand((b) => b).toList();
    expect(events, hasLength(2));
    expect(events.map((e) => e['id']).toSet(), hasLength(2));
    expect(events.first['type'], 'audit');
  });
}
