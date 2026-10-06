import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/categories.dart';
import '../logic/audit_builder.dart';
import '../logic/html_analyzer.dart';
import '../logic/messages.dart';
import '../logic/phone.dart';
import '../models/audit.dart';
import '../models/business.dart';
import '../models/lead.dart';
import '../services/settings_controller.dart';
import '../services/share_service.dart';
import '../theme.dart';
import '../widgets/audit_graphic.dart';
import '../widgets/compose_sheets.dart';
import '../widgets/status_pill.dart';
import 'dashboard_screen.dart' show formatDay;
import 'home_shell.dart';

/// One business: what was found, the pipeline, the personalised graphic,
/// and the buttons that hand it to WhatsApp or email.
class LeadScreen extends StatefulWidget {
  const LeadScreen({
    super.key,
    required this.business,
    required this.settings,
    required this.services,
    this.seed,
  });

  final Business business;
  final SettingsController settings;
  final AppServices services;

  /// Where it was found (category, country, city) when opened from Search.
  final Lead? seed;

  @override
  State<LeadScreen> createState() => _LeadScreenState();
}

class _LeadScreenState extends State<LeadScreen> {
  final _graphicKey = GlobalKey();
  final _notes = TextEditingController();

  late Lead _lead;
  String _phone = '';
  bool _loaded = false;
  bool _checking = false;
  bool _busy = false;

  Business get _b => widget.business;
  bool get _hasRealWebsite => _b.hasWebsite && socialPlatformOf(_b.website) == null;
  ShareService get _share => widget.services.share;

  @override
  void initState() {
    super.initState();
    final seed = widget.seed;
    _lead = Lead(
      business: _b,
      items: buildAudit(_b, null),
      savedAt: DateTime.now(),
      category: seed?.category ?? '',
      countryCode: seed?.countryCode ?? '',
      city: seed?.city ?? '',
    );
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await widget.services.leads.find(_b.id);
    final seed = widget.seed;
    var lead = saved ?? _lead;
    if (saved != null && seed != null) {
      lead = lead.copyWith(
        category: lead.category.isEmpty ? seed.category : null,
        countryCode: lead.countryCode.isEmpty ? seed.countryCode : null,
        city: lead.city.isEmpty ? seed.city : null,
      );
    }
    final countryCode = lead.countryCode.isNotEmpty ? lead.countryCode : widget.settings.value.defaultCountry;
    final country = await widget.services.geo.country(countryCode);
    if (!mounted) return;
    setState(() {
      _lead = lead;
      _notes.text = lead.notes;
      _phone = whatsappNumber(
        international: _b.internationalPhone,
        national: _b.phone,
        defaultCountryCode: (country?.dialCode.isNotEmpty ?? false) ? country!.dialCode : '880',
      );
      _loaded = true;
    });
    if (saved == null) await _check();
  }

  /// Opens the website (if any), rebuilds the audit and saves the lead.
  Future<void> _check() async {
    var lead = _lead;
    final links = {...lead.socialLinks};
    final linked = _b.hasWebsite ? socialPlatformOf(_b.website) : null;
    if (linked != null) links.putIfAbsent(linked, () => _b.website);

    if (_hasRealWebsite) {
      setState(() => _checking = true);
      final report = await widget.services.checker.check(_b.website);
      if (!mounted) return;
      for (final e in report.socialLinks.entries) {
        links.putIfAbsent(e.key, () => e.value);
      }
      lead = lead.copyWith(
        website: report,
        email: lead.email.isEmpty && report.emails.isNotEmpty ? report.emails.first : null,
      );
    }
    final items = buildAudit(_b, lead.website);
    setState(() {
      _checking = false;
      _lead = lead.copyWith(items: items, socialLinks: links);
    });
    await _save();
  }

  Future<void> _save() => widget.services.leads.save(_lead);

  void _update(Lead next) {
    setState(() => _lead = next);
    _save();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---- Audit rows ----

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
    _update(_lead.copyWith(items: [
      for (final i in _lead.items)
        i.area == item.area ? i.copyWith(status: choice.$1, verdict: choice.$2) : i,
    ]));
  }

