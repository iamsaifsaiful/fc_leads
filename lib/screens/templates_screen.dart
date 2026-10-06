import 'package:flutter/material.dart';

import '../logic/audit_builder.dart';
import '../logic/messages.dart';
import '../logic/templates.dart';
import '../models/business.dart';
import '../services/settings_controller.dart';
import '../theme.dart';

/// Edit the WhatsApp and email messages every lead starts from.
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key, required this.settings});
  final SettingsController settings;

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _wa = TextEditingController();
  final _subject = TextEditingController();
  final _email = TextEditingController();
  TextEditingController? _focused;
  bool _filled = false;
  bool _dirty = false;

  static const _sample = Business(
    id: 'sample',
    name: 'Rahim Tea House',
    rating: 4.4,
    reviewCount: 12,
  );

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_fill);
    _fill();
  }

  void _fill() {
    if (_filled || !widget.settings.loaded) return;
    final s = widget.settings.value;
    _wa.text = s.whatsappTemplate;
    _subject.text = s.emailSubjectTemplate;
    _email.text = s.emailTemplate;
    _filled = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.settings.removeListener(_fill);
    _wa.dispose();
    _subject.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    await widget.settings.update(widget.settings.value.copyWith(
      whatsappTemplate: _wa.text,
      emailSubjectTemplate: _subject.text,
      emailTemplate: _email.text,
    ));
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Templates saved')));
  }

  void _reset() {
    setState(() {
      _wa.text = defaultWhatsappTemplate;
      _subject.text = defaultEmailSubjectTemplate;
      _email.text = defaultEmailTemplate;
      _dirty = true;
    });
  }

  void _insert(String key) {
    final c = _focused ?? _wa;
    final sel = c.selection;
    final text = c.text;
    final at = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final token = '{$key}';
    c.value = TextEditingValue(
      text: text.replaceRange(at, end, token),
      selection: TextSelection.collapsed(offset: at + token.length),
    );
    setState(() => _dirty = true);
  }

  Widget _field(TextEditingController c, String label, {int minLines = 1, int maxLines = 1}) {
    return Focus(
      onFocusChange: (f) {
        if (f) _focused = c;
      },
      child: TextField(
        controller: c,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: (_) => setState(() => _dirty = true),
        decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      ),
    );
  }

  void _preview() {
    final s = widget.settings.value.copyWith(
      whatsappTemplate: _wa.text,
      emailSubjectTemplate: _subject.text,
      emailTemplate: _email.text,
    );
    final items = buildAudit(_sample, null);
    final wa = whatsappMessage(_sample, items, s, city: 'Dhaka', category: 'Cafes & coffee shops');
    final em = emailMessage(_sample, items, s, city: 'Dhaka', category: 'Cafes & coffee shops');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Text('Preview for a sample café', style: TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 12),
            const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _Bubble(text: wa.body),
            const SizedBox(height: 16),
            const Text('Email', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _Bubble(text: 'Subject: ${em.subject}\n\n${em.body}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message templates'),
        actions: [
          IconButton(tooltip: 'Preview', icon: const Icon(Icons.visibility_outlined), onPressed: _preview),
          PopupMenuButton<String>(
            onSelected: (_) => _reset(),
            itemBuilder: (_) => const [PopupMenuItem(value: 'reset', child: Text('Reset to defaults'))],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Text(
            'Every lead starts from these. Words in {braces} are filled in for each business. '
            'You can still change the text for one lead before sending.',
            style: TextStyle(color: Brand.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Text('Tap to insert into the box you are editing:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in placeholders.entries)
                Tooltip(
                  message: e.value,
                  child: ActionChip(label: Text('{${e.key}}'), onPressed: () => _insert(e.key)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _field(_wa, 'WhatsApp message', minLines: 6, maxLines: 16),
          const SizedBox(height: 14),
          _field(_subject, 'Email subject'),
          const SizedBox(height: 14),
          _field(_email, 'Email message', minLines: 8, maxLines: 20),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _preview,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _dirty ? _save : null, child: const Text('Save')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Brand.white, borderRadius: BorderRadius.circular(14)),
        child: SelectableText(text, style: const TextStyle(height: 1.4, color: Brand.ink)),
      );
}
