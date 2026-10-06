import 'package:flutter/material.dart';

import '../logic/lead_filter.dart';
import '../models/lead.dart';
import '../services/settings_controller.dart';
import '../theme.dart';
import 'dashboard_screen.dart' show formatDay;
import 'home_shell.dart';

/// A filter the Leads tab opens with (e.g. from a dashboard tile).
typedef LeadsPreset = LeadFilter;

/// Every business the user has opened, with search, filters and export.
class LeadsScreen extends StatefulWidget {
  const LeadsScreen({
    super.key,
    required this.settings,
    required this.services,
    this.preset,
    this.onPresetUsed,
  });

  final SettingsController settings;
  final AppServices services;
  final LeadsPreset? preset;
  final VoidCallback? onPresetUsed;

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _search = TextEditingController();
  List<Lead>? _leads;
  LeadFilter _filter = const LeadFilter();

  @override
  void initState() {
    super.initState();
    widget.services.leads.addListener(_reload);
    _applyPreset();
    _reload();
  }

  @override
  void didUpdateWidget(LeadsScreen old) {
    super.didUpdateWidget(old);
    _applyPreset();
  }

  void _applyPreset() {
    final p = widget.preset;
    if (p == null) return;
    _filter = p;
    _search.text = p.query;
    widget.onPresetUsed?.call();
  }

  @override
  void dispose() {
    widget.services.leads.removeListener(_reload);
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final leads = await widget.services.leads.all();
    if (mounted) setState(() => _leads = leads);
  }

  Future<void> _open(Lead lead) => openLead(
        context,
        business: lead.business,
        settings: widget.settings,
        services: widget.services,
      );

