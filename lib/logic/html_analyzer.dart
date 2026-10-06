import '../models/website_report.dart';

/// Social platforms recognised in links, in display order.
const socialPlatforms = <String, List<String>>{
  'Facebook': ['facebook.com', 'fb.com', 'fb.me'],
  'Instagram': ['instagram.com'],
  'TikTok': ['tiktok.com'],
  'YouTube': ['youtube.com', 'youtu.be'],
  'LinkedIn': ['linkedin.com'],
  'X': ['twitter.com', 'x.com'],
  'WhatsApp': ['wa.me', 'whatsapp.com'],
};

/// Link paths that are share buttons or widgets, not a business's profile.
const _shareMarkers = [
  'sharer',
  '/share',
  'intent/',
  '/plugins/',
  'share.php',
  'dialog/',
];

/// Returns the platform name if [url] points at a social profile.
String? socialPlatformOf(String url) {
  final uri = Uri.tryParse(url.trim().startsWith('http') ? url.trim() : 'https://${url.trim()}');
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www\.|m\.|web\.)'), '');
  for (final entry in socialPlatforms.entries) {
    for (final domain in entry.value) {
      if (host == domain || host.endsWith('.$domain')) return entry.key;
    }
  }
  return null;
}

final _titleRe = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false);
final _metaRe = RegExp(r'<meta\b[^>]*>', caseSensitive: false);
final _attrRe = RegExp(
  r'''([a-zA-Z_:][\w:.-]*)\s*=\s*("([^"]*)"|'([^']*)'|([^\s"'>]+))''',
);
final _h1Re = RegExp(r'<h1[\s>]', caseSensitive: false);
final _hrefRe = RegExp(r'''href\s*=\s*["']([^"']+)["']''', caseSensitive: false);
final _emailRe = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');

Map<String, String> _attributes(String tag) {
  final attrs = <String, String>{};
  for (final m in _attrRe.allMatches(tag)) {
    final value = m.group(3) ?? m.group(4) ?? m.group(5) ?? '';
    attrs[m.group(1)!.toLowerCase()] = value;
  }
  return attrs;
}

String _clean(String text) => text
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&#039;', "'")
    .replaceAll('&quot;', '"')
    .trim();

bool _isRealEmail(String email) {
  final e = email.toLowerCase();
  const fileEndings = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.css', '.js'];
  if (fileEndings.any(e.endsWith)) return false;
  const junk = ['example.com', 'domain.com', 'sentry', 'wixpress.com', 'yourdomain', 'email.com'];
  return !junk.any(e.contains);
}

/// Reads a downloaded home page and records what it found.
WebsiteReport analyzeHtml(
  String html, {
  required String url,
  required String finalUrl,
  required int loadMs,
}) {
  final title = _clean(_titleRe.firstMatch(html)?.group(1) ?? '');

  var description = '';
  var mobileFriendly = false;
  for (final m in _metaRe.allMatches(html)) {
    final attrs = _attributes(m.group(0)!);
    final name = (attrs['name'] ?? attrs['property'] ?? '').toLowerCase();
    final content = attrs['content'] ?? '';
    if (name == 'description' && description.isEmpty) description = _clean(content);
    if (name == 'viewport' && content.toLowerCase().contains('width=device-width')) {
      mobileFriendly = true;
    }
  }

  final social = <String, String>{};
  final emails = <String>{};
  for (final m in _hrefRe.allMatches(html)) {
    final href = m.group(1)!.trim();
    if (href.toLowerCase().startsWith('mailto:')) {
      final address = href.substring(7).split('?').first.trim().toLowerCase();
      if (_emailRe.hasMatch(address) && _isRealEmail(address)) emails.add(address);
      continue;
    }
    final platform = socialPlatformOf(href);
    if (platform == null || social.containsKey(platform)) continue;
    final lower = href.toLowerCase();
    if (_shareMarkers.any(lower.contains)) continue;
    social[platform] = href;
  }
  for (final m in _emailRe.allMatches(html)) {
    final address = m.group(0)!.toLowerCase();
    if (_isRealEmail(address)) emails.add(address);
  }

  final ordered = <String, String>{
    for (final name in socialPlatforms.keys)
      if (social.containsKey(name)) name: social[name]!,
  };

  return WebsiteReport(
    url: url,
    reachable: true,
    finalUrl: finalUrl,
    https: finalUrl.toLowerCase().startsWith('https://'),
    title: title,
    metaDescription: description,
    hasH1: _h1Re.hasMatch(html),
    mobileFriendly: mobileFriendly,
    structuredData: html.toLowerCase().contains('application/ld+json'),
    hasFaq: html.contains('FAQPage') ||
        RegExp(r'frequently asked|\bFAQs?\b', caseSensitive: false).hasMatch(html),
    loadMs: loadMs,
    socialLinks: ordered,
    emails: emails.take(3).toList(),
  );
}
