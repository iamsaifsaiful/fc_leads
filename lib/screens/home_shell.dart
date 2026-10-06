import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../models/business.dart';
import '../models/lead.dart';
import '../services/client_store.dart';
import '../services/graphic_renderer.dart';
import '../services/lead_store.dart';
import '../services/notifications.dart';
import '../services/places_api.dart';
import '../services/reminder_sync.dart';
import '../services/search_history.dart';
import '../services/settings_controller.dart';
import '../services/share_service.dart';
import '../services/website_checker.dart';
import 'client_screen.dart';
import 'clients_screen.dart';
import 'dashboard_screen.dart';
import 'lead_screen.dart';
import 'leads_screen.dart';
import 'more_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Everything that talks to the network, the phone or storage.
class AppServices {
  AppServices({
    PlacesApi? places,
    WebsiteChecker? checker,
    LeadStore? leads,
    ClientStore? clients,
    ShareService? share,
    GraphicRenderer? renderer,
    GeoRepository? geo,
    SearchHistory? history,
    Notifier? notifier,
  })  : places = places ?? PlacesApi(),
        checker = checker ?? WebsiteChecker(),
        leads = leads ?? LeadStore(),
        clients = clients ?? ClientStore(),
        share = share ?? ShareService(),
        renderer = renderer ?? GraphicRenderer(),
        geo = geo ?? GeoRepository(),
        history = history ?? SearchHistory(),
        notifier = notifier ?? NotificationService();

  final PlacesApi places;
  final WebsiteChecker checker;
  final LeadStore leads;
  final ClientStore clients;
  final ShareService share;
  final GraphicRenderer renderer;
  final GeoRepository geo;
  final SearchHistory history;
  final Notifier notifier;
}

/// Opens one business. [seed] carries where it was found (category, city).
Future<void> openLead(
  BuildContext context, {
  required Business business,
  required SettingsController settings,
  required AppServices services,
  Lead? seed,
}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LeadScreen(business: business, settings: settings, services: services, seed: seed),
    ));

Future<void> openSettings(BuildContext context, SettingsController settings, AppServices services) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(settings: settings, services: services),
    ));

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.settings, required this.services});

  final SettingsController settings;
  final AppServices services;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const home = 0, search = 1, leads = 2, clients = 3;
  int _tab = home;
  late final ReminderSync _reminders;

  /// Filter the Leads tab should open with, set from the dashboard.
  LeadsPreset? _preset;

  @override
  void initState() {
    super.initState();
    _reminders = ReminderSync(
      notifier: widget.services.notifier,
      leads: widget.services.leads,
      clients: widget.services.clients,
      settings: widget.settings,
    );
    widget.services.notifier.tapped.addListener(_onTap);
    widget.settings.load().then((_) => _reminders.start()).then((_) => _onTap());
  }

  @override
  void dispose() {
    widget.services.notifier.tapped.removeListener(_onTap);
    super.dispose();
  }

  /// A reminder was tapped: open the lead or client it is about.
  Future<void> _onTap() async {
    final payload = widget.services.notifier.tapped.value;
    if (payload == null || !mounted) return;
    widget.services.notifier.tapped.value = null;
    final i = payload.indexOf(':');
    if (i < 0) return;
    final kind = payload.substring(0, i);
    final id = payload.substring(i + 1);
    if (kind == 'lead') {
      final lead = await widget.services.leads.find(id);
      if (lead == null || !mounted) return;
      setState(() => _tab = leads);
      await openLead(context, business: lead.business, settings: widget.settings, services: widget.services);
    } else if (kind == 'client') {
      final client = await widget.services.clients.find(id);
      if (client == null || !mounted) return;
      setState(() => _tab = clients);
      await openClient(context, client: client, settings: widget.settings, services: widget.services);
    }
  }

  void _go(int tab, {LeadsPreset? preset}) => setState(() {
        _tab = tab;
        if (preset != null) _preset = preset;
      });

  void _settings() => openSettings(context, widget.settings, widget.services);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardScreen(
            settings: widget.settings,
            services: widget.services,
            onSearch: () => _go(search),
            onLeads: (preset) => _go(leads, preset: preset),
            onClients: () => _go(clients),
            onSettings: _settings,
          ),
          SearchScreen(
            settings: widget.settings,
            services: widget.services,
            onOpenSettings: _settings,
          ),
          LeadsScreen(
            settings: widget.settings,
            services: widget.services,
            preset: _preset,
            onPresetUsed: () => _preset = null,
          ),
          ClientsScreen(settings: widget.settings, services: widget.services),
          MoreScreen(settings: widget.settings, services: widget.services),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.travel_explore), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: 'Leads'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