  Future<void> _remove(Lead lead) async {
    setState(() => _leads = [...?_leads]..remove(lead));
    await widget.services.leads.remove(lead.business.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Removed ${lead.business.name}'),
        action: SnackBarAction(label: 'Undo', onPressed: () => widget.services.leads.save(lead)),
      ));
  }

  Future<void> _export(List<Lead> leads) async {
    if (leads.isEmpty) return;
    final now = DateTime.now();
    final name = 'fc_leads_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
    final path = await widget.services.renderer.writeExport(name, leadsToCsv(leads));
    await widget.services.share.shareFile(path: path, mimeType: 'text/csv', subject: 'FC Leads export');
  }

  void _toggleStatus(LeadStatus s) {
    final next = {..._filter.statuses};
    if (!next.remove(s)) next.add(s);
    setState(() => _filter = _filter.copyWith(statuses: next));
  }

  Future<void> _openFilters() async {
    final countries = {for (final l in _leads ?? const <Lead>[]) l.countryCode}..remove('');
    final cats = {for (final l in _leads ?? const <Lead>[]) l.category}..remove('');
    final result = await showModalBottomSheet<LeadFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        filter: _filter,
        countries: countries.toList()..sort(),
        categories: cats.toList()..sort(),
      ),
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final all = _leads;
    final shown = all == null ? const <Lead>[] : _filter.apply(all);
    final sheet = _filter.sheetCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads'),
        actions: [
          PopupMenuButton<LeadSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _filter.sort,
            onSelected: (v) => setState(() => _filter = _filter.copyWith(sort: v)),
            itemBuilder: (_) => [for (final s in LeadSort.values) PopupMenuItem(value: s, child: Text(s.label))],
          ),
          IconButton(
            tooltip: 'Export as CSV',
            icon: const Icon(Icons.ios_share),
            onPressed: shown.isEmpty ? null : () => _export(shown),
          ),
        ],
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (v) => setState(() => _filter = _filter.copyWith(query: v)),
                          decoration: const InputDecoration(
                            hintText: 'Search name, area, notes',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: sheet > 0,
                        label: Text('$sheet'),
                        child: IconButton.filledTonal(
                          tooltip: 'Filters',
                          onPressed: _openFilters,
                          icon: const Icon(Icons.filter_list),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final s in LeadStatus.values) ...[
                        FilterChip(
                          avatar: CircleAvatar(backgroundColor: statusColor(s), radius: 5),
                          label: Text('${s.label} ${all.where((l) => l.status == s).length}'),
                          selected: _filter.statuses.contains(s),
                          onSelected: (_) => _toggleStatus(s),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${shown.length} of ${all.length} leads',
                          style: const TextStyle(color: Brand.muted),
                        ),
                      ),
                      if (sheet > 0 || _filter.statuses.isNotEmpty || _filter.query.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() {
                            _search.clear();
                            _filter = LeadFilter(sort: _filter.sort);
                          }),
                          child: const Text('Clear filters'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: all.isEmpty
                      ? const _Empty(text: 'Businesses you open from Search are saved here.')
                      : shown.isEmpty
                          ? const _Empty(text: 'No leads match these filters.')
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: shown.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final lead = shown[i];
                                return Dismissible(
                                  key: ValueKey(lead.business.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6D2C9),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(Icons.delete_outline, color: Color(0xFF8A2412)),
                                  ),
                                  onDismissed: (_) => _remove(lead),
                                  child: _LeadTile(lead: lead, onTap: () => _open(lead)),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted)),
        ),
      );
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({required this.lead, required this.onTap});
  final Lead lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final issues = leadIssues(lead);
    final sent = [
      if (lead.whatsappSentAt != null) 'WhatsApp ${formatDay(lead.whatsappSentAt!)}',
      if (lead.emailSentAt != null) 'Email ${formatDay(lead.emailSentAt!)}',
    ];
    final where = [lead.category, lead.city].where((s) => s.isNotEmpty).join(' · ');
    final due = lead.followUpDue(DateTime.now());

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lead.business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: lead.status),
                ],
              ),
              if (where.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.ink)),
              ],
              const SizedBox(height: 4),
              Text(
                sent.isEmpty ? 'Not contacted yet' : 'Sent: ${sent.join(' · ')}',
                style: TextStyle(color: sent.isEmpty ? Brand.muted : const Color(0xFF1D5230), fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    issues == 0 ? 'All good' : '$issues to fix',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.ink, fontSize: 13),
                  ),
                  if (!leadHasWebsite(lead))
                    const Text('No website', style: TextStyle(color: Color(0xFF8A2412), fontSize: 13, fontWeight: FontWeight.w600)),
                  if (lead.followUp != null)
                    Text(
                      'Follow up ${formatDay(lead.followUp!)}',
                      style: TextStyle(
                        color: due ? const Color(0xFF7A4300) : Brand.muted,
                        fontWeight: due ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 13,
                      ),
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

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final LeadStatus status;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(0x26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withAlpha(0x80)),
      ),
      child: Text(status.label, style: const TextStyle(color: Brand.navy, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filter, required this.countries, required this.categories});
  final LeadFilter filter;
  final List<String> countries;
  final List<String> categories;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late LeadFilter _f = widget.filter;

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Filters', style: TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 20)),
            _label('Contact'),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final c in ContactFilter.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _f.contact == c,
                    onSelected: (_) => setState(() => _f = _f.copyWith(contact: c)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('No website only'),
              value: _f.noWebsiteOnly,
              onChanged: (v) => setState(() => _f = _f.copyWith(noWebsiteOnly: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Follow-up due'),
              value: _f.followUpDue,
              onChanged: (v) => setState(() => _f = _f.copyWith(followUpDue: v)),
            ),
            if (widget.categories.isNotEmpty) ...[
              _label('Business type'),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _f.category.isEmpty,
                    onSelected: (_) => setState(() => _f = _f.copyWith(category: '')),
                  ),
                  for (final c in widget.categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: _f.category == c,
                      onSelected: (_) => setState(() => _f = _f.copyWith(category: c)),
                    ),
                ],
              ),
            ],
            if (widget.countries.isNotEmpty) ...[
              _label('Country'),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _f.countryCode.isEmpty,
                    onSelected: (_) => setState(() => _f = _f.copyWith(countryCode: '')),
                  ),
                  for (final c in widget.countries)
                    ChoiceChip(
                      label: Text(c),
                      selected: _f.countryCode == c,
                      onSelected: (_) => setState(() => _f = _f.copyWith(countryCode: c)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_f.clearSheet()),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_f),
                    child: const Text('Show leads'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
