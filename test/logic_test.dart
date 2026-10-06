import 'package:fc_leads/data/categories.dart';
import 'package:fc_leads/data/geo.dart';
import 'package:fc_leads/data/services.dart';
import 'package:fc_leads/logic/audit_builder.dart';
import 'package:fc_leads/logic/lead_filter.dart';
import 'package:fc_leads/logic/messages.dart';
import 'package:fc_leads/logic/templates.dart';
import 'package:fc_leads/models/business.dart';
import 'package:fc_leads/models/lead.dart';
import 'package:fc_leads/models/search_spec.dart';
import 'package:fc_leads/models/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('templates', () {
    test('fills placeholders and leaves unknown ones', () {
      expect(renderTemplate('Hi {business}, {nope}!', {'business': 'Rahim'}), 'Hi Rahim, {nope}!');
    });

    test('tidies blank lines and trailing spaces', () {
      expect(renderTemplate('a  \n\n\n\nb\n{x}\n', {'x': ''}), 'a\n\nb');
    });

    test('recommends services for the problems found', () {
      final s = recommendedServices(buildAudit(noWebsite, null));
      expect(s, [
        AgencyService.websiteDesign,
        AgencyService.seoGrowth,
        AgencyService.reelsVideo,
        AgencyService.graphicsBranding,
      ]);
    });

    test('falls back to the category when all is well', () {
      final s = recommendedServices(buildAudit(withWebsite, goodSite), category: categoryByLabel('Dental clinics'));
      expect(s, [AgencyService.websiteDesign, AgencyService.seoGrowth]);
    });

    test('email uses the services and city', () {
      final m = emailMessage(noWebsite, buildAudit(noWebsite, null), const AppSettings(), city: 'Dhaka');
      expect(m.body, contains('Website Design, SEO & Growth Support, Reels & Video Editing and Graphics & Branding'));
    });
  });

  group('search', () {
    test('builds the Google query from picked values', () {
      const s = SearchSpec(
        category: 'Dental clinics',
        categoryQuery: 'dental clinics',
        countryCode: 'BD',
        countryName: 'Bangladesh',
        city: 'Dhaka',
        area: 'Dhanmondi',
      );
      expect(s.query, 'dental clinics in Dhanmondi, Dhaka, Bangladesh');
      expect(s.title, 'Dental clinics · Dhanmondi, Dhaka');
      expect(s.isComplete, isTrue);
    });

    test('typed search is sent as it is', () {
      const s = SearchSpec(freeText: ' rooftop cafes Gulshan ', countryCode: 'BD');
      expect(s.query, 'rooftop cafes Gulshan');
    });

    test('a type is needed', () {
      expect(const SearchSpec(city: 'Dhaka', countryName: 'Bangladesh').isComplete, isFalse);
    });

    test('every category belongs to a listed sector', () {
      for (final c in categories) {
        expect(sectors, contains(c.sector), reason: c.label);
        expect(c.services, isNotEmpty, reason: c.label);
      }
    });

    test('folds accents for search', () {
      expect(foldForSearch('São Paulo'), 'sao paulo');
      expect(foldForSearch('Kraków'), 'krakow');
    });
  });

  group('lead filter', () {
    final now = DateTime(2026, 10, 7, 12);
    final a = Lead(
      business: noWebsite,
      items: buildAudit(noWebsite, null),
      savedAt: now,
      category: 'Cafes & coffee shops',
      countryCode: 'BD',
      city: 'Dhaka',
      followUp: DateTime(2026, 10, 7),
    );
    final b = Lead(
      business: withWebsite,
      items: buildAudit(withWebsite, goodSite),
      savedAt: now.subtract(const Duration(days: 2)),
      status: LeadStatus.won,
      whatsappSentAt: now,
      countryCode: 'AE',
      notes: 'Owner is Dr. Karim',
    );
    final c = Lead(
      business: facebookOnly,
      items: buildAudit(facebookOnly, null),
      savedAt: now.subtract(const Duration(days: 1)),
      status: LeadStatus.contacted,
      emailSentAt: now,
      followUp: DateTime(2026, 10, 20),
    );
    final all = [a, b, c];
    List<String> names(LeadFilter f) => f.apply(all, now: now).map((l) => l.business.name).toList();

    test('newest first by default', () {
      expect(names(const LeadFilter()), ['Rahim Tea House', 'Lamia Boutique', 'Green Leaf Dental']);
    });

    test('status, contact, website and follow-up filters', () {
      expect(names(const LeadFilter(statuses: {LeadStatus.won})), ['Green Leaf Dental']);
      expect(names(const LeadFilter(contact: ContactFilter.notContacted)), ['Rahim Tea House']);
      expect(names(const LeadFilter(contact: ContactFilter.email)), ['Lamia Boutique']);
      expect(names(const LeadFilter(contact: ContactFilter.sent)), ['Lamia Boutique', 'Green Leaf Dental']);
      expect(names(const LeadFilter(noWebsiteOnly: true)), ['Rahim Tea House', 'Lamia Boutique']);
      expect(names(const LeadFilter(followUpDue: true)), ['Rahim Tea House']);
      expect(names(const LeadFilter(countryCode: 'AE')), ['Green Leaf Dental']);
      expect(names(const LeadFilter(category: 'Cafes & coffee shops')), ['Rahim Tea House']);
    });

    test('search looks in notes too', () {
      expect(names(const LeadFilter(query: 'karim')), ['Green Leaf Dental']);
    });

    test('sorts', () {
      expect(names(const LeadFilter(sort: LeadSort.name)), ['Green Leaf Dental', 'Lamia Boutique', 'Rahim Tea House']);
      expect(names(const LeadFilter(sort: LeadSort.followUp)).first, 'Rahim Tea House');
      expect(names(const LeadFilter(sort: LeadSort.mostIssues)).last, 'Green Leaf Dental');
    });

    test('counts sheet filters', () {
      expect(const LeadFilter(noWebsiteOnly: true, countryCode: 'BD').sheetCount, 2);
      expect(const LeadFilter(noWebsiteOnly: true, query: 'x').clearSheet().sheetCount, 0);
    });

    test('dashboard numbers', () {
      final s = LeadStats(all, now: now);
      expect(s.total, 3);
      expect(s.contacted, 2);
      expect(s.followUpsDue, 1);
      expect(s.byStatus[LeadStatus.won], 1);
    });

    test('CSV quotes commas and quotes', () {
      final odd = Lead(
        business: const Business(id: 'x', name: 'Rahim "Tea", House'),
        items: const [],
        savedAt: now,
        notes: 'line1\nline2',
      );
      final csv = leadsToCsv([odd]);
      expect(csv.split('\n').first, startsWith('Name,Category,City'));
      expect(csv, contains('"Rahim ""Tea"", House"'));
      expect(csv, contains('"line1\nline2"'));
    });

    test('old saved leads still load', () {
      final old = Lead.fromJson({
        'business': noWebsite.toJson(),
        'items': const [],
        'savedAt': '2026-10-06T10:00:00.000',
      });
      expect(old.status, LeadStatus.newLead);
      expect(old.socialLinks, isEmpty);
      expect(old.whatsappText, isNull);
    });
  });
}
