import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/lead.dart';

/// Saved leads, newest first, kept on the phone.
class LeadStore {
  static const _key = 'leads.v1';

  Future<List<Lead>> all() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final leads = list
          .whereType<Map>()
          .map((m) => Lead.fromJson(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return leads;
    } catch (_) {
      return [];
    }
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
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(leads.map((l) => l.toJson()).toList()));
  }
}
