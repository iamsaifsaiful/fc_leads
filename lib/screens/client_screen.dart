import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/services.dart';
import '../logic/billing.dart';
import '../logic/messages.dart';
import '../models/client.dart';
import '../services/settings_controller.dart';
import '../services/share_service.dart';
import '../theme.dart';
import 'clients_screen.dart' show BillingPill;
import 'dashboard_screen.dart' show formatDay;
import 'home_shell.dart';

/// Opens a client to view or edit. With no [client], creates a new one,
/// pre-filled from [draft] when given (e.g. from a won lead).
Future<void> openClient(
  BuildContext context, {
  Client? client,
  Client? draft,
  required SettingsController settings,
  required AppServices services,
}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ClientScreen(client: client, draft: draft, settings: settings, services: services),
    ));

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key, this.client, this.draft, required this.settings, required this.services});

  final Client? client;
  final Client? draft;
  final SettingsController settings;
  final AppServices services;

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final _form = GlobalKey<FormState>();
  late final Client _base;
  late final bool _isNew = widget.client == null;

  late final _name = TextEditingController(text: _base.name);
  late final _contact = TextEditingController(text: _base.contactPerson);
  late final _phone = TextEditingController(text: _base.phone);
  late final _email = TextEditingController(text: _base.email);
  late final _fee = TextEditingController(text: _base.monthlyFee == 0 ? '' : formatAmount(_base.monthlyFee).replaceAll(',', ''));
  late final _currency = TextEditingController(text: _base.currency);
  late final _notes = TextEditingController(text: _base.notes);
  late final _custom = TextEditingController();

  late List<String> _services = [..._base.services];
  late int _billingDay = _base.billingDay;
  late DateTime _start = _base.startDate;
  late ClientStatus _status = _base.status;
  late List<Payment> _payments = [..._base.payments];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _base = widget.client ??
        widget.draft ??
        Client(
          id: 'c${now.microsecondsSinceEpoch}',
          name: '',
          startDate: DateTime(now.year, now.month, now.day),
          billingDay: now.day > 28 ? 28 : now.day,
          currency: widget.settings.value.currency,
        );
  }

  @override
  void dispose() {
    for (final c in [_name, _contact, _phone, _email, _fee, _currency, _notes, _custom]) {
      c.dispose();
    }
    super.dispose();
  }

  Client get _current => Client(
        id: _base.id,
        name: _name.text.trim(),
        contactPerson: _contact.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        services: _services,
        monthlyFee: double.tryParse(_fee.text.replaceAll(',', '').trim()) ?? 0,
        currency: _currency.text.trim().isEmpty ? 'BDT' : _currency.text.trim().toUpperCase(),
        billingDay: _billingDay,
        startDate: _start,
        status: _status,
        notes: _notes.text.trim(),
        payments: _payments,
        leadId: _base.leadId,
      );

  Future<void> _save({bool close = true}) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await widget.services.clients.save(_current);
    if (!mounted) return;
    if (close) {
      Navigator.of(context).pop();
    } else {
      _toast('Saved');
    }
  }

  void _toast(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this client?'),
        content: const Text('Their payment history is deleted too.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.services.clients.remove(_base.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleService(String s) => setState(() {
        if (!_services.remove(s)) _services = [..._services, s];
      });

  void _addCustomService() {
    final s = _custom.text.trim();
    if (s.isEmpty || _services.contains(s)) return;
    setState(() {
      _services = [..._services, s];
      _custom.clear();
    });
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2015),
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: 'Client since',
    );
    if (d != null) setState(() => _start = d);
  }

  Future<void> _pickBillingDay() async {
    final day = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment due on day', style: TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= 28; d++)
                    ChoiceChip(
                      label: Text('$d'),
                      selected: _billingDay == d,
                      onSelected: (_) => Navigator.of(context).pop(d),
                    ),
                  ChoiceChip(
                    label: const Text('Last day'),
                    selected: _billingDay == 31,
                    onSelected: (_) => Navigator.of(context).pop(31),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (day != null) setState(() => _billingDay = day);
  }

  Future<void> _recordPayment(String month) async {
    final amount = TextEditingController(text: formatAmount(_current.monthlyFee).replaceAll(',', ''));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payment for ${monthLabel(month)}'),
        content: TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Amount received', suffixText: _current.currency),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final value = double.tryParse(amount.text.replaceAll(',', '').trim());
    amount.dispose();
    if (ok != true || value == null) return;
    setState(() {
      _payments = [
        ..._payments.where((p) => p.month != month),
        Payment(month: month, amount: value, paidOn: DateTime.now()),
      ];
    });
    if (!_isNew) await _save(close: false);
  }

  Future<void> _removePayment(Payment p) async {
    setState(() => _payments = [..._payments]..remove(p));
    if (!_isNew) await _save(close: false);
  }

  bool _report(ShareResult r, String app) {
    final share = widget.services.share;
    switch (r) {
      case ShareResult.opened:
        return true;
      case ShareResult.notInstalled:
        _toast('$app is not installed on this phone.');
      case ShareResult.failed:
        _toast('Could not open $app${share.lastError.isEmpty ? '' : ': ${share.lastError}'}');
    }
    return false;
  }

  Future<void> _sendReminder() async {
    final c = _current;
    final b = billingFor(c, DateTime.now());
    final text = TextEditingController(text: paymentMessage(c, b, widget.settings.value));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Payment reminder', style: TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 6),
              Text('To ${c.name} · ${c.phone.isEmpty ? 'no WhatsApp number' : c.phone}', style: const TextStyle(color: Brand.muted)),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                minLines: 6,
                maxLines: 14,
                decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: c.phone.isEmpty
                    ? null
                    : () async {
                        final phone = c.phone.replaceAll(RegExp(r'\D'), '');
                        _report(await widget.services.share.whatsappChat(phone: phone, text: text.text), 'WhatsApp');
                      },
                icon: const Icon(Icons.chat),
                label: const Text('Open WhatsApp chat'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  _report(
                    await widget.services.share.email(
                      imagePath: '',
                      to: c.email,
                      subject: 'Payment reminder: ${monthLabel(b.month)}',
                      body: text.text,
                    ),
                    'an email app',
                  );
                },
                icon: const Icon(Icons.mail_outline),
                label: const Text('Send by email'),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text.text));
                  _toast('Message copied');
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy message'),
              ),
            ],
          ),
        ),
      ),
    );
    text.dispose();
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        child: Text(t, style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 18)),
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = _current;
    final billing = billingFor(current, now);
    final standard = AgencyService.values.map((s) => s.label).toList();
    final custom = _services.where((s) => !standard.contains(s)).toList();
    final months = _recentMonths(current, now);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New client' : current.name.isEmpty ? 'Client' : current.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_isNew)
            IconButton(tooltip: 'Delete client', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (!_isNew && current.status == ClientStatus.active)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Next: ${monthLabel(billing.month)} · due ${formatDay(billing.dueDate)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          BillingPill(billing: billing),
                        ],
                      ),
                      if (billing.unpaidMonths.length > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Unpaid: ${billing.unpaidMonths.map(monthLabel).join(', ')}',
                          style: const TextStyle(color: Color(0xFF8A2412)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _recordPayment(billing.month),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Mark paid'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _sendReminder,
                              icon: const Icon(Icons.notifications_active_outlined),
                              label: const Text('Remind'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            _label('Client'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Add the business name' : null,
              decoration: const InputDecoration(labelText: 'Business name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contact,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Contact person'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'WhatsApp number with country code', hintText: '8801XXXXXXXXX'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            _label('Services'),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final s in [...standard, ...custom])
                  FilterChip(
                    label: Text(s),
                    selected: _services.contains(s),
                    onSelected: (_) => _toggleService(s),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _custom,
                    onSubmitted: (_) => _addCustomService(),
                    decoration: const InputDecoration(labelText: 'Other service', hintText: 'e.g. Facebook Ads', isDense: true),
                  ),
                ),
                IconButton(tooltip: 'Add service', icon: const Icon(Icons.add_circle_outline), onPressed: _addCustomService),
              ],
            ),
            _label('Billing'),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _fee,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final t = (v ?? '').replaceAll(',', '').trim();
                      if (t.isEmpty) return null;
                      return double.tryParse(t) == null ? 'Numbers only' : null;
                    },
                    decoration: const InputDecoration(labelText: 'Monthly fee'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _currency,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Currency'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.event_repeat, color: Brand.navy),
                    title: const Text('Payment due every month on'),
                    subtitle: Text(_billingDay == 31 ? 'the last day' : 'day $_billingDay'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickBillingDay,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.event_available, color: Brand.navy),
                    title: const Text('Client since'),
                    subtitle: Text('${formatDay(_start)} ${_start.year}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickStart,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in ClientStatus.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
            if (!_isNew) ...[
              _label('Payments'),
              Card(
                child: Column(
                  children: [
                    for (final m in months)
                      _MonthRow(
                        month: m,
                        payment: _paymentFor(m),
                        currency: current.currency,
                        onPay: () => _recordPayment(m),
                        onUndo: (p) => _removePayment(p),
                      ),
                  ],
                ),
              ),
            ],
            _label('Notes'),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'Contract details, login info location, preferences…'),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: Text(_isNew ? 'Add client' : 'Save')),
          ],
        ),
      ),
    );
  }

  Payment? _paymentFor(String month) {
    for (final p in _payments) {
      if (p.month == month) return p;
    }
    return null;
  }

  /// The last 12 billed months, newest first (plus next month).
  List<String> _recentMonths(Client c, DateTime now) {
    final out = <String>[];
    var y = now.year, m = now.month + 1;
    if (m > 12) {
      m = 1;
      y++;
    }
    final startKey = monthKeyOf(c.startDate);
    for (var i = 0; i < 13; i++) {
      final key = monthKey(y, m);
      if (key.compareTo(startKey) < 0) break;
      out.add(key);
      m--;
      if (m < 1) {
        m = 12;
        y--;
      }
    }
    return out;
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.month,
    required this.payment,
    required this.currency,
    required this.onPay,
    required this.onUndo,
  });

  final String month;
  final Payment? payment;
  final String currency;
  final VoidCallback onPay;
  final void Function(Payment) onUndo;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    return ListTile(
      dense: true,
      title: Text(monthLabel(month), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(p == null ? 'Not paid' : 'Paid ${formatMoney(p.amount, currency)} on ${formatDay(p.paidOn)}'),
      trailing: p == null
          ? TextButton(onPressed: onPay, child: const Text('Mark paid'))
          : IconButton(
              tooltip: 'Remove payment',
              icon: const Icon(Icons.undo),
              onPressed: () => onUndo(p),
            ),
      leading: Icon(
        p == null ? Icons.radio_button_unchecked : Icons.check_circle,
        color: p == null ? Brand.muted : const Color(0xFF2E8B57),
      ),
    );
  }
}
