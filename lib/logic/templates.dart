/// Message templates. Words in {braces} are filled in for each business.

const defaultWhatsappTemplate = '''Hi {business} team,

{me}. I found {business} on Google Maps and did a quick, free check of how you show up online.

{issues}

I've attached a one-page summary. If it helps, I can send the full report with simple steps to fix these, free of charge. Would that be useful?

{agency_website}''';

const defaultEmailSubjectTemplate = 'A quick online audit for {business}';

const defaultEmailTemplate = '''Hello {business} team,

{me}. I found {business} on Google Maps and did a quick, free check of how you show up online.

{issues}

From what we saw, these would help most: {services}.

I've attached a one-page summary of what we found. If it's useful, I'd be happy to send the full report with a simple plan to fix these, at no cost. Just reply to this email or message us on WhatsApp.

Best regards,
{signature}''';

const defaultPaymentTemplate = '''Hi {client},

A friendly reminder from {agency}: the monthly fee of {amount} for {services} ({month}) is due on {due_date}.

{payment_info}

Thank you for working with us!
{my_name}''';

/// Placeholders for the payment reminder.
const paymentPlaceholders = <String, String>{
  'client': 'Client name (or contact person)',
  'amount': 'Monthly fee with currency, e.g. "BDT 15,000"',
  'services': 'The services you provide them',
  'month': 'The month being paid for, e.g. "October 2026"',
  'due_date': 'The due date, e.g. "10 Oct"',
  'payment_info': 'How to pay (from Settings), e.g. bKash or bank details',
  'agency': 'Agency name',
  'my_name': 'Your name from Settings',
};

/// Every placeholder, with what it becomes. Shown on the Templates screen.
const placeholders = <String, String>{
  'business': 'The business name',
  'me': '"I\'m <your name> from <agency>" (or "This is <agency>")',
  'issues': 'The problems found, as a bulleted list',
  'services': 'The services that would help, e.g. "Website Design and SEO & Growth Support"',
  'city': 'The city you searched in',
  'category': 'The business type, e.g. "Dental clinics"',
  'my_name': 'Your name from Settings',
  'agency': 'Agency name',
  'agency_website': 'Agency website',
  'agency_whatsapp': 'Agency WhatsApp number',
  'agency_email': 'Agency email',
  'signature': 'Your name, agency, website, WhatsApp and email on separate lines',
};

final _placeholderRe = RegExp(r'\{([a-z_]+)\}');

/// Replaces {key} with [values][key]. Unknown keys are left as they are.
/// Tidies the result: no runs of blank lines, no trailing spaces.
String renderTemplate(String template, Map<String, String> values) {
  final filled = template.replaceAllMapped(_placeholderRe, (m) {
    final key = m.group(1)!;
    return values.containsKey(key) ? values[key]! : m.group(0)!;
  });
  return filled
      .split('\n')
      .map((l) => l.trimRight())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
