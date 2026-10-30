import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'server.dart';

enum LoginRole { team, admin }

class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.canManage = false,
  });

  final int id;
  final String name;
  final String email;
  final LoginRole role;

  /// Can also open admin reports (signed in as team or admin).
  final bool canManage;

  bool get isAdmin => role == LoginRole.admin;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String w) => String.fromCharCode(w.runes.first);
    final a = first(parts.first);
    final b = parts.length > 1 ? first(parts.last) : '';
    return (a + b).toUpperCase();
  }

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: '${j['name'] ?? ''}',
        email: '${j['email'] ?? ''}',
        role: j['role'] == 'admin' ? LoginRole.admin : LoginRole.team,
        canManage: j['canManage'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': isAdmin ? 'admin' : 'team',
        'canManage': canManage,
      };
}

/// Settings the admin keeps on the website.
class ServerConfig {
  const ServerConfig({
    this.dailyTarget = 20,
    this.agencyName = '',
    this.agencyWebsite = '',
    this.agencyWhatsapp = '',
    this.agencyEmail = '',
    this.searchReady = true,
  });

  final int dailyTarget;
  final String agencyName;
  final String agencyWebsite;
  final String agencyWhatsapp;
  final String agencyEmail;
  final bool searchReady;

  factory ServerConfig.fromJson(Map<String, dynamic> j) => ServerConfig(
        dailyTarget: (j['dailyTarget'] as num?)?.toInt() ?? 20,
        agencyName: '${j['agencyName'] ?? ''}',
        agencyWebsite: '${j['agencyWebsite'] ?? ''}',
        agencyWhatsapp: '${j['agencyWhatsapp'] ?? ''}',
        agencyEmail: '${j['agencyEmail'] ?? ''}',
        searchReady: j['searchReady'] != false,
      );

  Map<String, dynamic> toJson() => {
        'dailyTarget': dailyTarget,
        'agencyName': agencyName,
        'agencyWebsite': agencyWebsite,
        'agencyWhatsapp': agencyWhatsapp,
        'agencyEmail': agencyEmail,
        'searchReady': searchReady,
      };
}

/// Who is signed in. Nothing in the app works without a session.
class SessionController extends ChangeNotifier {
  SessionController(this.api) {
    api.onSignedOut = () => _clear(expired: true);
  }

  final ApiClient api;
  static const _kToken = 'session.token';
  static const _kUser = 'session.user';
  static const _kConfig = 'session.config';

  bool _loaded = false;
  SessionUser? _user;
  ServerConfig _config = const ServerConfig();
  bool _adminView = true;
  bool _expired = false;

  bool get loaded => _loaded;
  SessionUser? get user => _user;
  ServerConfig get config => _config;
  bool get signedIn => _user != null && api.token.isNotEmpty;

  /// The session ended on the server (shown once on the login screen).
  bool get expired => _expired;

  /// Admins can switch to the team screens and back.
  bool get showAdmin => (_user?.isAdmin ?? false) && _adminView;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    api.token = p.getString(_kToken) ?? '';
    try {
      final u = p.getString(_kUser);
      _user = u == null ? null : SessionUser.fromJson(Map<String, dynamic>.from(jsonDecode(u) as Map));
      final c = p.getString(_kConfig);
      if (c != null) _config = ServerConfig.fromJson(Map<String, dynamic>.from(jsonDecode(c) as Map));
    } catch (_) {
      _user = null;
    }
    if (api.token.isEmpty) _user = null;
    _loaded = true;
    notifyListeners();
    if (signedIn) refresh();
  }

  Future<void> login(String login, String password, LoginRole role) async {
    final j = await api.post('/auth/login', {
      'login': login.trim(),
      'password': password,
      'role': role == LoginRole.admin ? 'admin' : 'team',
      'device': 'android',
    }) as Map<String, dynamic>;
    api.token = '${j['token']}';
    _user = SessionUser.fromJson(Map<String, dynamic>.from(j['user'] as Map));
    _config = ServerConfig.fromJson(Map<String, dynamic>.from((j['config'] as Map?) ?? const {}));
    _adminView = true;
    _expired = false;
    await _save();
    notifyListeners();
  }

  /// Fresh name, role and settings from the server.
  Future<void> refresh() async {
    try {
      final j = await api.get('/me') as Map<String, dynamic>;
      _user = SessionUser.fromJson(Map<String, dynamic>.from(j['user'] as Map));
      _config = ServerConfig.fromJson(Map<String, dynamic>.from((j['config'] as Map?) ?? const {}));
      await _save();
      notifyListeners();
    } on ApiException {
      // Offline: keep what we have. Signed out: handled by onSignedOut.
    }
  }

  void setAdminView(bool admin) {
    _adminView = admin;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await _clear();
  }

  Future<void> _clear({bool expired = false}) async {
    api.token = '';
    _user = null;
    _expired = expired;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUser);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, api.token);
    if (_user != null) await p.setString(_kUser, jsonEncode(_user!.toJson()));
    await p.setString(_kConfig, jsonEncode(_config.toJson()));
  }
}
