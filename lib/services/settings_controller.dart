import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import 'settings_store.dart';

/// Holds the current settings and tells screens when they change.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final SettingsStore _store;
  AppSettings _value = const AppSettings();
  bool _loaded = false;

  AppSettings get value => _value;
  bool get loaded => _loaded;

  Future<void> load() async {
    _value = await _store.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings next) async {
    _value = next;
    notifyListeners();
    await _store.save(next);
  }
}
