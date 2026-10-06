import 'package:flutter/material.dart';

import '../data/categories.dart';
import '../data/geo.dart';
import '../theme.dart';

/// One row in a searchable picker.
class PickerItem<T> {
  const PickerItem({required this.value, required this.title, this.subtitle, this.leading, this.section});
  final T value;
  final String title;
  final String? subtitle;
  final String? leading;

  /// Rows with the same section are grouped under a header (when not searching).
  final String? section;
}

/// A full-screen list with a search box. Returns the chosen value.
class SearchPickerPage<T> extends StatefulWidget {
  const SearchPickerPage({
    super.key,
    required this.title,
    required this.hint,
    required this.load,
    this.selected,
    this.customLabel,
    this.customValue,
  });

  final String title;
  final String hint;
  final Future<List<PickerItem<T>>> Function() load;
  final T? selected;

  /// When given, typing shows a "Use '<text>'" row that returns customValue(text).
  final String Function(String text)? customLabel;
  final T Function(String text)? customValue;

  @override
  State<SearchPickerPage<T>> createState() => _SearchPickerPageState<T>();
}

class _SearchPickerPageState<T> extends State<SearchPickerPage<T>> {
  final _search = TextEditingController();
  List<PickerItem<T>>? _all;
  String _q = '';

  @override
  void initState() {
    super.initState();
    widget.load().then((items) {
      if (mounted) setState(() => _all = items);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Object> _rows() {
    final all = _all ?? const [];
    final q = foldForSearch(_q.trim());
    final rows = <Object>[];
    if (q.isNotEmpty && widget.customValue != null) rows.add(_Custom(_q.trim()));
    if (q.isEmpty) {
      String? section;
      for (final item in all) {
        if (item.section != null && item.section != section) {
          section = item.section;
          rows.add(section!);
        }
        rows.add(item);
      }
      return rows;
    }
    // Names that start with the text first, then ones that contain it.
    final starts = <PickerItem<T>>[];
    final contains = <PickerItem<T>>[];
    for (final item in all) {
      final t = foldForSearch(item.title);
      if (t.startsWith(q)) {
        starts.add(item);
      } else if (t.contains(q) || foldForSearch(item.subtitle ?? '').contains(q)) {
        contains.add(item);
      }
    }
    return rows
      ..addAll(starts)
      ..addAll(contains);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(hintText: widget.hint, prefixIcon: const Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: _all == null
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? const Center(child: Text('Nothing found', style: TextStyle(color: Brand.muted)))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          if (row is String) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                              child: Text(
                                row.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  color: Brand.goldDark,
                                ),
                              ),
                            );
                          }
                          if (row is _Custom) {
                            return ListTile(
                              leading: const Icon(Icons.edit_outlined),
                              title: Text(widget.customLabel?.call(row.text) ?? 'Use "${row.text}"'),
                              onTap: () => Navigator.of(context).pop(widget.customValue!(row.text)),
                            );
                          }
                          final item = row as PickerItem<T>;
                          final selected = item.value == widget.selected;
                          return ListTile(
                            leading: item.leading == null
                                ? null
                                : Text(item.leading!, style: const TextStyle(fontSize: 22)),
                            title: Text(item.title),
                            subtitle: item.subtitle == null
                                ? null
                                : Text(item.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: selected ? const Icon(Icons.check, color: Brand.navy) : null,
                            selected: selected,
                            onTap: () => Navigator.of(context).pop(item.value),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _Custom {
  const _Custom(this.text);
  final String text;
}

Future<T?> _open<T>(BuildContext context, SearchPickerPage<T> page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

Future<BusinessCategory?> pickCategory(BuildContext context, {String? selected}) {
  final current = selected == null ? null : categoryByLabel(selected);
  return _open<BusinessCategory>(
    context,
    SearchPickerPage<BusinessCategory>(
      title: 'Business type',
      hint: 'Search or type your own, e.g. "pizza"',
      selected: current,
      load: () async => [
        for (final sector in sectors)
          for (final c in categories.where((c) => c.sector == sector))
            PickerItem(
              value: c,
              title: c.label,
              subtitle: 'Needs: ${c.services.map((s) => s.label).join(', ')}',
              section: sector,
            ),
      ],
      customLabel: (t) => 'Search for "$t"',
      customValue: (t) => BusinessCategory(t, t, 'Custom', const []),
    ),
  );
}

Future<Country?> pickCountry(BuildContext context, GeoRepository geo, {String? selectedCode}) async {
  final all = await geo.countries();
  Country? current;
  for (final c in all) {
    if (c.code == selectedCode) current = c;
  }
  if (!context.mounted) return null;
  return _open<Country>(
    context,
    SearchPickerPage<Country>(
      title: 'Country',
      hint: 'Search 250 countries',
      selected: current,
      load: () async => [
        for (final c in all) PickerItem(value: c, title: c.name, leading: c.flag, subtitle: c.dialCode.isEmpty ? null : '+${c.dialCode}'),
      ],
    ),
  );
}

Future<String?> pickCity(BuildContext context, GeoRepository geo, Country country, {String? selected}) {
  return _open<String>(
    context,
    SearchPickerPage<String>(
      title: 'City in ${country.name}',
      hint: 'Search cities, largest first',
      selected: selected,
      load: () async => [
        for (final name in await geo.cities(country.code)) PickerItem(value: name, title: name),
      ],
      customLabel: (t) => 'Use "$t"',
      customValue: (t) => t,
    ),
  );
}
