import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lead.dart';
import 'lead_store.dart';
import 'server.dart';

/// Kinds of work the team report counts.
abstract class Work {
  static const audit = 'audit';
  static const whatsapp = 'whatsapp';
  static const email = 'email';
  static const status = 'status';
  static const followup = 'followup';
  static const client = 'client';
}

class WorkEvent {
  const WorkEvent({
    required this.id,
    required this.type,
    required this.placeId,
    required this.name,
    this.meta = '',
    required this.at,
  });

  final String id;
  final String type;
  final String placeId;
  final String name;
  final String meta;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'placeId': placeId,
        'name': name,
        'meta': meta,
        'at': at.toUtc().toIso8601String(),
      };

  factory WorkEvent.fromJson(Map<String, dynamic> j) => WorkEvent(
        id: '${j['id']}',
        type: '${j['type']}',
        placeId: '${j['placeId'] ?? ''}',
        name: '${j['name'] ?? ''}',
        meta: '${j['meta'] ?? ''}',
        at: DateTime.tryParse('${j['at']}')?.toLocal() ?? DateTime.now(),
      );
}

/// Today's numbers for the Home screen, from this phone's own log.
class TodayWork {
  const TodayWork({this.leads = 0, this.sent = 0, this.replies = 0});
  final int leads;
  final int sent;
  final int replies;
}

/// Sends work events and lead changes to the server. Everything is kept
/// on the phone first, so nothing is lost offline; it is sent when the
/// connection is back. Each event has an id, so a resend never counts twice.
class SyncService extends ChangeNotifier {
  SyncService(this._api, this._leads) {
    _leads.onSaved = (lead) => queueLead(lead);
    _leads.onRemoved = (id) => queueLeadDelete(id);
  }

  final ApiClient _api;
  final LeadStore _leads;
  final _rand = Random();

  static const _kEvents = 'sync.events';
  static const _kHistory = 'sync.history';
  static const _kLeads = 'sync.leads';
  static const _kOwner = 'sync.owner';

  bool _flushing = false;
  int _pending = 0;

