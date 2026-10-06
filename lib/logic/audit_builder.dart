import '../models/audit.dart';
import '../models/business.dart';
import '../models/website_report.dart';
import 'html_analyzer.dart';

/// Turns what was found on Google Maps and the website into the five
/// audit rows shown on the graphic.
///
/// [site] is null while the website check hasn't run yet.
List<AuditItem> buildAudit(Business b, WebsiteReport? site) {
  final linkedSocial = b.hasWebsite ? socialPlatformOf(b.website) : null;
  final hasRealWebsite = b.hasWebsite && linkedSocial == null;
  final siteWorks = hasRealWebsite && site != null && site.reachable;

  return [
    _maps(b),
    _website(b, site, hasRealWebsite, linkedSocial),
    _social(site, siteWorks, linkedSocial),
    _seo(site, hasRealWebsite, siteWorks),
    _ai(site, hasRealWebsite, siteWorks),
  ];
}

String _rating(Business b) =>
    b.rating == null ? '' : '${b.rating!.toStringAsFixed(1)}★ from ${b.reviewCount} reviews';

AuditItem _maps(Business b) {
  const area = AuditArea.maps;
  if (b.status == 'CLOSED_TEMPORARILY') {
    return const AuditItem(
      area: area,
      status: AuditStatus.warn,
      verdict: 'Shown closed',
      detail: 'Google Maps shows this business as temporarily closed.',
    );
  }
  if (b.rating == null || b.reviewCount == 0) {
    return const AuditItem(
      area: area,
      status: AuditStatus.warn,
      verdict: 'No reviews',
      detail: 'Listed on Google Maps but has no reviews yet.',
    );
  }
  if (b.reviewCount < 20) {
    return AuditItem(
      area: area,
      status: AuditStatus.warn,
      verdict: 'Few reviews',
      detail: 'Listed, ${_rating(b)}. More reviews help it rank in map results.',
    );
  }
  if (b.rating! < 4.0) {
    return AuditItem(
      area: area,
      status: AuditStatus.warn,
      verdict: 'Low rating',
      detail: 'Listed, ${_rating(b)}. Below 4★ loses customers to competitors.',
    );
  }
  return AuditItem(
    area: area,
    status: AuditStatus.good,
    verdict: 'Listed',
    detail: 'Listed, ${_rating(b)}.',
  );
}

AuditItem _website(
  Business b,
  WebsiteReport? site,
  bool hasRealWebsite,
  String? linkedSocial,
) {
  const area = AuditArea.website;
  if (!hasRealWebsite) {
    return AuditItem(
      area: area,
      status: AuditStatus.bad,
      verdict: 'Missing',
      detail: linkedSocial != null
          ? 'Google Maps links to a $linkedSocial page, not a website.'
          : 'No website is linked on Google Maps.',
    );
  }
  if (site == null) {
    return const AuditItem(
      area: area,
      status: AuditStatus.warn,
      verdict: 'Checking…',
      detail: 'Opening the website.',
    );
  }
  if (!site.reachable) {
    return AuditItem(
      area: area,
      status: AuditStatus.bad,
      verdict: 'Not working',
      detail: 'The website did not load${site.error.isEmpty ? '' : ' (${site.error})'}.',
    );
  }
  final seconds = (site.loadMs / 1000).toStringAsFixed(1);
  final problems = <String>[
    if (!site.https) 'not secure (no HTTPS)',
    if (!site.mobileFriendly) 'not mobile-friendly',
    if (site.loadMs > 4000) 'slow to load (${seconds}s)',
  ];
  if (problems.isEmpty) {
    return AuditItem(
      area: area,
      status: AuditStatus.good,
      verdict: 'Good',
      detail: 'Loads in ${seconds}s, secure and mobile-friendly.',
    );
  }
  return AuditItem(
    area: area,
    status: AuditStatus.warn,
    verdict: 'Needs work',
    detail: 'Website is ${_join(problems)}.',
  );
}

AuditItem _social(WebsiteReport? site, bool siteWorks, String? linkedSocial) {
  const area = AuditArea.social;
  final platforms = <String>{
    if (linkedSocial != null && linkedSocial != 'WhatsApp') linkedSocial,
    if (siteWorks) ...site!.socialLinks.keys.where((p) => p != 'WhatsApp'),
  }.toList();

  if (platforms.length >= 2) {
    return AuditItem(
      area: area,
      status: AuditStatus.good,
      verdict: 'Linked',
      detail: 'Found: ${platforms.join(', ')}.',
    );
  }
  if (platforms.length == 1) {
    return AuditItem(
      area: area,
      status: AuditStatus.warn,
      verdict: '${platforms.first} only',
      detail: 'Only a ${platforms.first} profile was found.',
    );
  }
  return AuditItem(
    area: area,
    status: siteWorks ? AuditStatus.bad : AuditStatus.warn,
    verdict: siteWorks ? 'Not linked' : 'Not found',
    detail: siteWorks
        ? 'The website has no links to social media.'
        : 'No website to find social profiles from. Check by hand.',
  );
}

