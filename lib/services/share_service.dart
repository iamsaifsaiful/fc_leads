import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum ShareResult { opened, notInstalled, failed }

/// Opens WhatsApp or an email app with everything filled in.
///
/// WhatsApp and email apps never let another app press Send, so the user
/// always taps Send in that app.
class ShareService {
  static const _channel = MethodChannel('fc_leads/share');

  /// Why the last call failed, for the error message.
  String lastError = '';

  Future<ShareResult> _call(String method, Map<String, Object?> args, Future<ShareResult> Function() fallback) async {
    lastError = '';
    try {
      final r = await _channel.invokeMethod<String>(method, args);
      if (r == 'not_installed') return ShareResult.notInstalled;
      return ShareResult.opened;
    } on MissingPluginException {
      return fallback();
    } on PlatformException catch (e) {
      lastError = e.message ?? e.code;
      return ShareResult.failed;
    } catch (e) {
      lastError = e.toString();
      return ShareResult.failed;
    }
  }

  /// Opens the chat with [phone] and types [text] into it.
  Future<ShareResult> whatsappChat({required String phone, required String text}) => _call(
        'whatsappChat',
        {'phone': phone, 'text': text},
        () async => await launchUrl(
          Uri.https('wa.me', '/$phone', {'text': text}),
          mode: LaunchMode.externalApplication,
        )
            ? ShareResult.opened
            : ShareResult.failed,
      );

  /// Sends the graphic (with [caption]) into the chat with [phone].
  Future<ShareResult> whatsappImage({
    required String imagePath,
    required String phone,
    String caption = '',
  }) =>
      _call(
        'whatsappImage',
        {'path': imagePath, 'phone': phone, 'text': caption},
        () async => ShareResult.failed,
      );

  Future<ShareResult> email({
    required String imagePath,
    required String to,
    required String subject,
    required String body,
  }) =>
      _call(
        'email',
        {'path': imagePath, 'to': to, 'subject': subject, 'body': body},
        () async => await launchUrl(Uri(
          scheme: 'mailto',
          path: to,
          query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
        ))
            ? ShareResult.opened
            : ShareResult.failed,
      );

  /// Opens the Android share sheet for any file (image, CSV…).
  Future<ShareResult> shareFile({
    required String path,
    String mimeType = 'image/png',
    String text = '',
    String subject = '',
  }) =>
      _call(
        'shareFile',
        {'path': path, 'mime': mimeType, 'text': text, 'subject': subject},
        () async => ShareResult.failed,
      );
}
