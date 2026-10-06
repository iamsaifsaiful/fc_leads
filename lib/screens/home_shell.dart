import 'package:flutter/material.dart';

import '../services/graphic_renderer.dart';
import '../services/lead_store.dart';
import '../services/places_api.dart';
import '../services/settings_controller.dart';
import '../services/share_service.dart';
import '../services/website_checker.dart';
import 'leads_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Everything that talks to the network, the phone or storage.
class AppServices {
  AppServices({
    PlacesApi? places,
    WebsiteChecker? checker,
    LeadStore? leads,
    ShareService? share,
    GraphicRenderer? renderer,
  })  : places = places ?? PlacesApi(),
        checker = checker ?? WebsiteChecker(),
        leads = leads ?? LeadStore(),
        share = share ?? ShareService(),
        renderer = renderer ?? GraphicRenderer();

  final PlacesApi places;
  final WebsiteChecker checker;
  final LeadStore leads;
  final ShareService share;
  final GraphicRenderer renderer;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.settings, required this.services});

  final SettingsController settings;
  final AppServices services;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  int _leadsVersion = 0;

  @override
  void initState() {
    super.initState();
    widget.settings.load();
  }

  void _select(int i) => setState(() {
        _tab = i;
        if (i == 1) _leadsVersion++;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          SearchScreen(
            settings: widget.settings,
            services: widget.services,
            onOpenSettings: () => _select(2),
          ),
          LeadsScreen(
            key: ValueKey(_leadsVersion),
            settings: widget.settings,
            services: widget.services,
          ),
          SettingsScreen(settings: widget.settings),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.travel_explore), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Leads'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
