import 'dart:convert';

import 'package:http/http.dart' as http;

/// The only server this app talks to. Set at build time with
/// `--dart-define=FCL_SERVER=…` for testing; the release build is fixed
/// to the agency's site.
const serverBase = String.fromEnvironment('FCL_SERVER', defaultValue: 'https://fansconnector.agency');

/// Shown on the login screen.
String get serverHost => Uri.parse(serverBase).host;

class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.code = ''});
  final String message;
  final int status;
  final String code;

  bool get signedOut => status == 401;
  bool get offline => status == 0;

  @override
  String toString() => message;
}

/// Talks to the FC Leads Server plugin (`/wp-json/fcleads/v1`).
///
/// Sites without pretty permalinks answer only on `/?rest_route=…`, so
/// a "no route" reply switches to that form once and remembers it.
class ApiClient {
  ApiClient({http.Client? client, this.base = serverBase}) : _http = client ?? http.Client();

  final http.Client _http;
  final String base;
  String token = '';
  bool _queryRoutes = false;

  /// Called when the server says the session is over.
  void Function()? onSignedOut;

  Uri _uri(String path, Map<String, String>? query) {
    final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (_queryRoutes) {
      return Uri.parse('$root/').replace(queryParameters: {'rest_route': '/fcleads/v1$path', ...?query});
    }
    final u = Uri.parse('$root/wp-json/fcleads/v1$path');
    return query == null || query.isEmpty ? u : u.replace(queryParameters: query);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, Object? body) => _send('PUT', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query, bool retried = false}) async {
    final req = http.Request(method, _uri(path, query));
    req.headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['X-FCL-Token'] = token;
    }
    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 25)));
    } catch (_) {
      throw ApiException('No connection to $serverHost. Check the internet and try again.');
    }

    dynamic json;
    try {
      json = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      json = null;
    }

    if (res.statusCode == 404 && !retried && !_queryRoutes) {
      final code = json is Map ? '${json['code'] ?? ''}' : '';
      if (json == null || code == 'rest_no_route') {
        _queryRoutes = true;
        return _send(method, path, body: body, query: query, retried: true);
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;

    final message = json is Map && json['message'] is String
        ? json['message'] as String
        : res.statusCode == 404
            ? 'The FC Leads plugin is not active on $serverHost.'
            : 'The server could not do that (error ${res.statusCode}).';
    final error = ApiException(message, status: res.statusCode, code: json is Map ? '${json['code'] ?? ''}' : '');
    if (error.signedOut && token.isNotEmpty) onSignedOut?.call();
    throw error;
  }
}
