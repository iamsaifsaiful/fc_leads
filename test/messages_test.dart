import 'package:fc_leads/logic/audit_builder.dart';
import 'package:fc_leads/logic/messages.dart';
import 'package:fc_leads/models/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

const _settings = AppSettings(
  senderName: 'Saiful',
  agencyName: 'FansConnector',
  agencyWebsite: 'fansconnector.com',
  whatsapp: '+880 1700-000000',
);

void main() {
  test('WhatsApp message names the business and lists each issue', () {
    final items = buildAudit(noWebsite, null);
    final m = whatsappMessage(noWebsite, items, _settings);
    expect(m.body, startsWith('Hi Rahim Tea House team,'));
    expect(m.body, contains("I'm Saiful from FansConnector"));
    expect(m.body, contains("There's no website linked on Google Maps"));
    expect(m.body, contains('ChatGPT or Gemini'));
    expect('• '.allMatches(m.body).length, 5);
    expect(m.body, endsWith('fansconnector.com'));
  });

  test('email has a subject and a signature', () {
    final items = buildAudit(noWebsite, null);
    final m = emailMessage(noWebsite, items, _settings);
    expect(m.subject, 'A quick online audit for Rahim Tea House');
    expect(m.body, contains('Best regards,\nSaiful\nFansConnector\nfansconnector.com\nWhatsApp: +880 1700-000000'));
  });

  test('without a sender name the agency speaks', () {
    final items = buildAudit(noWebsite, null);
    final m = whatsappMessage(noWebsite, items, const AppSettings());
    expect(m.body, contains('This is FansConnector.'));
  });

  test('strong presence gets a positive message', () {
    final items = buildAudit(withWebsite, goodSite);
    final m = whatsappMessage(withWebsite, items, _settings);
    expect(m.body, contains('already looks strong'));
    expect(m.body, isNot(contains('• ')));
  });

  test('rows still being checked are left out', () {
    final items = buildAudit(withWebsite, null);
    final m = whatsappMessage(withWebsite, items, _settings);
    expect(m.body, isNot(contains('website')));
  });
}
