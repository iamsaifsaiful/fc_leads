import 'package:flutter/material.dart';

import '../logic/lead_filter.dart';
import '../models/lead.dart';
import '../services/settings_controller.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'leads_screen.dart';

/// Home: how outreach is going and what to do next.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.settings,
    required this.services,
    required this.onSearch,
    required this.onLeads,
    required this.onSettings,
  });

  final SettingsController settings;
  final AppServices services;
  final VoidCallback onSearch;
  final void Function(LeadsPreset preset) onLeads;
  final VoidCallback onSettings;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Lead> _leads = const [];

  @override
  void initState() {
    super.initState();
    widget.services.leads.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.services.leads.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final leads = await widget.services.leads.all();
    if (mounted) setState(() => _leads = leads);
  }

  @override
  Widget build(BuildContext context) {
    final stats = LeadStats(_leads);
    final now = DateTime.now();
    final due = _leads.where((l) => l.followUpDue(now)).toList()
      ..sort((a, b) => a.followUp!.compareTo(b.followUp!));

    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) {
            final name = widget.settings.value.senderName.trim();
            return Text(name.isEmpty ? 'FC Leads' : 'Hi, ${name.split(' ').first}');
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) => widget.settings.loaded && !widget.settings.value.hasApiKey
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SetupCard(onSettings: widget.onSettings),
                  )
                : const SizedBox.shrink(),
          ),
          _HeroCard(onSearch: widget.onSearch),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              _StatTile(
                label: 'Leads saved',
                value: stats.total,
                onTap: () => widget.onLeads(const LeadFilter()),
              ),
              _StatTile(
                label: 'Contacted',
                value: stats.contacted,
                onTap: () => widget.onLeads(const LeadFilter(contact: ContactFilter.sent)),
              ),
              _StatTile(
                label: 'Not contacted yet',
                value: stats.total - stats.contacted,
                onTap: () => widget.onLeads(const LeadFilter(contact: ContactFilter.notContacted)),
              ),
              _StatTile(
                label: 'Follow-ups due',
                value: stats.followUpsDue,
                highlight: stats.followUpsDue > 0,
                onTap: () => widget.onLeads(const LeadFilter(followUpDue: true, sort: LeadSort.followUp)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _Title('Pipeline'),
          Card(
            child: Column(
              children: [
                for (final s in LeadStatus.values)
                  ListTile(
                    dense: true,
                    leading: _StatusDot(status: s),
                    title: Text(s.label),
                    trailing: Text(
                      '${stats.byStatus[s] ?? 0}',
                      style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    onTap: () => widget.onLeads(LeadFilter(statuses: {s})),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _Title('Follow up today'),
          if (due.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No follow-ups due. Set a follow-up date on a lead to see it here.',
                  style: TextStyle(color: Brand.muted),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final l in due.take(5))
                    ListTile(
                      title: Text(l.business.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${l.status.label} · due ${formatDay(l.followUp!)}',
                        style: const TextStyle(color: Brand.muted),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openLead(
                        context,
                        business: l.business,
                        settings: widget.settings,
                        services: widget.services,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const _Title('How it works'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Step(n: 1, text: 'Search: pick a business type, country and city.'),
                  _Step(n: 2, text: 'Open a business. The app checks its Maps profile, website, social media and SEO.'),
                  _Step(n: 3, text: 'Check the audit and graphic. Tap any row to correct it.'),
                  _Step(n: 4, text: 'Send on WhatsApp or by email, then set a status and follow-up date.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatDay(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 20)),
      );
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFBE4C2), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Add your Google Places API key and agency details in Settings to start.',
              style: TextStyle(color: Color(0xFF7A4300), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onSettings, child: const Text('Set up')),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find your next client',
            style: TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 24, color: Brand.cream),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search any city in the world for businesses that need a website, design, reels or SEO.',
            style: TextStyle(color: Brand.mist, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Brand.gold, foregroundColor: Brand.navy),
            onPressed: onSearch,
            icon: const Icon(Icons.travel_explore),
            label: const Text('Start a search'),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.onTap, this.highlight = false});
  final String label;
  final int value;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? const Color(0xFFFBE4C2) : Brand.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$value', style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 26)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final LeadStatus status;

  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: statusColor(status), shape: BoxShape.circle),
      );
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Brand.gold, shape: BoxShape.circle),
              child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.navy, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
          ],
        ),
      );
}
