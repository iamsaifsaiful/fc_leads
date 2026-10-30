import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/lead.dart';
import '../services/admin_api.dart';
import '../services/server.dart';
import '../services/settings_controller.dart';
import '../theme.dart';
import 'dashboard_screen.dart' show formatDay;
import 'home_shell.dart';
import 'leads_screen.dart' show StatusChip;
import 'templates_screen.dart';

/// The admin app: team report, team accounts and everyone's leads.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.settings, required this.services});

  final SettingsController settings;
  final AppServices services;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          ReportScreen(services: widget.services),
          TeamScreen(services: widget.services),
          AllLeadsScreen(services: widget.services),
          AdminMoreScreen(settings: widget.settings, services: widget.services),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Report'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Team'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'All leads'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}

const _ink = Color(0xFF0B1220);
const _muted = Color(0xFF5B6472);

String agoText(DateTime? t) {
  if (t == null) return 'Never active';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 2) return 'Active now';
  if (d.inMinutes < 60) return 'Active ${d.inMinutes} min ago';
  if (d.inHours < 24) return 'Active ${d.inHours} h ago';
  if (d.inDays < 30) return 'Active ${d.inDays} d ago';
  return 'Active ${formatDay(t)}';
}

String clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _change(int now, int before, Period p) {
  final d = now - before;
  final vs = switch (p) { Period.day => 'yesterday', Period.week => 'last week', Period.month => 'last month' };
  if (d == 0) return 'same as $vs';
  return '${d > 0 ? '+' : ''}$d vs $vs';
}

class PeriodSwitch extends StatelessWidget {
  const PeriodSwitch({super.key, required this.value, required this.onChanged});
  final Period value;
  final ValueChanged<Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE9EBEF), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final p in Period.values)
            Expanded(
              child: Material(
                color: p == value ? Brand.white : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => onChanged(p),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontWeight: p == value ? FontWeight.w800 : FontWeight.w600,
                          color: p == value ? _ink : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bars of leads checked (navy) and messaged (gold) per hour, day or week.
class WorkChart extends StatelessWidget {
  const WorkChart({super.key, required this.bars, this.height = 120});
  final List<ChartBar> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    var shown = bars;
    if (bars.length == 24) {
      // A day: only the working hours that have anything, at least 9–6.
      var first = 9, last = 18;
      for (var i = 0; i < 24; i++) {
        if (bars[i].leads + bars[i].sent > 0) {
          first = math.min(first, i);
          last = math.max(last, i);
        }
      }
      shown = bars.sublist(first, last + 1);
    }
    final max = shown.fold<int>(1, (m, b) => math.max(m, math.max(b.leads, b.sent)));
    return Semantics(
      label: 'Chart: ${shown.map((b) => '${b.label} ${b.leads} checked, ${b.sent} messaged').join('; ')}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height + 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final b in shown)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(b.leads, max, Brand.navy),
                          const SizedBox(width: 2),
                          _bar(b.sent, max, Brand.gold),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(b.label, maxLines: 1, style: const TextStyle(fontSize: 10.5, color: _muted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(int v, int max, Color c) => Container(
        width: 8,
        height: math.max(3, v / max * height),
        decoration: BoxDecoration(color: v == 0 ? const Color(0xFFE5E7EB) : c, borderRadius: BorderRadius.circular(3)),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(t, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
        ]);
    return Wrap(spacing: 12, children: [dot(Brand.navy, 'Checked'), dot(Brand.gold, 'Messaged')]);
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label, this.change});
  final int value;
  final String label;
  final String? change;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(color: Brand.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          Text(label, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
          if (change != null)
            Text(change!, maxLines: 2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF13603A))),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.initials, {this.size = 40, this.dark = true});
  final String initials;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: dark ? Brand.navy : Brand.gold, shape: BoxShape.circle),
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(color: dark ? Brand.gold : Brand.navy, fontWeight: FontWeight.w800, fontSize: size * 0.34),
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.4)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
}

