import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/audit_builder.dart';
import '../logic/html_analyzer.dart';
import '../logic/messages.dart';
import '../logic/phone.dart';
import '../models/audit.dart';
import '../models/business.dart';
import '../models/lead.dart';
import '../models/website_report.dart';
import '../services/settings_controller.dart';
import '../services/share_service.dart';
import '../theme.dart';
import '../widgets/audit_graphic.dart';
import '../widgets/status_pill.dart';
import 'home_shell.dart';

/// One business: what was found, the personalised graphic, and the
/// buttons that hand it to WhatsApp or email.
class LeadScreen extends StatefulWidget {
  const LeadScreen({
    super.key,
    required this.business,
    required this.settings,
    required this.services,
  });

  final Business business;
  final SettingsController settings;
  final AppServices services;

  @override
  State<LeadScreen> createState() => _LeadScreenState();
}

class _LeadScreenState extends State<LeadScreen> {
  final _graphicKey = GlobalKey();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  late List<AuditItem> _items;
  WebsiteReport? _site;
  Lead? _lead;
  bool _checking = false;
  bool _sending = false;

  Business get _b => widget.business;
  bool get _hasRealWebsite => _b.hasWebsite && socialPlatformOf(_b.website) == null;

  @override
  void initState() {
    super.initState();
    _items = buildAudit(_b, null);
    _phone.text = whatsappNumber(international: _b.internationalPhone, national: _b.phone);
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await widget.services.leads.find(_b.id);
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        _lead = saved;
        _items = saved.items;
        _site = saved.website;
        _email.text = saved.email;
      });
      return;
    }
    await _check();
  }

  /// Opens the website (if any), rebuilds the audit and saves the lead.
  Future<void> _check() async {
    if (_hasRealWebsite) {
      setState(() => _checking = true);
      final report = await widget.services.checker.check(_b.website);
      if (!mounted) return;
      setState(() {
        _site = report;
        _checking = false;
        if (_email.text.trim().isEmpty && report.emails.isNotEmpty) {
          _email.text = report.emails.first;
        }
      });
    }
    setState(() => _items = buildAudit(_b, _site));
    await _save();
  }

  Future<void> _save({DateTime? whatsappAt, DateTime? emailAt}) async {
    final base = _lead ??
        Lead(business: _b, items: _items, website: _site, savedAt: DateTime.now());
    final next = Lead(
      business: _b,
      items: _items,
      website: _site,
      email: _email.text.trim(),
      whatsappSentAt: whatsappAt ?? base.whatsappSentAt,
      emailSentAt: emailAt ?? base.emailSentAt,
      savedAt: DateTime.now(),
    );
    _lead = next;
    await widget.services.leads.save(next);
  }

  Future<void> _editRow(AuditItem item) async {
    final choice = await showModalBottomSheet<(AuditStatus, String)>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Change "${item.area.label}"',
                style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            for (final c in verdictChoices(item.area))
              ListTile(
                title: Text(c.$2),
                trailing: StatusPill(status: c.$1, text: c.$2),
                selected: c.$2 == item.verdict,
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _items = [
        for (final i in _items)
          i.area == item.area ? i.copyWith(status: choice.$1, verdict: choice.$2) : i,
      ];
    });
    await _save();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<String?> _renderGraphic() async {
    try {
      return await widget.services.renderer.renderToFile(_graphicKey, _b.name);
    } catch (e) {
      _toast('Could not create the graphic: $e');
      return null;
    }
  }

  Future<void> _sendWhatsApp() async {
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      _toast('Add a WhatsApp number first.');
      return;
    }
    setState(() => _sending = true);
    final path = await _renderGraphic();
    if (path == null || !mounted) {
      if (mounted) setState(() => _sending = false);
      return;
    }
    final message = whatsappMessage(_b, _items, widget.settings.value);
    final result = await widget.services.share.whatsapp(imagePath: path, phone: phone, text: message.body);
    if (!mounted) return;
    setState(() => _sending = false);
    switch (result) {
      case ShareResult.opened:
        await _save(whatsappAt: DateTime.now());
        if (mounted) setState(() {});
      case ShareResult.notInstalled:
        _toast('WhatsApp is not installed on this phone.');
      case ShareResult.failed:
        _toast('Could not open WhatsApp.');
    }
  }

  Future<void> _sendEmail() async {
    setState(() => _sending = true);
    final path = await _renderGraphic();
    if (path == null || !mounted) {
      if (mounted) setState(() => _sending = false);
      return;
    }
    final message = emailMessage(_b, _items, widget.settings.value);
    final result = await widget.services.share.email(
      imagePath: path,
      to: _email.text.trim(),
      subject: message.subject,
      body: message.body,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    switch (result) {
      case ShareResult.opened:
        await _save(emailAt: DateTime.now());
        if (mounted) setState(() {});
      case ShareResult.notInstalled:
        _toast('No email app found on this phone.');
      case ShareResult.failed:
        _toast('Could not open an email app.');
    }
  }

  Future<void> _shareElsewhere() async {
    setState(() => _sending = true);
    final path = await _renderGraphic();
    if (path == null || !mounted) {
      if (mounted) setState(() => _sending = false);
      return;
    }
    final message = whatsappMessage(_b, _items, widget.settings.value);
    await widget.services.share.share(imagePath: path, text: message.body);
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    return Scaffold(
      appBar: AppBar(
        title: Text(_b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Check again',
            icon: const Icon(Icons.refresh),
            onPressed: _checking ? null : _check,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoCard(business: _b, onOpen: _openUrl),
              const SizedBox(height: 20),
              _SectionTitle(
                'Audit',
                trailing: _checking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Tap a row to change it', style: TextStyle(color: Brand.muted, fontSize: 12)),
              ),
              Card(
                child: Column(
                  children: [
                    for (final item in _items)
                      _AuditTile(item: item, onTap: () => _editRow(item)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Graphic'),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: AuditGraphic.width / AuditGraphic.height,
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _graphicKey,
                      child: AuditGraphic(
                        clientName: _b.name,
                        items: _items,
                        settings: widget.settings.value,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Send'),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'WhatsApp number (with country code)',
                  helperText: digits.isNotEmpty && !looksLikeMobile(digits)
                      ? 'Looks like a landline. It may not have WhatsApp.'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Email',
                  helperText: _site != null && _site!.emails.isNotEmpty
                      ? 'Found on their website'
                      : 'Google Maps does not list emails. Add one if you have it.',
                ),
              ),
              const SizedBox(height: 16),
              if (_sending) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _sending ? null : _sendWhatsApp,
                icon: const Icon(Icons.chat),
                label: Text(_lead?.whatsappSentAt != null ? 'Send on WhatsApp again' : 'Send on WhatsApp'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _sending ? null : _sendEmail,
                icon: const Icon(Icons.mail_outline),
                label: Text(_lead?.emailSentAt != null ? 'Send by email again' : 'Send by email'),
              ),
              TextButton.icon(
                onPressed: _sending ? null : _shareElsewhere,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share to Messenger or elsewhere'),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Preview message', style: TextStyle(fontWeight: FontWeight.w600)),
                children: [
                  SelectableText(
                    whatsappMessage(_b, _items, widget.settings.value).body,
                    style: const TextStyle(color: Brand.ink, height: 1.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.business, required this.onOpen});
  final Business business;
  final Future<void> Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final lines = [
      if (b.category.isNotEmpty) b.category,
      if (b.rating != null) '${b.rating!.toStringAsFixed(1)}★ from ${b.reviewCount} reviews',
      if (b.address.isNotEmpty) b.address,
      if (b.phone.isNotEmpty) b.phone,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l, style: const TextStyle(color: Brand.ink)),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (b.mapsUrl.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Google Maps'),
                    onPressed: () => onOpen(b.mapsUrl),
                  ),
                if (b.hasWebsite)
                  ActionChip(
                    avatar: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Website'),
                    onPressed: () => onOpen(b.website),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.item, required this.onTap});
  final AuditItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(areaIcon(item.area), size: 22, color: Brand.navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.area.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(item.detail, style: const TextStyle(color: Brand.muted, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(status: item.status, text: item.verdict),
          ],
        ),
      ),
    );
  }
}
