/// What the app found when it opened a business's website.
class WebsiteReport {
  const WebsiteReport({
    required this.url,
    required this.reachable,
    this.finalUrl = '',
    this.https = false,
    this.title = '',
    this.metaDescription = '',
    this.hasH1 = false,
    this.mobileFriendly = false,
    this.structuredData = false,
    this.hasFaq = false,
    this.loadMs = 0,
    this.socialLinks = const {},
    this.emails = const [],
    this.error = '',
  });

  final String url;
  final bool reachable;
  final String finalUrl;
  final bool https;
  final String title;
  final String metaDescription;
  final bool hasH1;

  /// Has a responsive viewport meta tag.
  final bool mobileFriendly;

  /// Has schema.org JSON-LD, which search engines and AI tools read.
  final bool structuredData;
  final bool hasFaq;
  final int loadMs;

  /// Platform name ("Facebook", "Instagram"...) → profile URL.
  final Map<String, String> socialLinks;
  final List<String> emails;
  final String error;

  /// The five basic on-page SEO checks.
  int get seoPassed => [
        https,
        title.trim().isNotEmpty,
        metaDescription.trim().isNotEmpty,
        hasH1,
        mobileFriendly,
      ].where((ok) => ok).length;

  static const int seoTotal = 5;

  factory WebsiteReport.unreachable(String url, String error) =>
      WebsiteReport(url: url, reachable: false, error: error);

  Map<String, dynamic> toJson() => {
        'url': url,
        'reachable': reachable,
        'finalUrl': finalUrl,
        'https': https,
        'title': title,
        'metaDescription': metaDescription,
        'hasH1': hasH1,
        'mobileFriendly': mobileFriendly,
        'structuredData': structuredData,
        'hasFaq': hasFaq,
        'loadMs': loadMs,
        'socialLinks': socialLinks,
        'emails': emails,
        'error': error,
      };

  factory WebsiteReport.fromJson(Map<String, dynamic> json) => WebsiteReport(
        url: (json['url'] as String?) ?? '',
        reachable: json['reachable'] == true,
        finalUrl: (json['finalUrl'] as String?) ?? '',
        https: json['https'] == true,
        title: (json['title'] as String?) ?? '',
        metaDescription: (json['metaDescription'] as String?) ?? '',
        hasH1: json['hasH1'] == true,
        mobileFriendly: json['mobileFriendly'] == true,
        structuredData: json['structuredData'] == true,
        hasFaq: json['hasFaq'] == true,
        loadMs: (json['loadMs'] as num?)?.toInt() ?? 0,
        socialLinks: (json['socialLinks'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            const {},
        emails: (json['emails'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        error: (json['error'] as String?) ?? '',
      );
}