AuditItem _seo(WebsiteReport? site, bool hasRealWebsite, bool siteWorks) {
  const area = AuditArea.seo;
  if (!hasRealWebsite) {
    return const AuditItem(
      area: area,
      status: AuditStatus.bad,
      verdict: 'Weak',
      detail: 'Without a website it only shows up in map results.',
    );
  }
  if (site == null) {
    return const AuditItem(
      area: area,
      status: AuditStatus.warn,
      verdict: 'Checking…',
      detail: 'Opening the website.',
    );
  }
  if (!siteWorks) {
    return const AuditItem(
      area: area,
      status: AuditStatus.bad,
      verdict: 'Weak',
      detail: "Search engines can't read a site that doesn't load.",
    );
  }
  final missing = <String>[
    if (!site.https) 'HTTPS',
    if (site.title.trim().isEmpty) 'page title',
    if (site.metaDescription.trim().isEmpty) 'meta description',
    if (!site.hasH1) 'main heading (H1)',
    if (!site.mobileFriendly) 'mobile viewport',
  ];
  final passed = site.seoPassed;
  if (missing.isEmpty) {
    return const AuditItem(
      area: area,
      status: AuditStatus.good,
      verdict: 'Good',
      detail: 'Passes all 5 basic on-page checks.',
    );
  }
  return AuditItem(
    area: area,
    status: passed >= 3 ? AuditStatus.warn : AuditStatus.bad,
    verdict: passed >= 3 ? 'Weak' : 'Poor',
    detail: 'Passes $passed of ${WebsiteReport.seoTotal} basic checks. Missing: ${_join(missing)}.',
  );
}

AuditItem _ai(WebsiteReport? site, bool hasRealWebsite, bool siteWorks) {
  const area = AuditArea.ai;
  if (hasRealWebsite && site == null) {
    return const AuditItem(
      area: area,
      status: AuditStatus.warn,
      verdict: 'Checking…',
      detail: 'Opening the website.',
    );
  }
  if (!siteWorks) {
    return const AuditItem(
      area: area,
      status: AuditStatus.bad,
      verdict: 'Not ready',
      detail: 'AI tools like ChatGPT and Gemini have little to read about it.',
    );
  }
  if (site!.structuredData && site.hasFaq) {
    return const AuditItem(
      area: area,
      status: AuditStatus.good,
      verdict: 'Ready',
      detail: 'Has structured data and FAQ content.',
    );
  }
  if (site.structuredData) {
    return const AuditItem(
      area: area,
      status: AuditStatus.warn,
      verdict: 'Partly ready',
      detail: 'Has structured data, but no FAQ content.',
    );
  }
  return const AuditItem(
    area: area,
    status: AuditStatus.bad,
    verdict: 'Not ready',
    detail: 'No structured data (schema) for AI tools to read.',
  );
}

/// Preset verdicts the user can switch a row to by tapping it.
List<(AuditStatus, String)> verdictChoices(AuditArea area) => switch (area) {
      AuditArea.maps => const [
          (AuditStatus.good, 'Listed'),
          (AuditStatus.warn, 'Few reviews'),
          (AuditStatus.warn, 'Low rating'),
        ],
      AuditArea.website => const [
          (AuditStatus.good, 'Good'),
          (AuditStatus.warn, 'Needs work'),
          (AuditStatus.bad, 'Missing'),
          (AuditStatus.bad, 'Not working'),
        ],
      AuditArea.social => const [
          (AuditStatus.good, 'Active'),
          (AuditStatus.warn, 'Inactive'),
          (AuditStatus.warn, 'Facebook only'),
          (AuditStatus.bad, 'Not found'),
        ],
      AuditArea.seo => const [
          (AuditStatus.good, 'Good'),
          (AuditStatus.warn, 'Weak'),
          (AuditStatus.bad, 'Poor'),
        ],
      AuditArea.ai => const [
          (AuditStatus.good, 'Ready'),
          (AuditStatus.warn, 'Partly ready'),
          (AuditStatus.bad, 'Not ready'),
        ],
    };

String _join(List<String> parts) {
  if (parts.length <= 1) return parts.join();
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}
