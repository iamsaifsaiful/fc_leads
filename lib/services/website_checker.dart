import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logic/html_analyzer.dart';
import '../models/website_report.dart';

/// Opens a business's home page and checks the basics.
class WebsiteChecker {
  WebsiteChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36';

  static Uri? normalise(String url) {
    var u = url.trim();
    if (u.isEmpty) return null;
    if (!u.startsWith(RegExp(r'https?://', caseSensitive: false))) u = 'https://$u';
    final uri = Uri.tryParse(u);
    return (uri == null || uri.host.isEmpty) ? null : uri;
  }

  Future<WebsiteReport> check(String url) async {
    final uri = normalise(url);
    if (uri == null) return WebsiteReport.unreachable(url, 'bad address');

    final watch = Stopwatch()..start();
    try {
      final response = await _client.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'text/html,application/xhtml+xml',
      }).timeout(const Duration(seconds: 15));
      watch.stop();

      if (response.statusCode >= 400) {
        return WebsiteReport.unreachable(url, 'HTTP ${response.statusCode}');
      }
      final finalUrl = (response.request?.url ?? uri).toString();
      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      return analyzeHtml(
        html,
        url: url,
        finalUrl: finalUrl,
        loadMs: watch.elapsedMilliseconds,
      );
    } catch (e) {
      final reason = e.toString().contains('Timeout') ? 'timed out' : 'could not connect';
      return WebsiteReport.unreachable(url, reason);
    }
  }
}
