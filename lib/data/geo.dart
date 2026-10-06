import 'dart:convert';

import 'package:flutter/services.dart';

class Country {
  const Country({required this.code, required this.name, required this.dialCode});

  /// ISO 3166-1 alpha-2, e.g. "BD".
  final String code;
  final String name;

  /// Calling code without "+", e.g. "880".
  final String dialCode;

  /// Flag emoji built from the two letters of [code].
  String get flag => String.fromCharCodes(
        code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
      );

  factory Country.fromJson(Map<String, dynamic> json) => Country(
        code: json['c'] as String,
        name: json['n'] as String,
        dialCode: (json['p'] as String?) ?? '',
      );
}

/// Countries and their cities (largest first), bundled from GeoNames.
class GeoRepository {
  GeoRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  List<Country>? _countries;
  final Map<String, List<String>> _cities = {};

  Future<List<Country>> countries() async {
    if (_countries != null) return _countries!;
    final raw = await _bundle.loadString('assets/geo/countries.json');
    final list = (jsonDecode(raw) as List)
        .map((e) => Country.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return _countries = list;
  }

  Future<Country?> country(String code) async {
    for (final c in await countries()) {
      if (c.code == code) return c;
    }
    return null;
  }

  /// City names for a country, most populous first. Empty if none bundled.
  Future<List<String>> cities(String countryCode) async {
    final cached = _cities[countryCode];
    if (cached != null) return cached;
    List<String> names;
    try {
      final raw = await _bundle.loadString('assets/geo/cities/$countryCode.txt');
      names = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    } catch (_) {
      names = const [];
    }
    return _cities[countryCode] = names;
  }
}

/// Lowercase and strip common accents so "sao paulo" finds "São Paulo".
String foldForSearch(String s) {
  const from = 'àáâãäåāăąçćčďèéêëēėęěìíîïīįñńňòóôõöøōőřśšşťùúûüūůűųýÿźżž';
  const to = 'aaaaaaaaacccdeeeeeeeeiiiiiinnnoooooooorssstuuuuuuuuyyzzz';
  final lower = s.toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf.toString();
}
