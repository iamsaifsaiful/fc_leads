/// Turns a Google Maps phone number into the digits WhatsApp expects
/// (country code, no "+", no spaces), e.g. "8801711234567".
///
/// Returns an empty string when there is no usable number.
String whatsappNumber({
  String international = '',
  String national = '',
  String defaultCountryCode = '880',
}) {
  final intl = international.replaceAll(RegExp(r'\D'), '');
  if (intl.length >= 8) return intl;

  var local = national.replaceAll(RegExp(r'\D'), '');
  if (local.length < 8) return '';
  if (local.startsWith('00')) return local.substring(2);
  if (local.startsWith(defaultCountryCode)) return local;
  if (local.startsWith('0')) local = local.substring(1);
  return '$defaultCountryCode$local';
}

/// Bangladeshi mobile numbers are 880 + 1 + 9 digits. Landlines can't
/// usually receive WhatsApp. Numbers from other countries are not judged.
bool looksLikeMobile(String digits) {
  if (!digits.startsWith('880')) return digits.isNotEmpty;
  return RegExp(r'^8801[3-9]\d{8}$').hasMatch(digits);
}
