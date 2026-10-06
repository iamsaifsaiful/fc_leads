import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum ShareResult { opened, notInstalled, failed }

/// Opens WhatsApp or an email app with the graphic, text and recipient
/// filled in. The user taps Send in that app.
class ShareService {
  static const _channel = MethodChannel('fc_leads/share');

  Future<ShareResult> whatsapp({
    required String imagePath,
    required String phone,
    required String text,
  }) async {
    try {
      final r = await _channel.invokeMethod<String>('whatsapp', {
        'path': imagePath,
        'phone': phone,
        'text': text,
      });
      return r == 'not_installed' ? ShareResult.notInstalled : ShareResult.opened;
    } on MissingPluginException {
      // Not on Android: fall back to a wa.me link (text only).
      final uri = Uri.https('wa.me', '/$phone', {'text': text});
      return await launchUrl(uri, mode: LaunchMode.externalApplication)
          ? ShareResult.opened
          : ShareResult.failed;
    } catch (_) {
      return ShareResult.failed;
    }
  }

  Future<ShareResult> email({
    required String imagePath,
    required String to,
    required String subject,
    required String body,
  }) async {
    try {
      final r = await _channel.invokeMethod<String>('email', {
        'path': imagePath,
        'to': to,
        'subject': subject,
        'body': body,
      });
      return r == 'not_installed' ? ShareResult.notInstalled : ShareResult.opened;
    } on MissingPluginException {
      final uri = Uri(
        scheme: 'mailto',
        path: to,
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );
      return await launchUrl(uri) ? ShareResult.opened : ShareResult.failed;
    } catch (_) {
      return ShareResult.failed;
    }
  }

  Future<ShareResult> share({required String imagePath, required String text}) async {
    try {
      await _channel.invokeMethod<String>('share', {'path': imagePath, 'text': text});
      return ShareResult.opened;
    } catch (_) {
      return ShareResult.failed;
    }
  }
}
