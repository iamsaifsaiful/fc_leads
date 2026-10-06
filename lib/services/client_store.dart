import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/client.dart';

/// Paying clients, kept on the phone. Screens listen and refresh on changes.
class ClientStore extends ChangeNotifier {
  static const _key = 'clients.v1';
  List<Client>? _cache;

  Future<List<Client>> all() async {
    if (_cache != null) return List.of(_cache!);
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    var clients = <Client>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        clients = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((m) => Client.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {
        clients = [];
      }
    }
    clients.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _cache = clients;
    return List.of(clients);
  }

  Future<Client?> find(String id) async {
    for (final c in await all()) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> save(Client client) async {
    final list = (await all()).where((c) => c.id != client.id).toList()
      ..add(client)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _write(list);
  }

  Future<void> remove(String id) async {
    await _write((await all()).where((c) => c.id != id).toList());
  }

  /// Reads again from storage (pull to refresh).
  Future<void> reload() async {
    _cache = null;
    await all();
    notifyListeners();
  }

  Future<void> _write(List<Client> clients) async {
    _cache = clients;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(clients.map((c) => c.toJson()).toList()));
  }
}
