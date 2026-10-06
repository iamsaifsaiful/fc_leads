import 'audit.dart';
import 'business.dart';
import 'website_report.dart';

/// A business the user has opened, with its audit and what was sent.
class Lead {
  const Lead({
    required this.business,
    required this.items,
    this.website,
    this.email = '',
    this.whatsappSentAt,
    this.emailSentAt,
    required this.savedAt,
  });

  final Business business;
  final List<AuditItem> items;
  final WebsiteReport? website;

  /// Contact email, found on the website or typed by the user.
  final String email;
  final DateTime? whatsappSentAt;
  final DateTime? emailSentAt;
  final DateTime savedAt;

  bool get contacted => whatsappSentAt != null || emailSentAt != null;

  Lead copyWith({
    List<AuditItem>? items,
    String? email,
    DateTime? whatsappSentAt,
    DateTime? emailSentAt,
  }) =>
      Lead(
        business: business,
        items: items ?? this.items,
        website: website,
        email: email ?? this.email,
        whatsappSentAt: whatsappSentAt ?? this.whatsappSentAt,
        emailSentAt: emailSentAt ?? this.emailSentAt,
        savedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'business': business.toJson(),
        'items': items.map((i) => i.toJson()).toList(),
        'website': website?.toJson(),
        'email': email,
        'whatsappSentAt': whatsappSentAt?.toIso8601String(),
        'emailSentAt': emailSentAt?.toIso8601String(),
        'savedAt': savedAt.toIso8601String(),
      };

  factory Lead.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
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
    );
  }
}
