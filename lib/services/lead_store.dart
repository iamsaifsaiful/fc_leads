import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lead.dart';

/// Saved leads, newest first, kept on the phone and copied to the server.
/// Screens listen to it and refresh when a lead is saved or removed.
class LeadStore extends ChangeNotifier {
  static const _key = 'leads.v1';
  List<Lead>? _cache;

  /// Set by the sync service: called after a local change.
  void Function(Lead lead)? onSaved;
  void Function(String placeId)? onRemoved;

  Future<List<Lead>> all() async {
    if (_cache != null) return List.of(_cache!);
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    var leads = <Lead>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        leads = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((m) => Lead.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {
        leads = [];
      }
    }
    leads.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    _cache = leads;
    return List.of(leads);
  }

  Future<Lead?> find(String businessId) async {
    for (final lead in await all()) {
      if (lead.business.id == businessId) return lead;
    }
    return null;
  }

  /// [sync] false is for leads that came from the server.
  Future<void> save(Lead lead, {bool sync = true}) async {
    final leads = (await all()).where((l) => l.business.id != lead.business.id).toList()
      ..add(lead)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    await _write(leads);
    if (sync) onSaved?.call(lead);
  }

  Future<void> remove(String businessId) async {
    final leads = (await all()).where((l) => l.business.id != businessId).toList();
    await _write(leads);
    onRemoved?.call(businessId);
  }

  /// Another person signed in on this phone.
  Future<void> clearAll() => _write([]);

  /// Reads again from storage (pull to refresh).
  Future<void> reload() async {
    _cache = null;
    await all();
    notifyListeners();
  }

  Future<void> _write(List<Lead> leads) async {
    _cache = leads;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(leads.map((l) => l.toJson()).toList()));
  }
}
