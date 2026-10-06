import 'package:flutter/material.dart';

import '../logic/billing.dart';
import '../models/client.dart';
import '../services/settings_controller.dart';
import '../theme.dart';
import 'client_screen.dart';
import 'dashboard_screen.dart' show formatDay;
import 'home_shell.dart';

enum ClientView {
  active('Active'),
  due('Due & overdue'),
  paused('Paused'),
  ended('Ended'),
  all('All');

  const ClientView(this.label);
  final String label;
}

/// Current clients: what they buy, what they pay and who owes this month.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.settings, required this.services});

  final SettingsController settings;
  final AppServices services;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Client>? _clients;
  ClientView _view = ClientView.active;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.services.clients.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.services.clients.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final c = await widget.services.clients.all();
    if (mounted) setState(() => _clients = c);
  }

  Future<void> _open({Client? client}) => openClient(
        context,
        client: client,
        settings: widget.settings,
        services: widget.services,
      );

  Future<void> _markPaid(Client c) async {
    final b = billingFor(c, DateTime.now());
    final next = c.copyWith(payments: [
      ...c.payments,
      Payment(month: b.month, amount: c.monthlyFee, paidOn: DateTime.now()),
    ]);
    await widget.services.clients.save(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${c.name}: ${monthLabel(b.month)} marked paid'),
        action: SnackBarAction(label: 'Undo', onPressed: () => widget.services.clients.save(c)),
      ));
  }

  Future<void> _export() async {
    final all = _clients ?? const <Client>[];
    if (all.isEmpty) return;
    final path = await widget.services.renderer.writeExport('fc_clients.csv', clientsToCsv(all));
    await widget.services.share.shareFile(path: path, mimeType: 'text/csv', subject: 'FC Leads clients');
  }

  List<Client> _shown(DateTime now) {
    final q = _query.trim().toLowerCase();
    return (_clients ?? const <Client>[]).where((c) {
      if (q.isNotEmpty && !'${c.name} ${c.contactPerson} ${c.services.join(' ')}'.toLowerCase().contains(q)) {
        return false;
      }
      switch (_view) {
        case ClientView.active:
          return c.status == ClientStatus.active;
        case ClientView.due:
          final s = billingFor(c, now).state;
          return s == BillState.overdue || s == BillState.dueToday || s == BillState.dueSoon;
        case ClientView.paused:
          return c.status == ClientStatus.paused;
        case ClientView.ended:
          return c.status == ClientStatus.ended;
        case ClientView.all:
          return true;
      }
    }).toList()
      ..sort((a, b) => billingFor(a, now).dueDate.compareTo(billingFor(b, now).dueDate));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final all = _clients;
    final stats = ClientStats(all ?? const [], now: now);
    final shown = _shown(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => widget.services.clients.reload(),
          ),
          IconButton(
            tooltip: 'Export as CSV',
            icon: const Icon(Icons.ios_share),
            onPressed: (all ?? const []).isEmpty ? null : _export,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add client'),
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => widget.services.clients.reload(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  _Summary(stats: stats),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search clients or services',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final v in ClientView.values)
                        ChoiceChip(
                          label: Text(v.label),
                          selected: _view == v,
                          onSelected: (_) => setState(() => _view = v),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (all.isEmpty)
                    const _Empty(
                      text: 'No clients yet. Add one with the button below, or open a won lead and tap "Make client".',
                    )
                  else if (shown.isEmpty)
                    const _Empty(text: 'No clients in this view.')
                  else
                    for (final c in shown) ...[
                      _ClientTile(
                        client: c,
                        billing: billingFor(c, now),
                        onTap: () => _open(client: c),
                        onMarkPaid: () => _markPaid(c),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.stats});
  final ClientStats stats;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value, {Color color = Brand.cream}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Brand.mist))),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly income', style: TextStyle(color: Brand.mist)),
          const SizedBox(height: 2),
          Text(
            formatTotals(stats.monthly),
            style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 28, color: Brand.cream),
          ),
          Text('${stats.active} active clients', style: const TextStyle(color: Brand.mist)),
          const SizedBox(height: 8),
          line('Collected this month', formatTotals(stats.collectedThisMonth), color: const Color(0xFF8FE0B4)),
          line('Still to collect', formatTotals(stats.stillDueThisMonth), color: Brand.gold),
          line('Overdue clients', '${stats.overdue}', color: stats.overdue > 0 ? const Color(0xFFFF9C85) : Brand.cream),
          line('Due in the next 7 days', '${stats.dueThisWeek}'),
        ],
      ),
    );
  }
}

/// Pill text and colours for a client's payment state.
(String, AuditColors) billingPill(Billing b) {
  switch (b.state) {
    case BillState.overdue:
      return ('Overdue ${b.daysLate}d', AuditColors.bad);
    case BillState.dueToday:
      return ('Due today', AuditColors.warn);
    case BillState.dueSoon:
      return ('Due ${formatDay(b.dueDate)}', AuditColors.warn);
    case BillState.upcoming:
      return ('Next ${formatDay(b.dueDate)}', AuditColors.good);
    case BillState.notBilled:
      return ('Not billed', AuditColors.neutral);
  }
}

enum AuditColors {
  good(Color(0xFFD7EBDA), Color(0xFF1D5230)),
  warn(Color(0xFFFBE4C2), Color(0xFF7A4300)),
  bad(Color(0xFFF6D2C9), Color(0xFF8A2412)),
  neutral(Color(0xFFE3DCCF), Brand.ink);

  const AuditColors(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

class BillingPill extends StatelessWidget {
  const BillingPill({super.key, required this.billing});
  final Billing billing;

  @override
  Widget build(BuildContext context) {
    final (text, colors) = billingPill(billing);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: colors.fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client, required this.billing, required this.onTap, required this.onMarkPaid});
  final Client client;
  final Billing billing;
  final VoidCallback onTap;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final c = client;
    final canPay = c.status == ClientStatus.active &&
        (billing.state == BillState.overdue || billing.state == BillState.dueToday || billing.state == BillState.dueSoon);
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
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BillingPill(billing: billing),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                c.services.isEmpty ? 'No services listed' : c.services.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Brand.ink),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatMoney(c.monthlyFee, c.currency)} / month · day ${c.billingDay}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (canPay)
                    TextButton.icon(
                      onPressed: onMarkPaid,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark paid'),
                    ),
                ],
              ),
              if (billing.unpaidMonths.length > 1)
                Text(
                  '${billing.unpaidMonths.length} months unpaid',
                  style: const TextStyle(color: Color(0xFF8A2412), fontWeight: FontWeight.w600, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted, height: 1.4)),
      );
}
