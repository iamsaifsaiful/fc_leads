import 'package:flutter/material.dart';

import '../logic/html_analyzer.dart';
import '../models/business.dart';
import '../services/places_api.dart';
import '../services/settings_controller.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'lead_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.settings,
    required this.services,
    required this.onOpenSettings,
  });

  final SettingsController settings;
  final AppServices services;
  final VoidCallback onOpenSettings;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final List<Business> _results = [];
  String? _nextPage;
  String? _error;
  bool _loading = false;
  bool _noWebsiteOnly = false;
  Set<String> _contacted = {};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _refreshContacted() async {
    final leads = await widget.services.leads.all();
    if (!mounted) return;
    setState(() => _contacted = {for (final l in leads) if (l.contacted) l.business.id});
  }

  Future<void> _search({bool more = false}) async {
    final q = _query.text.trim();
    if (q.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _results.clear();
        _nextPage = null;
      }
    });
    try {
      final page = await widget.services.places.search(
        q,
        apiKey: widget.settings.value.apiKey,
        pageToken: more ? _nextPage : null,
      );
      if (!mounted) return;
      setState(() {
        _results.addAll(page.businesses);
        _nextPage = page.nextPageToken;
      });
      await _refreshContacted();
    } on PlacesException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _hasRealWebsite(Business b) => b.hasWebsite && socialPlatformOf(b.website) == null;

  Future<void> _open(Business b) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LeadScreen(
        business: b,
        settings: widget.settings,
        services: widget.services,
      ),
    ));
    await _refreshContacted();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _noWebsiteOnly ? _results.where((b) => !_hasRealWebsite(b)).toList() : _results;

    return Scaffold(
      appBar: AppBar(title: const Text('Find clients')),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (widget.settings.loaded && !widget.settings.value.hasApiKey) ...[
                _KeyBanner(onOpenSettings: widget.onOpenSettings),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'e.g. restaurants in Dhanmondi, Dhaka',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _search,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('No website only'),
                    selected: _noWebsiteOnly,
                    onSelected: (v) => setState(() => _noWebsiteOnly = v),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFF8A2412))),
              ],
              const SizedBox(height: 8),
              if (_results.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${visible.length} of ${_results.length} businesses',
                    style: const TextStyle(color: Brand.muted),
                  ),
                ),
              for (final b in visible) ...[
                _BusinessTile(
                  business: b,
                  hasWebsite: _hasRealWebsite(b),
                  contacted: _contacted.contains(b.id),
                  onTap: () => _open(b),
                ),
                const SizedBox(height: 10),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_nextPage != null)
                OutlinedButton(onPressed: () => _search(more: true), child: const Text('Load 20 more')),
              if (!_loading && _results.isEmpty && _error == null)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Text(
                    'Search Google Maps by business type and area. Open a result to '
                    'audit it and send a personalised graphic.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Brand.muted, height: 1.4),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _KeyBanner extends StatelessWidget {
  const _KeyBanner({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFBE4C2), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Add your Google Places API key in Settings to start searching.',
              style: TextStyle(color: Color(0xFF7A4300), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onOpenSettings, child: const Text('Settings')),
        ],
      ),
    );
  }
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({
    required this.business,
    required this.hasWebsite,
    required this.contacted,
    required this.onTap,
  });

  final Business business;
  final bool hasWebsite;
  final bool contacted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final meta = [
      if (b.category.isNotEmpty) b.category,
      if (b.rating != null) '${b.rating!.toStringAsFixed(1)}★ (${b.reviewCount})',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w700, fontSize: 17),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.ink)),
              ],
              if (b.address.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  b.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Brand.muted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Tag(
                    text: hasWebsite ? 'Has website' : 'No website',
                    bg: hasWebsite ? const Color(0xFFE3DCCF) : const Color(0xFFF6D2C9),
                    fg: hasWebsite ? Brand.ink : const Color(0xFF8A2412),
                  ),
                  if (b.phone.isEmpty && b.internationalPhone.isEmpty)
                    const _Tag(text: 'No phone', bg: Color(0xFFE3DCCF), fg: Brand.ink),
                  if (contacted) const _Tag(text: 'Contacted', bg: Color(0xFFD7EBDA), fg: Color(0xFF1D5230)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
