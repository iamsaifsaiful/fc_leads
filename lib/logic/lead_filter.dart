import '../models/audit.dart';
import '../models/lead.dart';
import 'html_analyzer.dart';

enum ContactFilter {
  any('Any'),
  notContacted('Not contacted'),
  sent('Contacted'),
  whatsapp('Sent on WhatsApp'),
  email('Sent by email');

  const ContactFilter(this.label);
  final String label;
}

enum LeadSort {
  newest('Newest first'),
  oldest('Oldest first'),
  name('Name A–Z'),
  mostIssues('Most problems'),
  followUp('Follow-up date');

  const LeadSort(this.label);
  final String label;
}

bool leadHasWebsite(Lead l) => l.business.hasWebsite && socialPlatformOf(l.business.website) == null;

int leadIssues(Lead l) => l.items.where((i) => i.status != AuditStatus.good).length;

/// What the Leads screen shows. Every field narrows the list.
class LeadFilter {
  const LeadFilter({
    this.query = '',
    this.statuses = const {},
    this.contact = ContactFilter.any,
    this.noWebsiteOnly = false,
    this.followUpDue = false,
    this.countryCode = '',
    this.category = '',
    this.sort = LeadSort.newest,
  });

  final String query;

  /// Empty = every status.
  final Set<LeadStatus> statuses;
  final ContactFilter contact;
  final bool noWebsiteOnly;
  final bool followUpDue;
  final String countryCode;
  final String category;
  final LeadSort sort;

  /// Filters set in the filter sheet (not search text, status chips or sort).
  int get sheetCount => [
        contact != ContactFilter.any,
        noWebsiteOnly,
        followUpDue,
        countryCode.isNotEmpty,
        category.isNotEmpty,
      ].where((x) => x).length;

  LeadFilter copyWith({
    String? query,
    Set<LeadStatus>? statuses,
    ContactFilter? contact,
    bool? noWebsiteOnly,
    bool? followUpDue,
    String? countryCode,
    String? category,
    LeadSort? sort,
  }) =>
      LeadFilter(
        query: query ?? this.query,
        statuses: statuses ?? this.statuses,
        contact: contact ?? this.contact,
        noWebsiteOnly: noWebsiteOnly ?? this.noWebsiteOnly,
        followUpDue: followUpDue ?? this.followUpDue,
        countryCode: countryCode ?? this.countryCode,
        category: category ?? this.category,
        sort: sort ?? this.sort,
      );

  /// Clears the sheet filters, keeping search text, status chips and sort.
  LeadFilter clearSheet() => LeadFilter(query: query, statuses: statuses, sort: sort);

  List<Lead> apply(List<Lead> leads, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final q = query.trim().toLowerCase();
    final out = leads.where((l) {
      if (q.isNotEmpty) {
        final hay = '${l.business.name} ${l.business.address} ${l.city} ${l.category} ${l.notes}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (statuses.isNotEmpty && !statuses.contains(l.status)) return false;
      switch (contact) {
        case ContactFilter.any:
          break;
        case ContactFilter.notContacted:
          if (l.contacted) return false;
        case ContactFilter.sent:
          if (!l.contacted) return false;
        case ContactFilter.whatsapp:
          if (l.whatsappSentAt == null) return false;
        case ContactFilter.email:
          if (l.emailSentAt == null) return false;
      }
      if (noWebsiteOnly && leadHasWebsite(l)) return false;
      if (followUpDue && !l.followUpDue(today)) return false;
      if (countryCode.isNotEmpty && l.countryCode != countryCode) return false;
      if (category.isNotEmpty && l.category != category) return false;
      return true;
    }).toList();

    switch (sort) {
      case LeadSort.newest:
        out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      case LeadSort.oldest:
        out.sort((a, b) => a.savedAt.compareTo(b.savedAt));
      case LeadSort.name:
        out.sort((a, b) => a.business.name.toLowerCase().compareTo(b.business.name.toLowerCase()));
      case LeadSort.mostIssues:
        out.sort((a, b) => leadIssues(b).compareTo(leadIssues(a)));
      case LeadSort.followUp:
        final far = DateTime(9999);
        out.sort((a, b) => (a.followUp ?? far).compareTo(b.followUp ?? far));
    }
    return out;
  }
}

/// Numbers for the Home dashboard.
class LeadStats {
  LeadStats(List<Lead> leads, {DateTime? now})
      : total = leads.length,
        contacted = leads.where((l) => l.contacted).length,
        noWebsite = leads.where((l) => !leadHasWebsite(l)).length,
        followUpsDue = leads.where((l) => l.followUpDue(now ?? DateTime.now())).length,
        byStatus = {
          for (final s in LeadStatus.values) s: leads.where((l) => l.status == s).length,
        };

  final int total;
  final int contacted;
  final int noWebsite;
  final int followUpsDue;
  final Map<LeadStatus, int> byStatus;
}

/// Leads as CSV for Excel or Google Sheets.
String leadsToCsv(List<Lead> leads) {
  String cell(Object? v) {
    final s = (v ?? '').toString();
    if (s.contains(RegExp('[",\n]'))) return '"${s.replaceAll('"', '""')}"';
    return s;
  }

  String date(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  const header = [
    'Name', 'Category', 'City', 'Country', 'Status', 'Phone', 'Email', 'Website',
    'Google Maps', 'Rating', 'Reviews', 'Problems', 'WhatsApp sent', 'Email sent',
    'Follow-up', 'Social links', 'Notes',
  ];
  final rows = <String>[header.join(',')];
  for (final l in leads) {
    final b = l.business;
    rows.add([
      b.name, l.category, l.city, l.countryCode, l.status.label,
      b.internationalPhone.isNotEmpty ? b.internationalPhone : b.phone,
      l.email, b.website, b.mapsUrl, b.rating?.toStringAsFixed(1) ?? '', b.reviewCount,
      l.items.where((i) => i.status != AuditStatus.good).map((i) => '${i.area.shortLabel}: ${i.verdict}').join('; '),
      date(l.whatsappSentAt), date(l.emailSentAt), date(l.followUp),
      l.socialLinks.values.join(' '), l.notes,
    ].map(cell).join(','));
  }
  return '${rows.join('\n')}\n';
}
