import 'dart:math' as math;

import '../models/client.dart';

String monthKey(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

String monthKeyOf(DateTime d) => monthKey(d.year, d.month);

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// "2026-10" → "October 2026".
String monthLabel(String key) {
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final m = int.tryParse(parts[1]) ?? 1;
  return '${_monthNames[(m - 1).clamp(0, 11)]} ${parts[0]}';
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The date a month's fee is due. Billing day 31 (or past the month's end)
/// means the last day of the month.
DateTime dueDate(Client c, int year, int month) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(c.billingDay, last));
}

enum BillState {
  upcoming('Upcoming'),
  dueSoon('Due soon'),
  dueToday('Due today'),
  overdue('Overdue'),
  notBilled('Not billed');

  const BillState(this.label);
  final String label;
}

/// Where a client's payments stand today.
class Billing {
  const Billing({
    required this.state,
    required this.month,
    required this.dueDate,
    this.daysLate = 0,
    this.unpaidMonths = const [],
  });

  final BillState state;

  /// The month to pay next, "YYYY-MM".
  final String month;
  final DateTime dueDate;
  final int daysLate;

  /// Months already due and not paid, oldest first.
  final List<String> unpaidMonths;
}

/// Works out the next payment: the oldest unpaid month up to now, or next
/// month when everything is paid. Paused and ended clients are not billed.
Billing billingFor(Client c, DateTime now) {
  final today = _day(now);
  final start = _day(c.startDate);

  // First billed month: the start month, unless its due day is before the start date.
  var y = start.year, m = start.month;
  if (dueDate(c, y, m).isBefore(start)) {
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
  }

  if (c.status != ClientStatus.active) {
    return Billing(state: BillState.notBilled, month: monthKey(y, m), dueDate: dueDate(c, y, m));
  }

  final unpaid = <(int, int)>[];
  var cy = y, cm = m;
  while (cy < today.year || (cy == today.year && cm <= today.month)) {
    if (!c.isPaid(monthKey(cy, cm))) unpaid.add((cy, cm));
    cm++;
    if (cm > 12) {
      cm = 1;
      cy++;
    }
  }

  final late = [
    for (final u in unpaid)
      if (dueDate(c, u.$1, u.$2).isBefore(today)) monthKey(u.$1, u.$2),
  ];

  // Next month to pay: oldest unpaid one, else the first month after now.
  final (ny, nm) = unpaid.isNotEmpty ? unpaid.first : (cy, cm);
  final due = dueDate(c, ny, nm);
  final diff = due.difference(today).inDays;

  final BillState state;
  if (diff < 0) {
    state = BillState.overdue;
  } else if (diff == 0) {
    state = BillState.dueToday;
  } else if (diff <= 3) {
    state = BillState.dueSoon;
  } else {
    state = BillState.upcoming;
  }
  return Billing(
    state: state,
    month: monthKey(ny, nm),
    dueDate: due,
    daysLate: diff < 0 ? -diff : 0,
    unpaidMonths: late,
  );
}

/// "15,000" for 15000; keeps two decimals only when needed.
String formatAmount(double v) {
  final whole = v.truncate();
  final cents = ((v - whole).abs() * 100).round();
  final digits = whole.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final sign = v < 0 ? '-' : '';
  return cents == 0 ? '$sign$buf' : '$sign$buf.${cents.toString().padLeft(2, '0')}';
}

String formatMoney(double v, String currency) => '${currency.trim()} ${formatAmount(v)}'.trim();

/// Totals for the Clients screen and Home.
class ClientStats {
  ClientStats(List<Client> clients, {DateTime? now}) : this._(clients, now ?? DateTime.now());

  ClientStats._(List<Client> clients, DateTime now)
      : active = clients.where((c) => c.status == ClientStatus.active).length,
        monthly = _sum(clients.where((c) => c.status == ClientStatus.active), (c) => c.monthlyFee),
        collectedThisMonth = _sumPayments(clients, monthKeyOf(now)),
        stillDueThisMonth = _sum(
          clients.where((c) {
            if (c.status != ClientStatus.active) return false;
            final b = billingFor(c, now);
            return b.month == monthKeyOf(now) || b.state == BillState.overdue;
          }),
          (c) => c.monthlyFee * math.max(1, billingFor(c, now).unpaidMonths.length),
        ),
        overdue = clients.where((c) => billingFor(c, now).state == BillState.overdue).length,
        dueThisWeek = clients.where((c) {
          final b = billingFor(c, now);
          return (b.state == BillState.dueToday || b.state == BillState.dueSoon || b.state == BillState.upcoming) &&
              b.dueDate.difference(_day(now)).inDays <= 7;
        }).length;

  final int active;

  /// Monthly income from active clients, per currency.
  final Map<String, double> monthly;

  /// Payments recorded for this month, per currency.
  final Map<String, double> collectedThisMonth;

  /// Fees still to collect this month (and earlier unpaid months), per currency.
  final Map<String, double> stillDueThisMonth;
  final int overdue;
  final int dueThisWeek;

  static Map<String, double> _sum(Iterable<Client> cs, double Function(Client) amount) {
    final out = <String, double>{};
    for (final c in cs) {
      out[c.currency] = (out[c.currency] ?? 0) + amount(c);
    }
    return out;
  }

  static Map<String, double> _sumPayments(List<Client> cs, String month) {
    final out = <String, double>{};
    for (final c in cs) {
      for (final p in c.payments.where((p) => p.month == month)) {
        out[c.currency] = (out[c.currency] ?? 0) + p.amount;
      }
    }
    return out;
  }
}

/// "BDT 45,000 + USD 300", or "0" when empty.
String formatTotals(Map<String, double> totals) {
  final parts = totals.entries.where((e) => e.value != 0).map((e) => formatMoney(e.value, e.key)).toList();
  return parts.isEmpty ? '0' : parts.join(' + ');
}

/// Clients as CSV for Excel or Google Sheets.
String clientsToCsv(List<Client> clients, {DateTime? now}) {
  String cell(Object? v) {
    final s = (v ?? '').toString();
    if (s.contains(RegExp('[",\n]'))) return '"${s.replaceAll('"', '""')}"';
    return s;
  }

  final at = now ?? DateTime.now();
  final rows = <String>[
    'Name,Contact person,Phone,Email,Services,Monthly fee,Currency,Billing day,Start date,Status,Next due,Payment state,Unpaid months,Notes',
  ];
  for (final c in clients) {
    final b = billingFor(c, at);
    final d = b.dueDate;
    rows.add([
      c.name, c.contactPerson, c.phone, c.email, c.services.join('; '), formatAmount(c.monthlyFee),
      c.currency, c.billingDay, c.startDate.toIso8601String().substring(0, 10), c.status.label,
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      b.state.label, b.unpaidMonths.join('; '), c.notes,
    ].map(cell).join(','));
  }
  return '${rows.join('\n')}\n';
}
