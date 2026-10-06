import '../logic/templates.dart';

/// The user's own details, shown on every graphic and message.
class AppSettings {
  const AppSettings({
    this.apiKey = '',
    this.senderName = '',
    this.agencyName = 'FansConnector',
    this.agencyWebsite = 'fansconnector.com',
    this.whatsapp = '',
    this.email = '',
    this.accent = 0,
    this.defaultCountry = 'BD',
    this.whatsappTemplate = defaultWhatsappTemplate,
    this.emailSubjectTemplate = defaultEmailSubjectTemplate,
    this.emailTemplate = defaultEmailTemplate,
  });

  /// Google Places API key. Stays on the phone.
  final String apiKey;
  final String senderName;
  final String agencyName;
  final String agencyWebsite;

  /// The agency's own WhatsApp number, shown on the graphic.
  final String whatsapp;
  final String email;

  /// Index into [accentColors] for the graphic.
  final int accent;

  /// ISO country code used when a lead has none.
  final String defaultCountry;
  final String whatsappTemplate;
  final String emailSubjectTemplate;
  final String emailTemplate;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? apiKey,
    String? senderName,
    String? agencyName,
    String? agencyWebsite,
    String? whatsapp,
    String? email,
    int? accent,
    String? defaultCountry,
    String? whatsappTemplate,
    String? emailSubjectTemplate,
    String? emailTemplate,
  }) =>
      AppSettings(
        apiKey: apiKey ?? this.apiKey,
        senderName: senderName ?? this.senderName,
        agencyName: agencyName ?? this.agencyName,
        agencyWebsite: agencyWebsite ?? this.agencyWebsite,
        whatsapp: whatsapp ?? this.whatsapp,
        email: email ?? this.email,
        accent: accent ?? this.accent,
        defaultCountry: defaultCountry ?? this.defaultCountry,
        whatsappTemplate: whatsappTemplate ?? this.whatsappTemplate,
        emailSubjectTemplate: emailSubjectTemplate ?? this.emailSubjectTemplate,
        emailTemplate: emailTemplate ?? this.emailTemplate,
      );
}