  /// Changes waiting to reach the server.
  int get pending => _pending;

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 30).toRadixString(36)}';

  Future<List<Map<String, dynamic>>> _list(SharedPreferences p, String key) async {
    try {
      return (jsonDecode(p.getString(key) ?? '[]') as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _map(SharedPreferences p, String key) async {
    try {
      return Map<String, dynamic>.from(jsonDecode(p.getString(key) ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  /// Records a piece of work and sends it when possible.
  Future<void> record(String type, {required String placeId, required String name, String meta = ''}) async {
    final e = WorkEvent(id: _newId(), type: type, placeId: placeId, name: name, meta: meta, at: DateTime.now());
    final p = await SharedPreferences.getInstance();
    final events = await _list(p, _kEvents)..add(e.toJson());
    final cutoff = DateTime.now().subtract(const Duration(days: 31));
    final history = (await _list(p, _kHistory))
      ..add(e.toJson())
      ..removeWhere((h) => (DateTime.tryParse('${h['at']}') ?? DateTime(2000)).isBefore(cutoff));
    await p.setString(_kEvents, jsonEncode(events.length > 2000 ? events.sublist(events.length - 2000) : events));
    await p.setString(_kHistory, jsonEncode(history));
    notifyListeners();
    flush();
  }

  Future<void> queueLead(Lead lead) async {
    final p = await SharedPreferences.getInstance();
    final m = await _map(p, _kLeads);
    m[lead.business.id] = {
      'op': 'put',
      'name': lead.business.name,
      'category': lead.category,
      'city': lead.city,
      'status': lead.status.name,
      'data': lead.toJson(),
    };
    await p.setString(_kLeads, jsonEncode(m));
    flush();
  }

  Future<void> queueLeadDelete(String placeId) async {
    final p = await SharedPreferences.getInstance();
    final m = await _map(p, _kLeads);
    m[placeId] = {'op': 'delete'};
    await p.setString(_kLeads, jsonEncode(m));
    flush();
  }

  /// Sends what is waiting. Safe to call often; a call made while a send is
  /// running makes it go round once more.
  Future<void> flush() async {
    if (_api.token.isEmpty) return;
    if (_flushing) {
      _again = true;
      return _running ?? Future<void>.value();
    }
    _flushing = true;
    final done = _flushLoop();
    _running = done;
    try {
      await done;
    } finally {
      _flushing = false;
      _running = null;
      notifyListeners();
    }
  }

  bool _again = false;
  Future<void>? _running;

  Future<void> _flushLoop() async {
    do {
      _again = false;
      if (!await _flushOnce()) break;
    } while (_again);
  }

  /// One pass. Returns false when the server can't be reached.
  Future<bool> _flushOnce() async {
    final p = await SharedPreferences.getInstance();
    var ok = true;
    var events = await _list(p, _kEvents);
    while (events.isNotEmpty) {
      final batch = events.take(100).toList();
      try {
        await _api.post('/activity', {'events': batch});
      } on ApiException catch (e) {
        if (e.offline || e.signedOut || e.status >= 500) {
          ok = false;
          break;
        }
        // A rejected batch would block the queue forever: drop it.
      }
      // Re-read: more work may have been recorded while this was sending.
      final sent = batch.map((b) => '${b['id']}').toSet();
      events = (await _list(p, _kEvents))..removeWhere((e) => sent.contains('${e['id']}'));
      await p.setString(_kEvents, jsonEncode(events));
    }
    final leads = await _map(p, _kLeads);
    if (ok) {
      for (final id in leads.keys.toList()) {
        final item = Map<String, dynamic>.from(leads[id] as Map);
        try {
          if (item['op'] == 'delete') {
            await _api.delete('/leads/${Uri.encodeComponent(id)}');
          } else {
            await _api.put('/leads/${Uri.encodeComponent(id)}', {
              'name': item['name'],
              'category': item['category'],
              'city': item['city'],
              'status': item['status'],
              'data': item['data'],
            });
          }
        } on ApiException catch (e) {
          if (e.offline || e.signedOut || e.status >= 500) {
            ok = false;
            break;
          }
        }
        // Keep it if it changed again while sending.
        final latest = await _map(p, _kLeads);
        if (jsonEncode(latest[id]) == jsonEncode(item)) latest.remove(id);
        await p.setString(_kLeads, jsonEncode(latest));
      }
    }
    _pending = (await _list(p, _kEvents)).length + (await _map(p, _kLeads)).length;
    return ok;
  }

  /// Brings this member's leads from the server (after signing in on a
  /// new phone, or to pick up changes). Never overwrites newer local edits.
  Future<int> pullLeads() async {
    var added = 0;
    for (var page = 1; page <= 20; page++) {
      final j = await _api.get('/leads', query: {'page': '$page'});
      final items = (j is Map ? j['items'] as List? : null) ?? const [];
      for (final it in items.whereType<Map>()) {
        final data = it['data'];
        if (data is! Map) continue;
        final remote = Lead.fromJson(Map<String, dynamic>.from(data));
        if (remote.business.id.isEmpty) continue;
        final local = await _leads.find(remote.business.id);
        if (local == null || local.savedAt.isBefore(remote.savedAt)) {
          await _leads.save(remote, sync: false);
          added++;
        }
      }
      if (items.length < 200) break;
    }
    return added;
  }

  Future<TodayWork> today() async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final leads = <String>{};
    final sent = <String>{};
    final replies = <String>{};
    for (final h in await _list(p, _kHistory)) {
      final at = DateTime.tryParse('${h['at']}')?.toLocal();
      if (at == null || at.isBefore(start)) continue;
      final id = '${h['placeId']}';
      switch (h['type']) {
        case Work.audit:
          leads.add(id);
        case Work.whatsapp:
        case Work.email:
          sent.add(id);
        case Work.status:
          if (h['meta'] == 'replied') replies.add(id);
      }
    }
    return TodayWork(leads: leads.length, sent: sent.length, replies: replies.length);
  }

  /// Called after sign-in. A different person on this phone starts clean
  /// (their own leads come from the server).
  Future<void> startFor(int userId) async {
    final p = await SharedPreferences.getInstance();
    final owner = p.getInt(_kOwner);
    if (owner != null && owner != userId) {
      await p.remove(_kEvents);
      await p.remove(_kHistory);
      await p.remove(_kLeads);
      await _leads.clearAll();
    }
    await p.setInt(_kOwner, userId);
    notifyListeners();
    await flush();
    try {
      await pullLeads();
    } on ApiException {
      // Offline: try again on the next refresh.
    }
  }
}
