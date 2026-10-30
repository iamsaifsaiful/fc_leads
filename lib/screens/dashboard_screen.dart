import 'package:flutter/material.dart';

import '../logic/billing.dart';
import '../logic/lead_filter.dart';
import '../models/client.dart';
import '../models/lead.dart';
import '../services/settings_controller.dart';
import '../services/sync.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'leads_screen.dart';

const _ink = Color(0xFF0B1220);
const _muted = Color(0xFF5B6472);

/// Home: today's target, what to follow up, and how outreach is going.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.settings,
    required this.services,
    required this.onSearch,
    required this.onLeads,
    required this.onClients,
    required this.onSettings,
  });

  final SettingsController settings;
  final AppServices services;
  final VoidCallback onSearch;
  final void Function(LeadsPreset preset) onLeads;
  final VoidCallback onClients;
  final VoidCallback onSettings;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Lead> _leads = const [];
  List<Client> _clients = const [];
  TodayWork _today = const TodayWork();

  @override
  void initState() {
    super.initState();
    widget.services.leads.addListener(_reload);
    widget.services.clients.addListener(_reload);
    widget.services.sync.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.services.leads.removeListener(_reload);
    widget.services.clients.removeListener(_reload);
    widget.services.sync.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final leads = await widget.services.leads.all();
    final clients = await widget.services.clients.all();
    final today = await widget.services.sync.today();
    if (mounted) {
      setState(() {
        _leads = leads;
        _clients = clients;
        _today = today;
      });
    }
  }

  /// Pull to refresh: send waiting work, fetch leads and settings, re-read.
  Future<void> _refresh() async {
    final s = widget.services;
    await s.sync.flush();
    try {
      await s.sync.pullLeads();
    } catch (_) {}
    await s.session.refresh();
    await s.leads.reload();
    await s.clients.reload();
    await _reload();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final stats = LeadStats(_leads);
    final now = DateTime.now();
    final due = _leads.where((l) => l.followUpDue(now)).toList()
      ..sort((a, b) => a.followUp!.compareTo(b.followUp!));
    final money = ClientStats(_clients, now: now);
    final session = widget.services.session;
    final user = session.user;
    final target = session.config.dailyTarget <= 0 ? 20 : session.config.dailyTarget;
    final progress = (_today.leads / target).clamp(0.0, 1.0);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Brand.navy, shape: BoxShape.circle),
                    child: Text(user?.initials ?? '', style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(), style: const TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w500)),
                        Text(user?.firstName ?? 'FC Leads', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                      ],
                    ),
                  ),
                  if (widget.services.sync.pending > 0)
                    Tooltip(
                      message: '${widget.services.sync.pending} changes waiting to sync',
                      child: const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.cloud_upload_outlined, color: _muted),
                      ),
                    ),
                  if (user != null && user.isAdmin)
                    IconButton.filledTonal(
                      tooltip: 'Back to admin',
                      onPressed: () => session.setAdminView(true),
                      icon: const Icon(Icons.bar_chart),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (!session.config.searchReady) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFFBE4C2), borderRadius: BorderRadius.circular(16)),
                  child: const Text(
                    'Search is not set up on the website yet. Ask your admin to add the Google key.',
                    style: TextStyle(color: Color(0xFF7A4300), fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(22)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text("Today's target", style: TextStyle(color: Brand.mist, fontWeight: FontWeight.w600, fontSize: 13))),
                        Text('${(progress * 100).round()}%', style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${_today.leads}', style: const TextStyle(color: Brand.white, fontSize: 38, fontWeight: FontWeight.w800, height: 1)),
                        const SizedBox(width: 6),
                        Text('/ $target leads checked', style: const TextStyle(color: Brand.mist, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withAlpha(30),
                        color: Brand.gold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _MiniStat(value: _today.leads, label: 'Checked'),
                        const SizedBox(width: 8),
                        _MiniStat(value: _today.sent, label: 'Messaged'),
                        const SizedBox(width: 8),
                        _MiniStat(value: _today.replies, label: 'Replies'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      color: Brand.gold,
                      icon: Icons.search,
                      label: 'New search',
                      onTap: widget.onSearch,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionTile(
                      color: Brand.white,
                      icon: Icons.event_outlined,
                      label: 'Follow-ups',
                      badge: stats.followUpsDue,
                      onTap: () => widget.onLeads(const LeadFilter(followUpDue: true, sort: LeadSort.followUp)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Text('Follow up today', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  if (due.length > 3)
                    TextButton(
                      onPressed: () => widget.onLeads(const LeadFilter(followUpDue: true, sort: LeadSort.followUp)),
                      child: const Text('See all'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (due.isEmpty)
                const _Empty('Nothing due. Set a follow-up date on a lead and it shows here on the day.')
              else
                for (final l in due.take(3)) ...[
                  _FollowUpTile(
                    lead: l,
                    onTap: () => openLead(context, business: l.business, settings: widget.settings, services: widget.services),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 12),
              const Text('Pipeline', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final s in LeadStatus.values)
                        InkWell(
                          onTap: () => widget.onLeads(LeadFilter(statuses: {s})),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor(s), shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                                Text('${stats.byStatus[s] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Clients', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onClients,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _clients.isEmpty
                        ? const Text(
                            'No clients yet. Add your current clients to track services, monthly fees and payments.',
                            style: TextStyle(color: _muted),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${formatTotals(money.monthly)} / month',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.3)),
                              Text('${money.active} active clients', style: const TextStyle(color: _muted)),
                              const SizedBox(height: 8),
                              Text('Collected this month: ${formatTotals(money.collectedThisMonth)}'),
                              Text(
                                'Due in 7 days: ${money.dueThisWeek} · overdue: ${money.overdue}',
                                style: TextStyle(
                                  color: money.overdue > 0 ? const Color(0xFF9F1C14) : const Color(0xFF374151),
                                  fontWeight: money.overdue > 0 ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatDay(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withAlpha(18), borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: const TextStyle(color: Brand.white, fontSize: 20, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: Brand.mist, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.color, required this.icon, required this.label, required this.onTap, this.badge = 0});
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Brand.navy, size: 24),
                  const Spacer(),
                  if (badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFDE4E1), borderRadius: BorderRadius.circular(99)),
                      child: Text('$badge', style: const TextStyle(color: Color(0xFF9F1C14), fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowUpTile extends StatelessWidget {
  const _FollowUpTile({required this.lead, required this.onTap});
  final Lead lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = lead.business.name;
    final detail = lead.notes.trim().isNotEmpty ? lead.notes.trim().split('\n').first : '${lead.status.label} · due ${formatDay(lead.followUp!)}';
    return Material(
      color: Brand.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Brand.soft, borderRadius: BorderRadius.circular(12)),
                child: Text(name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.navy)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.chevron_right, color: Brand.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Brand.white, borderRadius: BorderRadius.circular(18)),
        child: Text(text, style: const TextStyle(color: _muted, height: 1.4)),
      );
}
