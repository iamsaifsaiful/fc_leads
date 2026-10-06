import 'package:flutter/material.dart';

import '../services/settings_controller.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});
  final SettingsController settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKey = TextEditingController();
  final _sender = TextEditingController();
  final _agency = TextEditingController();
  final _website = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  bool _filled = false;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_fill);
    _fill();
  }

  void _fill() {
    if (_filled || !widget.settings.loaded) return;
    final s = widget.settings.value;
    _apiKey.text = s.apiKey;
    _sender.text = s.senderName;
    _agency.text = s.agencyName;
    _website.text = s.agencyWebsite;
    _whatsapp.text = s.whatsapp;
    _email.text = s.email;
    _filled = true;
  }

  @override
  void dispose() {
    widget.settings.removeListener(_fill);
    for (final c in [_apiKey, _sender, _agency, _website, _whatsapp, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    await widget.settings.update(widget.settings.value.copyWith(
      apiKey: _apiKey.text.trim(),
      senderName: _sender.text.trim(),
      agencyName: _agency.text.trim().isEmpty ? 'FansConnector' : _agency.text.trim(),
      agencyWebsite: _website.text.trim(),
      whatsapp: _whatsapp.text.trim(),
      email: _email.text.trim(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type, String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _Heading('Google Places API key'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _apiKey,
              obscureText: !_showKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'API key',
                suffixIcon: IconButton(
                  tooltip: _showKey ? 'Hide key' : 'Show key',
                  icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
          ),
          const Text(
            'Google Cloud Console → create a project → turn on billing → enable '
            '"Places API (New)" → Credentials → Create API key. Restrict the key '
            'to Places API (New). The key is saved only on this phone.',
            style: TextStyle(color: Brand.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          const _Heading('Agency details'),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Used on every graphic and in every WhatsApp and email message.',
              style: TextStyle(color: Brand.muted, fontSize: 13),
            ),
          ),
          _field(_agency, 'Agency name', helper: 'Shown at the top of the graphic.'),
          _field(_website, 'Agency website', type: TextInputType.url, helper: 'Shown at the bottom of the graphic.'),
          _field(_whatsapp, 'Agency WhatsApp number', type: TextInputType.phone, helper: 'Shown on the graphic and in the email signature.'),
          _field(_email, 'Agency email', type: TextInputType.emailAddress, helper: 'Added to the email signature.'),
          _field(_sender, 'Your name', helper: 'Messages start "I\'m <your name> from <agency>".'),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 18),
      ),
    );
  }
}
