import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

class SettingsStore {
  static const _prefix = 'settings.';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    const d = AppSettings();
    return AppSettings(
      apiKey: p.getString('${_prefix}apiKey') ?? d.apiKey,
      senderName: p.getString('${_prefix}senderName') ?? d.senderName,
      agencyName: p.getString('${_prefix}agencyName') ?? d.agencyName,
      agencyWebsite: p.getString('${_prefix}agencyWebsite') ?? d.agencyWebsite,
      whatsapp: p.getString('${_prefix}whatsapp') ?? d.whatsapp,
      email: p.getString('${_prefix}email') ?? d.email,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('${_prefix}apiKey', s.apiKey.trim());
    await p.setString('${_prefix}senderName', s.senderName.trim());
    await p.setString('${_prefix}agencyName', s.agencyName.trim());
    await p.setString('${_prefix}agencyWebsite', s.agencyWebsite.trim());
    await p.setString('${_prefix}whatsapp', s.whatsapp.trim());
    await p.setString('${_prefix}email', s.email.trim());
  }
}
