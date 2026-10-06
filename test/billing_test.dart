import 'package:fc_leads/logic/billing.dart';
import 'package:fc_leads/logic/messages.dart';
import 'package:fc_leads/models/business.dart';
import 'package:fc_leads/models/client.dart';
import 'package:fc_leads/models/lead.dart';
import 'package:fc_leads/models/settings.dart';
import 'package:fc_leads/services/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

Client _client({int day = 10, DateTime? start, List<Payment> payments = const [], ClientStatus status = ClientStatus.active}) =>
    Client(
      id: 'c1',
      name: 'Green Leaf Dental',
      contactPerson: 'Dr. Karim',
      phone: '8801711234567',
      services: const ['Website Design', 'SEO & Growth Support'],
      monthlyFee: 15000,
      billingDay: day,
      startDate: start ?? DateTime(2026, 8, 1),
      status: status,
      payments: payments,
    );

Payment _paid(String month) => Payment(month: month, amount: 15000, paidOn: DateTime(2026, 1, 1));

void main() {
  test('due date clamps to the last day of short months', () {
    expect(dueDate(_client(day: 31), 2026, 2), DateTime(2026, 2, 28));
    expect(dueDate(_client(day: 10), 2026, 2), DateTime(2026, 2, 10));
  });

  test('upcoming when everything so far is paid', () {
    final c = _client(payments: [_paid('2026-08'), _paid('2026-09'), _paid('2026-10')]);
    final b = billingFor(c, DateTime(2026, 10, 7));
    expect(b.state, BillState.upcoming);
    expect(b.month, '2026-11');
    expect(b.dueDate, DateTime(2026, 11, 10));
  });

  test('this month due soon, then due today, then overdue', () {
    final c = _client(payments: [_paid('2026-08'), _paid('2026-09')]);
    expect(billingFor(c, DateTime(2026, 10, 1)).state, BillState.upcoming);
    expect(billingFor(c, DateTime(2026, 10, 8)).state, BillState.dueSoon);
    expect(billingFor(c, DateTime(2026, 10, 10, 18)).state, BillState.dueToday);
    final late = billingFor(c, DateTime(2026, 10, 15));
    expect(late.state, BillState.overdue);
    expect(late.daysLate, 5);
  });

  test('missed months are listed oldest first', () {
    final c = _client(payments: [_paid('2026-08')]);
    final b = billingFor(c, DateTime(2026, 10, 15));
    expect(b.month, '2026-09');
    expect(b.unpaidMonths, ['2026-09', '2026-10']);
  });

  test('starting after the due day bills from next month', () {
    final c = _client(day: 5, start: DateTime(2026, 10, 7));
    final b = billingFor(c, DateTime(2026, 10, 7));
    expect(b.month, '2026-11');
    expect(b.state, BillState.upcoming);
  });

  test('paused clients are not billed', () {
    expect(billingFor(_client(status: ClientStatus.paused), DateTime(2026, 10, 15)).state, BillState.notBilled);
  });

  test('money formatting', () {
    expect(formatAmount(15000), '15,000');
    expect(formatAmount(1234567.5), '1,234,567.50');
    expect(formatAmount(999), '999');
    expect(formatMoney(15000, 'BDT'), 'BDT 15,000');
    expect(formatTotals({'BDT': 15000, 'USD': 300}), 'BDT 15,000 + USD 300');
    expect(formatTotals({}), '0');
    expect(monthLabel('2026-10'), 'October 2026');
  });

  test('stats add up income, collected and overdue', () {
    final now = DateTime(2026, 10, 15);
    final a = _client(payments: [_paid('2026-08'), _paid('2026-09'), Payment(month: '2026-10', amount: 15000, paidOn: now)]);
    final b = Client(
      id: 'c2',
      name: 'Rahim Tea House',
      monthlyFee: 5000,
      billingDay: 1,
      startDate: DateTime(2026, 9, 1),
    );
    final s = ClientStats([a, b], now: now);
    expect(s.active, 2);
    expect(s.monthly['BDT'], 20000);
    expect(s.collectedThisMonth['BDT'], 15000);
    expect(s.overdue, 1);
    expect(s.stillDueThisMonth['BDT'], 10000);
  });

  test('payment reminder fills in the template', () {
    const settings = AppSettings(senderName: 'Saiful', paymentInfo: 'bKash: 01700000000');
    final c = _client(payments: [_paid('2026-08'), _paid('2026-09')]);
    final msg = paymentMessage(c, billingFor(c, DateTime(2026, 10, 8)), settings);
    expect(msg, startsWith('Hi Dr. Karim,'));
    expect(msg, contains('BDT 15,000 for Website Design and SEO & Growth Support (October 2026) is due on 10 Oct'));
    expect(msg, contains('bKash: 01700000000'));
    expect(msg, endsWith('Saiful'));
  });

  test('payment reminder adds up missed months', () {
    final c = _client(payments: [_paid('2026-08')]);
    final msg = paymentMessage(c, billingFor(c, DateTime(2026, 10, 15)), const AppSettings());
    expect(msg, contains('BDT 30,000'));
    expect(msg, contains('September 2026, October 2026'));
  });

  test('clients CSV has a row per client', () {
    final csv = clientsToCsv([_client()], now: DateTime(2026, 10, 7));
    expect(csv.split('\n')[1], startsWith('Green Leaf Dental,Dr. Karim,8801711234567'));
  });

  group('reminders', () {
    final now = DateTime(2026, 10, 7, 12);
    const s = AppSettings(reminderHour: 9, reminderMinute: 30);
    Lead lead(String id, DateTime? followUp, {LeadStatus status = LeadStatus.contacted}) => Lead(
          business: Business(id: id, name: 'Shop $id'),
          items: const [],
          savedAt: now,
          followUp: followUp,
          status: status,
        );

    test('one per future follow-up, at the chosen time', () {
      final r = plannedReminders([
        lead('a', DateTime(2026, 10, 9)),
        lead('b', DateTime(2026, 10, 7)), // today 9:30 already passed
        lead('c', DateTime(2026, 10, 9), status: LeadStatus.won),
        lead('d', null),
      ], const [], s, now);
      expect(r, hasLength(1));
      expect(r.single.at, DateTime(2026, 10, 9, 9, 30));
      expect(r.single.payload, 'lead:a');
      expect(r.single.title, 'Follow up: Shop a');
    });

    test('payment due date and overdue nudge', () {
      final due = _client(payments: [_paid('2026-08'), _paid('2026-09')]);
      final r = plannedReminders(const [], [due], s, now);
      expect(r.single.at, DateTime(2026, 10, 10, 9, 30));
      expect(r.single.title, 'Payment due today: Green Leaf Dental');
      expect(r.single.payload, 'client:c1');

      final late = _client(payments: [_paid('2026-08')]);
      final r2 = plannedReminders(const [], [late], s, now);
      expect(r2.single.at, DateTime(2026, 10, 8, 9, 30));
      expect(r2.single.title, 'Payment overdue: Green Leaf Dental');
    });

    test('nothing when reminders are off', () {
      final r = plannedReminders([lead('a', DateTime(2026, 10, 9))], [_client()], s.copyWith(remindersOn: false), now);
      expect(r, isEmpty);
    });

    test('ids are stable and differ', () {
      expect(stableId('lead:a'), stableId('lead:a'));
      expect(stableId('lead:a'), isNot(stableId('lead:b')));
    });
  });
}
