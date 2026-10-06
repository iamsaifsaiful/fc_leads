/// The user's own details, shown on every graphic and message.
class AppSettings {
  const AppSettings({
    this.apiKey = '',
    this.senderName = '',
    this.agencyName = 'FansConnector',
    this.agencyWebsite = 'fansconnector.com',
    this.whatsapp = '',
    this.email = '',
  });

  /// Google Places API key. Stays on the phone.
  final String apiKey;
  final String senderName;
  final String agencyName;
  final String agencyWebsite;

  /// The agency's own WhatsApp number, shown on the graphic.
  final String whatsapp;
  final String email;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? apiKey,
    String? senderName,
    String? agencyName,
    String? agencyWebsite,
    String? whatsapp,
    String? email,
  }) =>
      AppSettings(
        apiKey: apiKey ?? this.apiKey,
        senderName: senderName ?? this.senderName,
        agencyName: agencyName ?? this.agencyName,
        agencyWebsite: agencyWebsite ?? this.agencyWebsite,
        whatsapp: whatsapp ?? this.whatsapp,
        email: email ?? this.email,
      );
}
