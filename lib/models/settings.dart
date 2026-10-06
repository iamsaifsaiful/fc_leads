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
    this.paymentTemplate = defaultPaymentTemplate,
    this.paymentInfo = '',
    this.currency = 'BDT',
    this.remindersOn = true,
    this.reminderHour = 10,
    this.reminderMinute = 0,
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

  /// Payment reminder sent to clients on their due date.
  final String paymentTemplate;

  /// How clients pay (bKash, bank account…), added to payment reminders.
  final String paymentInfo;

  /// Default currency for new clients.
  final String currency;

  /// Phone notifications for follow-ups and payment due dates.
  final bool remindersOn;
  final int reminderHour;
  final int reminderMinute;

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
    String? paymentTemplate,
    String? paymentInfo,
    String? currency,
    bool? remindersOn,
    int? reminderHour,
    int? reminderMinute,
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
        paymentTemplate: paymentTemplate ?? this.paymentTemplate,
        paymentInfo: paymentInfo ?? this.paymentInfo,
        currency: currency ?? this.currency,
        remindersOn: remindersOn ?? this.remindersOn,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
      );
}
