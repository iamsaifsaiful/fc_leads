import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

class SettingsStore {
  static const _p = 'settings.';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    const d = AppSettings();
    String s(String key, String fallback) => p.getString('$_p$key') ?? fallback;
    return AppSettings(
      apiKey: s('apiKey', d.apiKey),
      senderName: s('senderName', d.senderName),
      agencyName: s('agencyName', d.agencyName),
      agencyWebsite: s('agencyWebsite', d.agencyWebsite),
      whatsapp: s('whatsapp', d.whatsapp),
      email: s('email', d.email),
      accent: p.getInt('${_p}accent') ?? d.accent,
      defaultCountry: s('defaultCountry', d.defaultCountry),
      whatsappTemplate: s('whatsappTemplate', d.whatsappTemplate),
      emailSubjectTemplate: s('emailSubjectTemplate', d.emailSubjectTemplate),
      emailTemplate: s('emailTemplate', d.emailTemplate),
      paymentTemplate: s('paymentTemplate', d.paymentTemplate),
      paymentInfo: s('paymentInfo', d.paymentInfo),
      currency: s('currency', d.currency),
      remindersOn: p.getBool('${_p}remindersOn') ?? d.remindersOn,
      reminderHour: p.getInt('${_p}reminderHour') ?? d.reminderHour,
      reminderMinute: p.getInt('${_p}reminderMinute') ?? d.reminderMinute,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('${_p}apiKey', s.apiKey.trim());
    await p.setString('${_p}senderName', s.senderName.trim());
    await p.setString('${_p}agencyName', s.agencyName.trim());
    await p.setString('${_p}agencyWebsite', s.agencyWebsite.trim());
    await p.setString('${_p}whatsapp', s.whatsapp.trim());
    await p.setString('${_p}email', s.email.trim());
    await p.setInt('${_p}accent', s.accent);
    await p.setString('${_p}defaultCountry', s.defaultCountry);
    await p.setString('${_p}whatsappTemplate', s.whatsappTemplate);
    await p.setString('${_p}emailSubjectTemplate', s.emailSubjectTemplate);
    await p.setString('${_p}emailTemplate', s.emailTemplate);
    await p.setString('${_p}paymentTemplate', s.paymentTemplate);
    await p.setString('${_p}paymentInfo', s.paymentInfo);
    await p.setString('${_p}currency', s.currency.trim().isEmpty ? 'BDT' : s.currency.trim());
    await p.setBool('${_p}remindersOn', s.remindersOn);
    await p.setInt('${_p}reminderHour', s.reminderHour);
    await p.setInt('${_p}reminderMinute', s.reminderMinute);
  }
}
