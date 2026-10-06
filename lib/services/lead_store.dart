import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lead.dart';

/// Saved leads, newest first, kept on the phone. Screens listen to it and
/// refresh when a lead is saved or removed.
class LeadStore extends ChangeNotifier {
  static const _key = 'leads.v1';
  List<Lead>? _cache;

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

  Future<void> save(Lead lead) async {
    final leads = (await all()).where((l) => l.business.id != lead.business.id).toList()
      ..insert(0, lead);
    await _write(leads);
  }

  Future<void> remove(String businessId) async {
    final leads = (await all()).where((l) => l.business.id != businessId).toList();
    await _write(leads);
  }

  Future<void> _write(List<Lead> leads) async {
    _cache = leads;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(leads.map((l) => l.toJson()).toList()));
  }
}
