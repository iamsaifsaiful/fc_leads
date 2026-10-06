import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/search_spec.dart';

/// The last searches, newest first, plus the last picked values.
class SearchHistory {
  static const _key = 'search.recent';
  static const _lastKey = 'search.last';
  static const max = 8;

  Future<List<SearchSpec>> recent() async {
    final p = await SharedPreferences.getInstance();
    try {
      return (jsonDecode(p.getString(_key) ?? '[]') as List)
          .whereType<Map>()
          .map((m) => SearchSpec.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(SearchSpec spec) async {
    final list = (await recent()).where((s) => s != spec).toList()..insert(0, spec);
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(list.take(max).map((s) => s.toJson()).toList()));
    await p.setString(_lastKey, jsonEncode(spec.copyWith(freeText: '').toJson()));
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  /// The values picked last time, so the form opens where the user left it.
  Future<SearchSpec?> last() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_lastKey);
    if (raw == null) return null;
    try {
      return SearchSpec.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }
}