  // ---- Links ----

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') || url.startsWith('tel:') ? url : 'https://$url');
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _toast('Could not open $url');
  }

  void _findOn(String platform, String domain) {
    final q = [_b.name, _lead.city, 'site:$domain'].where((s) => s.isNotEmpty).join(' ');
    _openUrl(Uri.https('www.google.com', '/search', {'q': q}).toString());
  }

  Future<void> _addLink() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _AddLinkDialog(),
    );
    if (result == null || result.$2.trim().isEmpty) return;
    final url = result.$2.trim();
    final platform = result.$1.isEmpty ? (socialPlatformOf(url) ?? 'Link') : result.$1;
    _update(_lead.copyWith(socialLinks: {..._lead.socialLinks, platform: url}));
  }

  void _removeLink(String platform) {
    final links = {..._lead.socialLinks}..remove(platform);
    _update(_lead.copyWith(socialLinks: links));
  }

  // ---- Pipeline ----

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lead.followUp ?? now.add(const Duration(days: 3)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Follow up on',
    );
    if (picked != null) _update(_lead.copyWith(followUp: picked));
  }

  // ---- Sending ----

  Future<String?> _renderGraphic() async {
    try {
      return await widget.services.renderer.renderToFile(_graphicKey, _b.name);
    } catch (e) {
      _toast('Could not create the graphic: $e');
      return null;
    }
  }

  bool _report(ShareResult r, String app) {
    switch (r) {
      case ShareResult.opened:
        return true;
      case ShareResult.notInstalled:
        _toast('$app is not installed on this phone.');
      case ShareResult.failed:
        _toast('Could not open $app${_share.lastError.isEmpty ? '' : ': ${_share.lastError}'}');
    }
    return false;
  }

  void _markSent({bool whatsapp = false, bool email = false}) {
    final now = DateTime.now();
    _update(_lead.copyWith(
      whatsappSentAt: whatsapp ? now : null,
      emailSentAt: email ? now : null,
      status: _lead.status == LeadStatus.newLead ? LeadStatus.contacted : null,
    ));
  }

  String _city() => _lead.city;

  OutreachMessage _waTemplate() =>
      whatsappMessage(_b, _lead.items, widget.settings.value, city: _city(), category: _lead.category);

  OutreachMessage _emailTemplate() =>
      emailMessage(_b, _lead.items, widget.settings.value, city: _city(), category: _lead.category);

  Future<void> _openWhatsApp() async {
    final template = _waTemplate().body;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WhatsAppSheet(
        phone: _phone,
        text: _lead.whatsappText ?? template,
        templateText: template,
        onChanged: (phone, text) {
          _phone = phone;
          _lead = _lead.copyWith(whatsappText: text == template ? null : text);
          _save();
        },
        onOpenChat: (phone, text) async {
          final ok = _report(await _share.whatsappChat(phone: phone, text: text), 'WhatsApp');
          if (ok) _markSent(whatsapp: true);
          return ok;
        },
        onSendGraphic: (phone, caption) async {
          final path = await _renderGraphic();
          if (path == null) return false;
          final ok = _report(await _share.whatsappImage(imagePath: path, phone: phone, caption: caption), 'WhatsApp');
          if (ok) _markSent(whatsapp: true);
          return ok;
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openEmail() async {
    final template = _emailTemplate();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EmailSheet(
        to: _lead.email,
        subject: _lead.emailSubject ?? template.subject,
        body: _lead.emailBody ?? template.body,
        templateSubject: template.subject,
        templateBody: template.body,
        onChanged: (to, subject, body) {
          _lead = _lead.copyWith(
            email: to,
            emailSubject: subject == template.subject ? null : subject,
            emailBody: body == template.body ? null : body,
          );
          _save();
        },
        onSend: (to, subject, body) async {
          final path = await _renderGraphic();
          if (path == null) return false;
          final ok = _report(
            await _share.email(imagePath: path, to: to, subject: subject, body: body),
            'an email app',
          );
          if (ok) _markSent(email: true);
          return ok;
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _shareGraphic() async {
    setState(() => _busy = true);
    final path = await _renderGraphic();
    if (path != null) {
      _report(await _share.shareFile(path: path, text: _lead.whatsappText ?? _waTemplate().body), 'the share menu');
    }
    if (mounted) setState(() => _busy = false);
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Check again',
            icon: const Icon(Icons.refresh),
            onPressed: _checking || !_loaded ? null : _check,
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
              _InfoCard(lead: _lead, onOpen: _openUrl),
              const SizedBox(height: 20),
              _SectionTitle('Social media', trailing: TextButton.icon(
                onPressed: _addLink,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add link'),
              )),
              _SocialCard(
                links: _lead.socialLinks,
                checking: _checking,
                onOpen: _openUrl,
                onRemove: _removeLink,
                onFind: _findOn,
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Status'),
              _PipelineCard(
                lead: _lead,
                notes: _notes,
                onStatus: (s) => _update(_lead.copyWith(status: s)),
                onPickFollowUp: _pickFollowUp,
                onClearFollowUp: () => _update(_lead.copyWith(clearFollowUp: true)),
                onNotes: (t) {
                  _lead = _lead.copyWith(notes: t);
                  _save();
                },
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                'Audit',
                trailing: _checking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Tap a row to change it', style: TextStyle(color: Brand.muted, fontSize: 12)),
              ),
              Card(
                child: Column(
                  children: [for (final item in _lead.items) _AuditTile(item: item, onTap: () => _editRow(item))],
                ),
              ),
              const SizedBox(height: 14),
              _ServicesRow(
                items: _lead.items,
                category: categoryByLabel(_lead.category),
              ),
              const SizedBox(height: 20),
              _SectionTitle('Graphic', trailing: TextButton.icon(
                onPressed: _busy ? null : _shareGraphic,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              )),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: AuditGraphic.width / AuditGraphic.height,
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _graphicKey,
                      child: AuditGraphic(
                        clientName: _b.name,
                        items: _lead.items,
                        settings: widget.settings.value,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Send'),
              _SentLine(lead: _lead),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _loaded ? _openWhatsApp : null,
                icon: const Icon(Icons.chat),
                label: const Text('Send on WhatsApp'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loaded ? _openEmail : null,
                icon: const Icon(Icons.mail_outline),
                label: const Text('Send by email'),
              ),
              if (_lead.email.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'No email found on their website. You can type one when sending.',
                    style: TextStyle(color: Brand.muted, fontSize: 12),
                  ),
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
            child: Text(text, style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 20)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.lead, required this.onOpen});
  final Lead lead;
  final Future<void> Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final b = lead.business;
    final phone = b.internationalPhone.isNotEmpty ? b.internationalPhone : b.phone;
    final lines = [
      [if (b.category.isNotEmpty) b.category, if (lead.category.isNotEmpty && lead.category != b.category) lead.category].join(' · '),
      if (b.rating != null) '${b.rating!.toStringAsFixed(1)}★ from ${b.reviewCount} reviews',
      if (b.address.isNotEmpty) b.address,
      if (phone.isNotEmpty) phone,
    ].where((l) => l.isNotEmpty);
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
                if (phone.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Call'),
                    onPressed: () => onOpen('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}'),
                  ),
                if (b.mapsUrl.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Google Maps'),
                    onPressed: () => onOpen(b.mapsUrl),
                  ),
                if (b.hasWebsite && socialPlatformOf(b.website) == null)
                  ActionChip(
                    avatar: const Icon(Icons.language, size: 18),
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

IconData socialIcon(String platform) => switch (platform) {
      'Facebook' => Icons.facebook,
      'Instagram' => Icons.camera_alt_outlined,
      'TikTok' => Icons.music_note_outlined,
      'YouTube' => Icons.smart_display_outlined,
      'LinkedIn' => Icons.work_outline,
      'X' => Icons.alternate_email,
      'WhatsApp' => Icons.chat_outlined,
      _ => Icons.link,
    };

class _SocialCard extends StatelessWidget {
  const _SocialCard({
    required this.links,
    required this.checking,
    required this.onOpen,
    required this.onRemove,
    required this.onFind,
  });

  final Map<String, String> links;
  final bool checking;
  final Future<void> Function(String url) onOpen;
  final void Function(String platform) onRemove;
  final void Function(String platform, String domain) onFind;

  static const _find = {
    'Facebook': 'facebook.com',
    'Instagram': 'instagram.com',
    'TikTok': 'tiktok.com',
    'YouTube': 'youtube.com',
    'LinkedIn': 'linkedin.com',
  };

  @override
  Widget build(BuildContext context) {
    final missing = _find.keys.where((p) => !links.containsKey(p)).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (links.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text(
                  checking ? 'Looking for links on their website…' : 'No social links found yet.',
                  style: const TextStyle(color: Brand.muted),
                ),
              ),
            for (final e in links.entries)
              ListTile(
                dense: true,
                leading: Icon(socialIcon(e.key), color: Brand.navy),
                title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => onOpen(e.value),
                trailing: IconButton(
                  tooltip: 'Remove ${e.key} link',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onRemove(e.key),
                ),
              ),
            if (missing.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Text('Find them on Google:', style: TextStyle(color: Brand.muted, fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final p in missing)
                      ActionChip(
                        avatar: Icon(socialIcon(p), size: 16),
                        label: Text(p),
                        onPressed: () => onFind(p, _find[p]!),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _url = TextEditingController();
  String _platform = '';

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Profile link', hintText: 'facebook.com/business'),
            onChanged: (v) => setState(() => _platform = socialPlatformOf(v) ?? ''),
          ),
          const SizedBox(height: 8),
          Text(
            _platform.isEmpty ? 'Paste a Facebook, Instagram, TikTok, YouTube or LinkedIn link.' : 'Recognised: $_platform',
            style: const TextStyle(color: Brand.muted, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.of(context).pop((_platform, _url.text)),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({
    required this.lead,
    required this.notes,
    required this.onStatus,
    required this.onPickFollowUp,
    required this.onClearFollowUp,
    required this.onNotes,
  });

  final Lead lead;
  final TextEditingController notes;
  final void Function(LeadStatus) onStatus;
  final VoidCallback onPickFollowUp;
  final VoidCallback onClearFollowUp;
  final void Function(String) onNotes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final s in LeadStatus.values)
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: statusColor(s), radius: 5),
                    label: Text(s.label),
                    selected: lead.status == s,
                    onSelected: (_) => onStatus(s),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined, color: Brand.navy),
              title: Text(lead.followUp == null ? 'Set a follow-up date' : 'Follow up on ${formatDay(lead.followUp!)}'),
              subtitle: lead.followUpDue(DateTime.now())
                  ? const Text('Due now', style: TextStyle(color: Color(0xFF7A4300), fontWeight: FontWeight.w700))
                  : null,
              onTap: onPickFollowUp,
              trailing: lead.followUp == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(tooltip: 'Clear follow-up', icon: const Icon(Icons.close), onPressed: onClearFollowUp),
            ),
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 6,
              onChanged: onNotes,
              decoration: const InputDecoration(labelText: 'Notes', hintText: 'Owner name, what they said, prices…', alignLabelWithHint: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicesRow extends StatelessWidget {
  const _ServicesRow({required this.items, required this.category});
  final List<AuditItem> items;
  final BusinessCategory? category;

  @override
  Widget build(BuildContext context) {
    final services = recommendedServices(items, category: category);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pitch these services', style: TextStyle(color: Brand.mist, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final s in services)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Brand.gold, borderRadius: BorderRadius.circular(999)),
                  child: Text(s.label, style: const TextStyle(color: Brand.navy, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentLine extends StatelessWidget {
  const _SentLine({required this.lead});
  final Lead lead;

  @override
  Widget build(BuildContext context) {
    final parts = [
      'WhatsApp: ${lead.whatsappSentAt == null ? 'not sent' : 'sent ${formatDay(lead.whatsappSentAt!)}'}',
      'Email: ${lead.emailSentAt == null ? 'not sent' : 'sent ${formatDay(lead.emailSentAt!)}'}',
    ];
    return Text(parts.join('   ·   '), style: const TextStyle(color: Brand.muted));
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
