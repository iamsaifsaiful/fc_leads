import 'client_store.dart';
import 'lead_store.dart';
import 'notifications.dart';
import 'settings_controller.dart';

/// Keeps phone reminders in step with leads, clients and settings: any
/// change reschedules everything (batched into one pass).
class ReminderSync {
  ReminderSync({
    required this.notifier,
    required this.leads,
    required this.clients,
    required this.settings,
  });

  final Notifier notifier;
  final LeadStore leads;
  final ClientStore clients;
  final SettingsController settings;
  bool _pending = false;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await notifier.init();
    if (settings.value.remindersOn) await notifier.requestPermission();
    leads.addListener(_queue);
    clients.addListener(_queue);
    settings.addListener(_queue);
    _queue();
  }

  void _queue() {
    if (_pending) return;
    _pending = true;
    Future.microtask(() async {
      _pending = false;
      await syncNow();
    });
  }

  Future<void> syncNow() async {
    if (!settings.loaded) return;
    final planned = plannedReminders(await leads.all(), await clients.all(), settings.value, DateTime.now());
    await notifier.schedule(planned);
  }
}
