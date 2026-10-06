import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../logic/html_analyzer.dart';
import '../models/business.dart';
import '../models/lead.dart';
import '../models/search_spec.dart';
import '../services/places_api.dart';
import '../services/settings_controller.dart';
import '../theme.dart';
import '../widgets/pickers.dart';
import 'home_shell.dart';

enum ResultSort {
  relevance('Best match'),
  rating('Highest rating'),
  mostReviews('Most reviews'),
  fewestReviews('Fewest reviews'),
  noWebsiteFirst('No website first');

  const ResultSort(this.label);
  final String label;
}

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
  final _free = TextEditingController();
  final _area = TextEditingController();
  SearchSpec _spec = const SearchSpec(countryCode: 'BD', countryName: 'Bangladesh', city: 'Dhaka');
  Country? _country;
  bool _freeMode = false;
  List<SearchSpec> _recent = [];

  final List<Business> _results = [];
  SearchSpec? _resultsFor;
  String? _nextPage;
  String? _error;
  bool _loading = false;

  ResultSort _sort = ResultSort.relevance;
  bool _noWebsiteOnly = false;
  bool _hasPhoneOnly = false;
  bool _hideSaved = false;
  Map<String, Lead> _saved = {};

  @override
  void initState() {
    super.initState();
    widget.services.leads.addListener(_refreshSaved);
    _init();
  }

  @override
  void dispose() {
    widget.services.leads.removeListener(_refreshSaved);
    _free.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final last = await widget.services.history.last();
    final recent = await widget.services.history.recent();
    var spec = last ?? _spec;
    final country = await widget.services.geo.country(spec.countryCode.isEmpty ? 'BD' : spec.countryCode);
    if (country != null && spec.countryName.isEmpty) spec = spec.copyWith(countryName: country.name);
    if (!mounted) return;
    setState(() {
      _spec = spec;
      _country = country;
      _recent = recent;
      _area.text = spec.area;
    });
    await _refreshSaved();
  }

  Future<void> _refreshSaved() async {
    final leads = await widget.services.leads.all();
    if (mounted) setState(() => _saved = {for (final l in leads) l.business.id: l});
  }

  Future<void> _chooseCategory() async {
    final c = await pickCategory(context, selected: _spec.category);
    if (c != null) setState(() => _spec = _spec.copyWith(category: c.label, categoryQuery: c.query));
  }

  Future<void> _chooseCountry() async {
    final c = await pickCountry(context, widget.services.geo, selectedCode: _spec.countryCode);
    if (c == null) return;
    final cities = await widget.services.geo.cities(c.code);
    setState(() {
      _country = c;
      _spec = _spec.copyWith(
        countryCode: c.code,
        countryName: c.name,
        city: cities.isEmpty ? '' : cities.first,
      );
    });
  }

  Future<void> _chooseCity() async {
    final country = _country;
    if (country == null) return;
    final city = await pickCity(context, widget.services.geo, country, selected: _spec.city);
    if (city != null) setState(() => _spec = _spec.copyWith(city: city));
  }

  SearchSpec get _current => _freeMode
      ? SearchSpec(freeText: _free.text, countryCode: _spec.countryCode, countryName: _spec.countryName)
      : _spec.copyWith(area: _area.text.trim(), freeText: '');

  Future<void> _search({SearchSpec? spec, bool more = false}) async {
    final s = spec ?? (more ? _resultsFor! : _current);
    if (_loading) return;
    if (!s.isComplete) {
      setState(() => _error = _freeMode ? 'Type what to search for.' : 'Choose a business type first.');
      return;
    }
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
        s.query,
        apiKey: widget.settings.value.apiKey,
        pageToken: more ? _nextPage : null,
        regionCode: s.countryCode,
      );
      if (!more) await widget.services.history.add(s);
      final recent = await widget.services.history.recent();
      if (!mounted) return;
      setState(() {
        _results.addAll(page.businesses);
        _nextPage = page.nextPageToken;
        _resultsFor = s;
        _recent = recent;
        if (page.businesses.isEmpty && !more) _error = 'No businesses found. Try a bigger city or another type.';
      });
    } on PlacesException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _useRecent(SearchSpec s) {
    setState(() {
      _freeMode = s.isFree;
      if (s.isFree) {
        _free.text = s.freeText;
      } else {
        _spec = s;
        _area.text = s.area;
      }
    });
    if (!s.isFree) {
      widget.services.geo.country(s.countryCode).then((c) {
        if (mounted && c != null) setState(() => _country = c);
      });
    }
    _search(spec: s);
  }

  bool _hasRealWebsite(Business b) => b.hasWebsite && socialPlatformOf(b.website) == null;

  List<Business> get _visible {
    final list = _results.where((b) {
      if (_noWebsiteOnly && _hasRealWebsite(b)) return false;
      if (_hasPhoneOnly && b.phone.isEmpty && b.internationalPhone.isEmpty) return false;
      if (_hideSaved && _saved.containsKey(b.id)) return false;
      return true;
    }).toList();
    switch (_sort) {
      case ResultSort.relevance:
        break;
      case ResultSort.rating:
        list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      case ResultSort.mostReviews:
        list.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
      case ResultSort.fewestReviews:
        list.sort((a, b) => a.reviewCount.compareTo(b.reviewCount));
      case ResultSort.noWebsiteFirst:
        int rank(Business b) => _hasRealWebsite(b) ? 1 : 0;
        list.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    return list;
  }

  void _open(Business b) {
    final s = _resultsFor;
    openLead(
      context,
      business: b,
      settings: widget.settings,
      services: widget.services,
      seed: Lead(
        business: b,
        items: const [],
        savedAt: DateTime.now(),
        category: s?.category ?? '',
        countryCode: s?.countryCode ?? '',
        city: s?.city ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(title: const Text('Find clients')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) => widget.settings.loaded && !widget.settings.value.hasApiKey
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _KeyBanner(onOpenSettings: widget.onOpenSettings),
                  )
                : const SizedBox.shrink(),
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Pick from lists'), icon: Icon(Icons.tune)),
              ButtonSegment(value: true, label: Text('Type a search'), icon: Icon(Icons.keyboard)),
            ],
            selected: {_freeMode},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _freeMode = v.first),
          ),
          const SizedBox(height: 12),
          if (_freeMode)
            TextField(
              controller: _free,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search Google Maps',
                hintText: 'e.g. rooftop restaurants in Gulshan',
                prefixIcon: Icon(Icons.search),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  _PickRow(
                    icon: Icons.storefront_outlined,
                    label: 'Business type',
                    value: _spec.category.isEmpty ? null : _spec.category,
                    placeholder: 'Choose a type',
                    onTap: _chooseCategory,
                  ),
                  const Divider(height: 1),
                  _PickRow(
                    icon: Icons.public,
                    label: 'Country',
                    value: _country == null ? null : '${_country!.flag}  ${_country!.name}',
                    placeholder: 'Choose a country',
                    onTap: _chooseCountry,
                  ),
                  const Divider(height: 1),
                  _PickRow(
                    icon: Icons.location_city_outlined,
                    label: 'City',
                    value: _spec.city.isEmpty ? null : _spec.city,
                    placeholder: 'Whole country',
                    onTap: _chooseCity,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: TextField(
                      controller: _area,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Area or neighbourhood (optional)',
                        hintText: 'e.g. Dhanmondi',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_current.isComplete) ...[
            const SizedBox(height: 8),
            Text(
              'Searching for: ${_current.query}',
              style: const TextStyle(color: Brand.muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : () => _search(),
            icon: const Icon(Icons.search),
            label: const Text('Search Google Maps'),
          ),
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('Recent searches', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () async {
                    await widget.services.history.clear();
                    setState(() => _recent = []);
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final s in _recent)
                  ActionChip(
                    avatar: const Icon(Icons.history, size: 16),
                    label: Text(s.title, overflow: TextOverflow.ellipsis),
                    onPressed: () => _useRecent(s),
                  ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF8A2412))),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${visible.length} of ${_results.length} businesses',
                    style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                PopupMenuButton<ResultSort>(
                  tooltip: 'Sort',
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => [
                    for (final s in ResultSort.values) PopupMenuItem(value: s, child: Text(s.label)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, size: 18),
                        const SizedBox(width: 4),
                        Text(_sort.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: const Text('No website only'),
                  selected: _noWebsiteOnly,
                  onSelected: (v) => setState(() => _noWebsiteOnly = v),
                ),
                FilterChip(
                  label: const Text('Has phone'),
                  selected: _hasPhoneOnly,
                  onSelected: (v) => setState(() => _hasPhoneOnly = v),
                ),
                FilterChip(
                  label: const Text('Hide saved'),
                  selected: _hideSaved,
                  onSelected: (v) => setState(() => _hideSaved = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          for (final b in visible) ...[
            _BusinessTile(
              business: b,
              hasWebsite: _hasRealWebsite(b),
              saved: _saved[b.id],
              onTap: () => _open(b),
            ),
            const SizedBox(height: 10),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_nextPage != null && _results.isNotEmpty)
            OutlinedButton(onPressed: () => _search(more: true), child: const Text('Load 20 more')),
          if (!_loading && _results.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.only(top: 28),
              child: Text(
                'Choose a business type and a city anywhere in the world, then open a result to audit it and send a personalised graphic.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.muted, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Brand.navy),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Brand.muted)),
      subtitle: Text(
        value ?? placeholder,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: value == null ? Brand.muted : Brand.navy,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
    required this.saved,
    required this.onTap,
  });

  final Business business;
  final bool hasWebsite;
  final Lead? saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final meta = [
      if (b.category.isNotEmpty) b.category,
      if (b.rating != null) '${b.rating!.toStringAsFixed(1)}★ (${b.reviewCount})',
    ].join(' · ');
    final linkedSocial = b.hasWebsite ? socialPlatformOf(b.website) : null;

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
                  if (linkedSocial != null)
                    _Tag(text: '$linkedSocial page', bg: const Color(0xFFE3DCCF), fg: Brand.ink),
                  if (b.phone.isEmpty && b.internationalPhone.isEmpty)
                    const _Tag(text: 'No phone', bg: Color(0xFFE3DCCF), fg: Brand.ink),
                  if (saved != null)
                    _Tag(
                      text: saved!.contacted ? 'Contacted' : 'Saved',
                      bg: const Color(0xFFD7EBDA),
                      fg: const Color(0xFF1D5230),
                    ),
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
