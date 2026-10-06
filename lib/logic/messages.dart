import '../data/categories.dart';
import '../data/services.dart';
import '../models/audit.dart';
import '../models/business.dart';
import '../models/settings.dart';
import 'templates.dart';

/// A message ready to drop into WhatsApp or an email app.
class OutreachMessage {
  const OutreachMessage({required this.subject, required this.body});
  final String subject;
  final String body;
}

/// One plain-English sentence for each row that needs attention.
String? issueSentence(AuditItem item) {
  if (item.status == AuditStatus.good) return null;
  final v = item.verdict.toLowerCase();
  if (v.contains('checking')) return null;
  switch (item.area) {
    case AuditArea.maps:
      if (v.contains('rating')) {
        return 'Your Google rating is under 4 stars, which sends some customers to competitors.';
      }
      if (v.contains('closed')) {
        return 'Google Maps shows you as temporarily closed, so customers may think you are shut.';
      }
      return 'Your Google Maps profile has few reviews, and more reviews help you appear higher in map results.';
    case AuditArea.website:
      if (v.contains('missing')) {
        if (item.detail.contains('links to a')) {
          return "Google Maps links to your social page, but there's no website where customers can see your services and prices.";
        }
        return "There's no website linked on Google Maps, so customers who find you can't see your services, prices or photos in one place.";
      }
      if (v.contains('not working')) {
        return "Your website didn't load when we checked, so visitors from Google may be leaving.";
      }
      if (item.detail.startsWith('Website is ')) {
        return 'Your website is ${item.detail.substring('Website is '.length)}';
      }
      return 'Your website needs some work to turn visitors into customers.';
    case AuditArea.social:
      if (v.endsWith(' only')) {
        final platform = item.verdict.substring(0, item.verdict.length - 5);
        return 'We could only find a $platform profile. Adding Instagram and short videos would reach more people.';
      }
      if (v.contains('inactive')) {
        return "Your social media hasn't been active lately, and customers often check it before visiting.";
      }
      return "We couldn't find your social media pages, which is where many customers check a business first.";
    case AuditArea.seo:
      return 'Your business is hard to find on Google Search beyond the map results.';
    case AuditArea.ai:
      return 'When people ask AI tools like ChatGPT or Gemini for a recommendation, your business is not set up to be mentioned.';
  }
}

/// The services that answer the problems found, most relevant first.
/// Falls back to the category's usual needs when nothing is wrong.
List<AgencyService> recommendedServices(List<AuditItem> items, {BusinessCategory? category}) {
  AuditStatus status(AuditArea a) =>
      items.firstWhere((i) => i.area == a, orElse: () => AuditItem(area: a, status: AuditStatus.good, verdict: '', detail: '')).status;
  bool weak(AuditArea a) {
    final i = items.where((i) => i.area == a);
    return i.isNotEmpty && status(a) != AuditStatus.good && !i.first.verdict.contains('Checking');
  }

  final picked = <AgencyService>[
    if (weak(AuditArea.website)) AgencyService.websiteDesign,
    if (weak(AuditArea.seo) || weak(AuditArea.ai) || weak(AuditArea.maps)) AgencyService.seoGrowth,
    if (weak(AuditArea.social)) AgencyService.reelsVideo,
    if (weak(AuditArea.social)) AgencyService.graphicsBranding,
  ];
  if (picked.isEmpty) {
    return category?.services.take(2).toList() ?? const [AgencyService.reelsVideo, AgencyService.seoGrowth];
  }
  return picked;
}

String _joinAnd(List<String> parts) {
  if (parts.length <= 1) return parts.join();
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}

/// Values for every placeholder in [placeholders].
Map<String, String> templateValues(
  Business b,
  List<AuditItem> items,
  AppSettings s, {
  String city = '',
  String category = '',
}) {
  final agency = s.agencyName.trim().isEmpty ? 'FansConnector' : s.agencyName.trim();
  final me = s.senderName.trim().isEmpty ? 'This is $agency' : "I'm ${s.senderName.trim()} from $agency";
  final issues = items.map(issueSentence).whereType<String>().toList();
  final issuesText = issues.isEmpty
      ? 'Your online presence already looks strong. We help businesses like '
          'yours turn that into more calls and visits with reels, design and '
          'ongoing SEO.'
      : 'A few things stood out:\n${issues.map((i) => '• $i').join('\n')}';
  final services = recommendedServices(items, category: categoryByLabel(category));
  final signature = [
    if (s.senderName.trim().isNotEmpty) s.senderName.trim(),
    agency,
    if (s.agencyWebsite.trim().isNotEmpty) s.agencyWebsite.trim(),
    if (s.whatsapp.trim().isNotEmpty) 'WhatsApp: ${s.whatsapp.trim()}',
    if (s.email.trim().isNotEmpty) s.email.trim(),
  ].join('\n');

  return {
    'business': b.name,
    'me': me,
    'issues': issuesText,
    'services': _joinAnd(services.map((x) => x.label).toList()),
    'city': city,
    'category': category,
    'my_name': s.senderName.trim(),
    'agency': agency,
    'agency_website': s.agencyWebsite.trim(),
    'agency_whatsapp': s.whatsapp.trim(),
    'agency_email': s.email.trim(),
    'signature': signature,
  };
}

/// Message for WhatsApp, from the WhatsApp template.
OutreachMessage whatsappMessage(
  Business b,
  List<AuditItem> items,
  AppSettings s, {
  String city = '',
  String category = '',
}) {
  final v = templateValues(b, items, s, city: city, category: category);
  return OutreachMessage(subject: '', body: renderTemplate(s.whatsappTemplate, v));
}

/// Email subject and body, from the email templates.
OutreachMessage emailMessage(
  Business b,
  List<AuditItem> items,
  AppSettings s, {
  String city = '',
  String category = '',
}) {
  final v = templateValues(b, items, s, city: city, category: category);
  return OutreachMessage(
    subject: renderTemplate(s.emailSubjectTemplate, v),
    body: renderTemplate(s.emailTemplate, v),
  );
}
