import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../logic/lead_filter.dart';
import '../services/settings_controller.dart';
import '../theme.dart';
import '../widgets/pickers.dart';
import 'home_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings, required this.services});
  final SettingsController settings;
  final AppServices services;

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
  int _accent = 0;
  Country? _country;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_fill);
    _fill();
  }

  Future<void> _fill() async {
    if (_filled || !widget.settings.loaded) return;
    _filled = true;
    final s = widget.settings.value;
    _apiKey.text = s.apiKey;
    _sender.text = s.senderName;
    _agency.text = s.agencyName;
    _website.text = s.agencyWebsite;
    _whatsapp.text = s.whatsapp;
    _email.text = s.email;
    _accent = s.accent;
    final c = await widget.services.geo.country(s.defaultCountry);
    if (mounted) setState(() => _country = c);
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
      accent: _accent,
      defaultCountry: _country?.code,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  Future<void> _pickCountry() async {
    final c = await pickCountry(context, widget.services.geo, selectedCode: _country?.code);
    if (c != null) setState(() => _country = c);
  }

  Future<void> _exportAll() async {
    final leads = await widget.services.leads.all();
    if (leads.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No leads to export yet')));
      }
      return;
    }
    final path = await widget.services.renderer.writeExport('fc_leads_all.csv', leadsToCsv(leads));
    await widget.services.share.shareFile(path: path, mimeType: 'text/csv', subject: 'FC Leads export');
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
          const _Heading('Graphic colour'),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < Brand.accents.length; i++)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: Brand.accents[i], radius: 8),
                  label: Text(Brand.accentNames[i]),
                  selected: _accent == i,
                  onSelected: (_) => setState(() => _accent = i),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const _Heading('Home country'),
          Card(
            child: ListTile(
              leading: Text(_country?.flag ?? '', style: const TextStyle(fontSize: 22)),
              title: Text(_country?.name ?? 'Choose'),
              subtitle: const Text('Used for phone numbers without a country code'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickCountry,
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(height: 28),
          const _Heading('Your data'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.table_view_outlined, color: Brand.navy),
              title: const Text('Export all leads (CSV)'),
              subtitle: const Text('Open in Excel or Google Sheets'),
              onTap: _exportAll,
            ),
          ),
          const SizedBox(height: 20),
          const _Heading('About'),
          const Text(
            'FC Leads by FansConnector. City data: GeoNames (CC BY 4.0). '
            'Business data: Google Maps Platform.',
            style: TextStyle(color: Brand.muted, fontSize: 13, height: 1.4),
          ),
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
      child: Text(text, style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 18)),
    );
  }
}