// ---------------------------------------------------------------- Report

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Period _period = Period.week;
  TeamReport? _report;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.services.admin.report(_period);
      if (mounted) setState(() => _report = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(TeamMember m) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => WorkerScreen(services: widget.services, memberId: m.id, name: m.name, period: _period),
      ));

  @override
  Widget build(BuildContext context) {
    final r = _report;
    final user = widget.services.session.user;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ADMIN', style: TextStyle(fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: Brand.goldDark)),
            const Text('Team report'),
          ],
        ),
        toolbarHeight: 64,
        actions: [IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            PeriodSwitch(
              value: _period,
              onChanged: (p) {
                setState(() => _period = p);
                _load();
              },
            ),
            const SizedBox(height: 14),
            if (_loading && r == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null && r == null)
              _ErrorBox(message: _error!, onRetry: _load)
            else if (r != null) ...[
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
                children: [
                  _Kpi(value: r.totals.leads, label: 'Checked', change: _change(r.totals.leads, r.previous.leads, _period)),
                  _Kpi(value: r.totals.sent, label: 'Messaged', change: _change(r.totals.sent, r.previous.sent, _period)),
                  _Kpi(value: r.totals.replies, label: 'Replies', change: _change(r.totals.replies, r.previous.replies, _period)),
                  _Kpi(value: r.totals.won, label: 'Won', change: _change(r.totals.won, r.previous.won, _period)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Brand.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Team work', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                        Text('${r.totals.searches} searches', style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const _Legend(),
                    const SizedBox(height: 12),
                    WorkChart(bars: r.bars),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Text('Team', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  Text('checked · messaged · replies', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              if (r.team.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No team members yet. Add them in the Team tab.', style: TextStyle(color: _muted)),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < r.team.length; i++)
                        _MemberRow(
                          member: r.team[i],
                          best: r.team.first.counts.leads,
                          top: i == 0,
                          onTap: () => _open(r.team[i]),
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.best, required this.top, required this.onTap});
  final TeamMember member;
  final int best;
  final bool top;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = member.counts;
    final share = best == 0 ? 0.0 : c.leads / best;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
        child: Row(
          children: [
            _Avatar(member.initials, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.name + (member.disabled ? ' (off)' : ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                      ),
                      Text('${c.leads} · ${c.sent} · ${c.replies}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEEF0F3),
                      color: top ? Brand.gold : Brand.navy,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _muted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- One member

class WorkerScreen extends StatefulWidget {
  const WorkerScreen({super.key, required this.services, required this.memberId, required this.name, required this.period});
  final AppServices services;
  final int memberId;
  final String name;
  final Period period;

  @override
  State<WorkerScreen> createState() => _WorkerScreenState();
}

class _WorkerScreenState extends State<WorkerScreen> {
  late Period _period = widget.period;
  WorkerReport? _r;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.services.admin.worker(widget.memberId, _period);
      if (mounted) setState(() => _r = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String type) => switch (type) {
        'search' => Icons.search,
        'audit' => Icons.fact_check_outlined,
        'whatsapp' => Icons.chat_outlined,
        'email' => Icons.mail_outline,
        'status' => Icons.flag_outlined,
        'followup' => Icons.event_outlined,
        'client' => Icons.handshake_outlined,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (r == null && _loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (r == null && _error != null)
              _ErrorBox(message: _error!, onRetry: _load)
            else if (r != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(22)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Avatar(r.member.initials, size: 52, dark: false),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.member.name, style: const TextStyle(color: Brand.white, fontWeight: FontWeight.w800, fontSize: 19)),
                              const SizedBox(height: 3),
                              Text(
                                '${agoText(r.member.lastActive)}${r.since == null ? '' : ' · since ${formatDay(r.since!)} ${r.since!.year}'}',
                                style: const TextStyle(color: Brand.mist, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (final (v, l) in [
                          (r.member.counts.leads, 'Checked'),
                          (r.member.counts.sent, 'Messaged'),
                          (r.member.counts.replies, 'Replies'),
                          (r.member.counts.won, 'Won'),
                        ]) ...[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(color: Colors.white.withAlpha(18), borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$v', style: TextStyle(color: l == 'Won' ? Brand.gold : Brand.white, fontWeight: FontWeight.w800, fontSize: 19)),
                                  Text(l, style: const TextStyle(color: Brand.mist, fontSize: 11.5)),
                                ],
                              ),
                            ),
                          ),
                          if (l != 'Won') const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PeriodSwitch(
                value: _period,
                onChanged: (p) {
                  setState(() => _period = p);
                  _load();
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Brand.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(child: Text('Work', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                      Text('${r.member.counts.searches} searches', style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 6),
                    const _Legend(),
                    const SizedBox(height: 12),
                    WorkChart(bars: r.bars, height: 96),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Recent activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Card(
                child: r.recent.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16), child: Text('No activity yet.', style: TextStyle(color: _muted)))
                    : Column(
                        children: [
                          for (final a in r.recent)
                            ListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: Brand.soft, borderRadius: BorderRadius.circular(10)),
                                child: Icon(_icon(a.type), size: 19, color: Brand.navy),
                              ),
                              title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              subtitle: Text(
                                [if (a.at != null) '${formatDay(a.at!)}, ${clock(a.at!)}', if (a.detail.isNotEmpty) a.detail].join(' · '),
                                style: const TextStyle(fontSize: 12, color: _muted),
                              ),
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

// ---------------------------------------------------------------- Team

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<TeamMember>? _team;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await widget.services.admin.team();
      if (mounted) {
        setState(() {
          _team = t;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _toast(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  Future<void> _add() async {
    final added = await showModalBottomSheet<TeamMember>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddMemberSheet(admin: widget.services.admin),
    );
    if (added != null) {
      _toast('${added.name} can now sign in with Team.');
      _load();
    }
  }

  Future<void> _actions(TeamMember m) async {
    final me = widget.services.session.user?.id;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('See report'),
              onTap: () => Navigator.of(context).pop('report'),
            ),
            if (m.isTeam)
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Set a new password'),
                onTap: () => Navigator.of(context).pop('password'),
              ),
            if (m.id != me)
              ListTile(
                leading: Icon(m.disabled ? Icons.toggle_on_outlined : Icons.block),
                title: Text(m.disabled ? 'Turn account on' : 'Turn account off'),
                subtitle: Text(m.disabled ? 'They can sign in again.' : 'Signs them out of the app now.'),
                onTap: () => Navigator.of(context).pop('toggle'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    try {
      switch (choice) {
        case 'report':
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => WorkerScreen(services: widget.services, memberId: m.id, name: m.name, period: Period.week),
          ));
        case 'toggle':
          await widget.services.admin.updateMember(m.id, disabled: !m.disabled);
          _toast(m.disabled ? 'Account turned on.' : 'Account turned off.');
          _load();
        case 'password':
          final pass = _newPassword();
          await widget.services.admin.updateMember(m.id, password: pass);
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('New password'),
              content: SelectableText('${m.email}\n$pass', style: const TextStyle(fontSize: 16, height: 1.5)),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pass));
                    Navigator.of(context).pop();
                  },
                  child: const Text('Copy and close'),
                ),
              ],
            ),
          );
      }
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;
    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Brand.navy,
        foregroundColor: Brand.white,
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt, color: Brand.gold),
        label: const Text('Add member', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            if (team == null && _error == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (team == null)
              _ErrorBox(message: _error!, onRetry: _load)
            else if (team.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No team members yet. Tap "Add member".', textAlign: TextAlign.center, style: TextStyle(color: _muted)),
              )
            else ...[
              const Text('Today', style: TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final m in team) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _actions(m),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          _Avatar(m.initials, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                Text(m.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: _muted)),
                                const SizedBox(height: 4),
                                Text(
                                  m.disabled ? 'Turned off' : '${agoText(m.lastActive)} · ${m.counts.leads} checked, ${m.counts.sent} messaged today',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: m.disabled ? const Color(0xFF9F1C14) : const Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!m.isTeam)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFFFF4DC), borderRadius: BorderRadius.circular(99)),
                              child: const Text('Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.goldDark)),
                            ),
                          const Icon(Icons.more_vert, color: _muted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

String _newPassword() {
  const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = math.Random.secure();
  return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({required this.admin});
  final AdminApi admin;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController(text: _newPassword());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final m = await widget.admin.addMember(name: _name.text.trim(), email: _email.text.trim(), password: _pass.text);
      await Clipboard.setData(ClipboardData(text: '${_email.text.trim()}\n${_pass.text}'));
      if (mounted) Navigator.of(context).pop(m);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add a team member', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'They sign in with Team using this email and password. The login is copied for you to send them.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Password (8+ characters)')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFF9F1C14), fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Adding…' : 'Add member')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- All leads

class AllLeadsScreen extends StatefulWidget {
  const AllLeadsScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<AllLeadsScreen> createState() => _AllLeadsScreenState();
}

class _AllLeadsScreenState extends State<AllLeadsScreen> {
  List<RemoteLead>? _leads;
  String? _error;
  String _query = '';
  LeadStatus? _status;
  int? _owner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await widget.services.admin.leads();
      if (mounted) {
        setState(() {
          _leads = l;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _show(RemoteLead r) {
    final lead = r.lead;
    final b = lead?.business;
    final phone = b == null ? '' : (b.internationalPhone.isNotEmpty ? b.internationalPhone : b.phone);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(r.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                StatusChip(status: r.status),
              ]),
              const SizedBox(height: 4),
              Text([r.category, r.city].where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(color: _muted)),
              const SizedBox(height: 12),
              Text('Handled by ${r.ownerName}${r.updatedAt == null ? '' : ' · updated ${formatDay(r.updatedAt!)}'}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (b != null && b.address.isNotEmpty) ...[const SizedBox(height: 8), Text(b.address)],
              if (lead != null && lead.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Notes', style: TextStyle(fontWeight: FontWeight.w800)),
                Text(lead.notes),
              ],
              if (lead != null && (lead.whatsappSentAt != null || lead.emailSentAt != null)) ...[
                const SizedBox(height: 12),
                Text([
                  if (lead.whatsappSentAt != null) 'WhatsApp ${formatDay(lead.whatsappSentAt!)}',
                  if (lead.emailSentAt != null) 'Email ${formatDay(lead.emailSentAt!)}',
                ].join(' · ')),
              ],
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (phone.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Call'),
                    onPressed: () => launchUrl(Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}')),
                  ),
                if (b != null && b.mapsUrl.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Google Maps'),
                    onPressed: () => launchUrl(Uri.parse(b.mapsUrl), mode: LaunchMode.externalApplication),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _leads;
    final owners = <int, String>{for (final l in all ?? const <RemoteLead>[]) l.ownerId: l.ownerName};
    final q = _query.trim().toLowerCase();
    final shown = (all ?? const <RemoteLead>[]).where((l) {
      if (_status != null && l.status != _status) return false;
      if (_owner != null && l.ownerId != _owner) return false;
      if (q.isNotEmpty && !'${l.name} ${l.city} ${l.category} ${l.ownerName}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('All leads')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(hintText: 'Search name, area, member', prefixIcon: Icon(Icons.search), isDense: true),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ChoiceChip(label: const Text('Everyone'), selected: _owner == null, onSelected: (_) => setState(() => _owner = null)),
                for (final e in owners.entries) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(label: Text(e.value), selected: _owner == e.key, onSelected: (_) => setState(() => _owner = e.key)),
                ],
              ]),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ChoiceChip(label: const Text('Any status'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
                for (final s in LeadStatus.values) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(label: Text(s.label), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
                ],
              ]),
            ),
            const SizedBox(height: 10),
            if (all == null && _error == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (all == null)
              _ErrorBox(message: _error!, onRetry: _load)
            else ...[
              Text('${shown.length} of ${all.length} leads', style: const TextStyle(color: _muted)),
              const SizedBox(height: 8),
              for (final l in shown) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _show(l),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ),
                            StatusChip(status: l.status),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            [l.category, l.city, 'by ${l.ownerName}'].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- More

class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key, required this.settings, required this.services});
  final SettingsController settings;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final user = services.session.user;
    Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
          child: ListTile(
            leading: Icon(icon, color: Brand.navy),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: _Avatar(user.initials),
                title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${user.email}\nAdmin · $serverHost'),
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: 10),
          tile(Icons.travel_explore, 'Open the team app', 'Search, audit and message clients yourself',
              () => services.session.setAdminView(false)),
          const SizedBox(height: 8),
          tile(Icons.edit_note, 'Message templates', 'Outreach and payment messages on this phone',
              () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TemplatesScreen(settings: settings)))),
          const SizedBox(height: 8),
          tile(Icons.language, 'Website settings', 'Google key, daily target and agency details',
              () => launchUrl(Uri.parse('$serverBase/wp-admin/admin.php?page=fcl-settings'), mode: LaunchMode.externalApplication)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF9F1C14), side: const BorderSide(color: Color(0xFF9F1C14))),
            onPressed: () => services.session.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
