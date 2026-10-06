import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../models/business.dart';
import '../models/lead.dart';
import '../services/graphic_renderer.dart';
import '../services/lead_store.dart';
import '../services/places_api.dart';
import '../services/search_history.dart';
import '../services/settings_controller.dart';
import '../services/share_service.dart';
import '../services/website_checker.dart';
import 'dashboard_screen.dart';
import 'lead_screen.dart';
import 'leads_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'templates_screen.dart';

/// Everything that talks to the network, the phone or storage.
class AppServices {
  AppServices({
    PlacesApi? places,
    WebsiteChecker? checker,
    LeadStore? leads,
    ShareService? share,
    GraphicRenderer? renderer,
    GeoRepository? geo,
    SearchHistory? history,
  })  : places = places ?? PlacesApi(),
        checker = checker ?? WebsiteChecker(),
        leads = leads ?? LeadStore(),
        share = share ?? ShareService(),
        renderer = renderer ?? GraphicRenderer(),
        geo = geo ?? GeoRepository(),
        history = history ?? SearchHistory();

  final PlacesApi places;
  final WebsiteChecker checker;
  final LeadStore leads;
  final ShareService share;
  final GraphicRenderer renderer;
  final GeoRepository geo;
  final SearchHistory history;
}

/// Opens one business. [lead] carries where it was found (category, city).
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

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.settings, required this.services});

  final SettingsController settings;
  final AppServices services;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const home = 0, search = 1, leads = 2, settingsTab = 4;
  int _tab = home;

  /// Filter the Leads tab should open with, set from the dashboard.
  LeadsPreset? _preset;

  @override
  void initState() {
    super.initState();
    widget.settings.load();
  }

  void _go(int tab, {LeadsPreset? preset}) => setState(() {
        _tab = tab;
        if (preset != null) _preset = preset;
      });

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
            onSettings: () => _go(settingsTab),
          ),
          SearchScreen(
            settings: widget.settings,
            services: widget.services,
            onOpenSettings: () => _go(settingsTab),
          ),
          LeadsScreen(
            settings: widget.settings,
            services: widget.services,
            preset: _preset,
            onPresetUsed: () => _preset = null,
          ),
          TemplatesScreen(settings: widget.settings),
          SettingsScreen(settings: widget.settings, services: widget.services),
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
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'Templates'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
