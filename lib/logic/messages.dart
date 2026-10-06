import '../models/audit.dart';
import '../models/business.dart';
import '../models/settings.dart';

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
      if (v.contains('checking')) return null;
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
      if (v.contains('checking')) return null;
      return 'Your business is hard to find on Google Search beyond the map results.';
    case AuditArea.ai:
      if (v.contains('checking')) return null;
      return 'When people ask AI tools like ChatGPT or Gemini for a recommendation, your business is not set up to be mentioned.';
  }
}

String _intro(Business b, AppSettings s) {
  final who = s.senderName.trim().isEmpty
      ? 'This is ${s.agencyName}'
      : "I'm ${s.senderName.trim()} from ${s.agencyName}";
  return '$who. I found ${b.name} on Google Maps and did a quick, free check '
      'of how you show up online.';
}

String _findings(List<AuditItem> items) {
  final issues = items.map(issueSentence).whereType<String>().toList();
  if (issues.isEmpty) {
    return 'Your online presence already looks strong. We help businesses like '
        'yours turn that into more calls and visits with reels, design and '
        'ongoing SEO.';
  }
  return 'A few things stood out:\n${issues.map((i) => '• $i').join('\n')}';
}

/// Short message for WhatsApp, sent as the caption of the graphic.
OutreachMessage whatsappMessage(Business b, List<AuditItem> items, AppSettings s) {
  final body = StringBuffer()
    ..writeln('Hi ${b.name} team,')
    ..writeln()
    ..writeln(_intro(b, s))
    ..writeln()
    ..writeln(_findings(items))
    ..writeln()
    ..writeln("I've attached a one-page summary. If it helps, I can send the full "
        'report with simple steps to fix these, free of charge. Would that be useful?');
  if (s.agencyWebsite.trim().isNotEmpty) {
    body
      ..writeln()
      ..write(s.agencyWebsite.trim());
  }
  return OutreachMessage(subject: '', body: body.toString().trimRight());
}

/// Longer message for email, with a subject and signature.
OutreachMessage emailMessage(Business b, List<AuditItem> items, AppSettings s) {
  final signature = [
    if (s.senderName.trim().isNotEmpty) s.senderName.trim(),
    s.agencyName,
    if (s.agencyWebsite.trim().isNotEmpty) s.agencyWebsite.trim(),
    if (s.whatsapp.trim().isNotEmpty) 'WhatsApp: ${s.whatsapp.trim()}',
    if (s.email.trim().isNotEmpty) s.email.trim(),
  ].join('\n');

  final body = StringBuffer()
    ..writeln('Hello ${b.name} team,')
    ..writeln()
    ..writeln(_intro(b, s))
    ..writeln()
    ..writeln(_findings(items))
    ..writeln()
    ..writeln("I've attached a one-page summary of what we found. If it's useful, "
        "I'd be happy to send the full report with a simple plan to fix these, "
        'at no cost. Just reply to this email or message us on WhatsApp.')
    ..writeln()
    ..writeln('Best regards,')
    ..write(signature);

  return OutreachMessage(
    subject: 'A quick online audit for ${b.name}',
    body: body.toString(),
  );
}
