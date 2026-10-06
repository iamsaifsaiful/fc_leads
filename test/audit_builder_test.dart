import 'package:fc_leads/logic/audit_builder.dart';
import 'package:fc_leads/models/audit.dart';
import 'package:fc_leads/models/website_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

AuditItem _row(List<AuditItem> items, AuditArea area) => items.firstWhere((i) => i.area == area);

void main() {
  test('always returns the five rows in order', () {
    final items = buildAudit(noWebsite, null);
    expect(items.map((i) => i.area), AuditArea.values);
  });

  test('no website: website missing, SEO and AI weak, few reviews', () {
    final items = buildAudit(noWebsite, null);
    expect(_row(items, AuditArea.maps).verdict, 'Few reviews');
    expect(_row(items, AuditArea.website).verdict, 'Missing');
    expect(_row(items, AuditArea.website).status, AuditStatus.bad);
    expect(_row(items, AuditArea.social).verdict, 'Not found');
    expect(_row(items, AuditArea.seo).status, AuditStatus.bad);
    expect(_row(items, AuditArea.ai).verdict, 'Not ready');
  });

  test('a Facebook page linked as the website counts as no website', () {
    final items = buildAudit(facebookOnly, null);
    expect(_row(items, AuditArea.maps).verdict, 'Listed');
    expect(_row(items, AuditArea.website).verdict, 'Missing');
    expect(_row(items, AuditArea.website).detail, contains('Facebook page'));
    expect(_row(items, AuditArea.social).verdict, 'Facebook only');
  });

  test('website not checked yet shows Checking', () {
    final items = buildAudit(withWebsite, null);
    expect(_row(items, AuditArea.website).verdict, 'Checking…');
    expect(_row(items, AuditArea.seo).verdict, 'Checking…');
  });

  test('strong website gets all good rows', () {
    final items = buildAudit(withWebsite, goodSite);
    expect(items.every((i) => i.status == AuditStatus.good), isTrue);
    expect(_row(items, AuditArea.social).detail, 'Found: Facebook, Instagram.');
  });

  test('weak website lists its problems', () {
    final items = buildAudit(withWebsite, weakSite);
    final site = _row(items, AuditArea.website);
    expect(site.verdict, 'Needs work');
    expect(site.detail, 'Website is not secure (no HTTPS), not mobile-friendly and slow to load (5.2s).');
    final seo = _row(items, AuditArea.seo);
    expect(seo.verdict, 'Poor');
    expect(seo.detail, contains('Passes 1 of 5'));
    expect(_row(items, AuditArea.social).verdict, 'Not linked');
  });

  test('broken website is reported as not working', () {
    final items = buildAudit(withWebsite, WebsiteReport.unreachable('x', 'timed out'));
    expect(_row(items, AuditArea.website).verdict, 'Not working');
    expect(_row(items, AuditArea.website).detail, contains('timed out'));
    expect(_row(items, AuditArea.ai).verdict, 'Not ready');
  });

  test('every area offers verdicts to switch to', () {
    for (final area in AuditArea.values) {
      expect(verdictChoices(area), isNotEmpty);
    }
  });
}
