import 'audit.dart';
import 'business.dart';
import 'website_report.dart';

/// Where a lead is in the sales pipeline. Set by the user.
enum LeadStatus {
  newLead('New'),
  contacted('Contacted'),
  replied('Replied'),
  interested('Interested'),
  won('Won'),
  lost('Lost');

  const LeadStatus(this.label);
  final String label;
}

/// A business the user has opened, with its audit and their notes.
class Lead {
  const Lead({
    required this.business,
    required this.items,
    this.website,
    this.email = '',
    this.whatsappSentAt,
    this.emailSentAt,
    required this.savedAt,
    this.status = LeadStatus.newLead,
    this.notes = '',
    this.followUp,
    this.socialLinks = const {},
    this.category = '',
    this.countryCode = '',
    this.city = '',
    this.whatsappText,
    this.emailSubject,
    this.emailBody,
  });

  final Business business;
  final List<AuditItem> items;
  final WebsiteReport? website;

  /// Contact email, found on the website or typed by the user.
  final String email;
  final DateTime? whatsappSentAt;
  final DateTime? emailSentAt;
  final DateTime savedAt;
  final LeadStatus status;
  final String notes;
  final DateTime? followUp;

  /// Platform name → profile URL, found on the website or added by hand.
  final Map<String, String> socialLinks;

  /// The search category it was found under, e.g. "Dental clinics".
  final String category;
  final String countryCode;
  final String city;

  /// Message text the user edited for this lead. Null = use the template.
  final String? whatsappText;
  final String? emailSubject;
  final String? emailBody;

  bool get contacted => whatsappSentAt != null || emailSentAt != null;

  bool followUpDue(DateTime now) {
    if (followUp == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    return !followUp!.isAfter(today);
  }

  Lead copyWith({
    Business? business,
    List<AuditItem>? items,
    WebsiteReport? website,
    String? email,
    DateTime? whatsappSentAt,
    DateTime? emailSentAt,
    LeadStatus? status,
    String? notes,
    DateTime? followUp,
    bool clearFollowUp = false,
    Map<String, String>? socialLinks,
    String? category,
    String? countryCode,
    String? city,
    String? whatsappText,
    String? emailSubject,
    String? emailBody,
    bool clearMessages = false,
  }) =>
      Lead(
        business: business ?? this.business,
        items: items ?? this.items,
        website: website ?? this.website,
        email: email ?? this.email,
        whatsappSentAt: whatsappSentAt ?? this.whatsappSentAt,
        emailSentAt: emailSentAt ?? this.emailSentAt,
        savedAt: DateTime.now(),
        status: status ?? this.status,
        notes: notes ?? this.notes,
        followUp: clearFollowUp ? null : (followUp ?? this.followUp),
        socialLinks: socialLinks ?? this.socialLinks,
        category: category ?? this.category,
        countryCode: countryCode ?? this.countryCode,
        city: city ?? this.city,
        whatsappText: clearMessages ? null : (whatsappText ?? this.whatsappText),
        emailSubject: clearMessages ? null : (emailSubject ?? this.emailSubject),
        emailBody: clearMessages ? null : (emailBody ?? this.emailBody),
      );

  Map<String, dynamic> toJson() => {
        'business': business.toJson(),
        'items': items.map((i) => i.toJson()).toList(),
        'website': website?.toJson(),
        'email': email,
        'whatsappSentAt': whatsappSentAt?.toIso8601String(),
        'emailSentAt': emailSentAt?.toIso8601String(),
        'savedAt': savedAt.toIso8601String(),
        'status': status.name,
        'notes': notes,
        'followUp': followUp?.toIso8601String(),
        'socialLinks': socialLinks,
        'category': category,
        'countryCode': countryCode,
        'city': city,
        'whatsappText': whatsappText,
        'emailSubject': emailSubject,
        'emailBody': emailBody,
      };

  factory Lead.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    String? text(Object? v) => v is String ? v : null;
    final site = json['website'];
    return Lead(
      business: Business.fromJson(
          Map<String, dynamic>.from(json['business'] as Map? ?? const {})),
      items: (json['items'] as List? ?? const [])
          .map((e) => AuditItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      website: site is Map
          ? WebsiteReport.fromJson(Map<String, dynamic>.from(site))
          : null,
      email: (json['email'] as String?) ?? '',
      whatsappSentAt: date(json['whatsappSentAt']),
      emailSentAt: date(json['emailSentAt']),
      savedAt: date(json['savedAt']) ?? DateTime.now(),
      status: LeadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => LeadStatus.newLead,
      ),
      notes: (json['notes'] as String?) ?? '',
      followUp: date(json['followUp']),
      socialLinks: (json['socialLinks'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          const {},
      category: (json['category'] as String?) ?? '',
      countryCode: (json['countryCode'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      whatsappText: text(json['whatsappText']),
      emailSubject: text(json['emailSubject']),
      emailBody: text(json['emailBody']),
    );
  }
}
