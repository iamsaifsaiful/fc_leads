
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/billing.dart';
import '../models/client.dart';
import '../models/lead.dart';
import '../models/settings.dart';

/// A reminder to show on the phone at [at].
class Reminder {
  const Reminder({required this.id, required this.at, required this.title, required this.body, required this.payload});
  final int id;
  final DateTime at;
  final String title;
  final String body;

  /// "lead:<businessId>" or "client:<clientId>".
  final String payload;
}

/// Stable 31-bit id for a string, so the same lead keeps the same id.
int stableId(String s, {int offset = 0}) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return offset + (h % 900000000);
}

DateTime _at(DateTime day, AppSettings s) => DateTime(day.year, day.month, day.day, s.reminderHour, s.reminderMinute);

/// Every reminder that should be scheduled now: one per open follow-up and
/// one per active client's next payment. Past times are skipped, except an
/// overdue payment gets a nudge the next morning.
List<Reminder> plannedReminders(List<Lead> leads, List<Client> clients, AppSettings s, DateTime now) {
  if (!s.remindersOn) return const [];
  final out = <Reminder>[];
  for (final l in leads) {
    final f = l.followUp;
    if (f == null || l.status == LeadStatus.won || l.status == LeadStatus.lost) continue;
    final at = _at(f, s);
    if (!at.isAfter(now)) continue;
    out.add(Reminder(
      id: stableId('lead:${l.business.id}', offset: 1),
      at: at,
      title: 'Follow up: ${l.business.name}',
      body: l.notes.trim().isNotEmpty ? l.notes.trim() : 'Status: ${l.status.label}. Tap to open the lead.',
      payload: 'lead:${l.business.id}',
    ));
  }
  for (final c in clients) {
    if (c.status != ClientStatus.active) continue;
    final b = billingFor(c, now);
    var at = _at(b.dueDate, s);
    var title = 'Payment due today: ${c.name}';
    if (b.state == BillState.overdue || !at.isAfter(now)) {
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      at = _at(tomorrow, s);
      title = 'Payment overdue: ${c.name}';
    }
    out.add(Reminder(
      id: stableId('client:${c.id}', offset: 1),
      at: at,
      title: title,
      body: '${formatMoney(c.monthlyFee, c.currency)} for ${monthLabel(b.month)}. Tap to send a reminder.',
      payload: 'client:${c.id}',
    ));
  }
  return out;
}

/// What the app needs from phone notifications.
abstract class Notifier {
  /// Payload of a tapped notification ("lead:…" / "client:…").
  ValueNotifier<String?> get tapped;
  Future<void> init();
  Future<void> requestPermission();

  /// Replaces every scheduled reminder with [reminders].
  Future<void> schedule(List<Reminder> reminders);
}

/// Shows reminders on the phone and reports taps.
class NotificationService implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  final tapped = ValueNotifier<String?>(null);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Follow-ups and client payment due dates',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (r) => tapped.value = r.payload,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        tapped.value = launch!.notificationResponse?.payload;
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Asks Android 13+ for permission to show notifications.
  @override
  Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          id: r.id,
          scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: r.title,
          body: r.body,
          payload: r.payload,
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }
}

/// Test double: records what would be scheduled.
class FakeNotifier implements Notifier {
  List<Reminder> scheduled = [];

  @override
  final tapped = ValueNotifier<String?>(null);

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> schedule(List<Reminder> reminders) async => scheduled = reminders;
}
