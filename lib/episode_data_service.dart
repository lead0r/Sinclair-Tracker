import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'episode.dart';

List<Episode> _parseCatalogue(String rawJson) {
  final root = jsonDecode(rawJson) as Map<String, dynamic>;
  final rows = root['episodes'] as List<dynamic>;
  return rows
      .map((row) => Episode.fromJson((row as Map).cast<String, dynamic>()))
      .toList(growable: false);
}

class EpisodeDataService {
  static const assetPath = 'assets/data/john_sinclair_episodes.json';
  static const _cachedAdditionsKey = 'catalog_cached_additions';
  static const _lastCheckKey = 'catalog_last_successful_check';

  Future<List<Episode>> fetchAllEpisodes() async {
    final rawJson = await rootBundle.loadString(assetPath);
    final bundled = await compute(_parseCatalogue, rawJson);
    return mergeEpisodeCatalogues(bundled, await loadCachedAdditions());
  }

  Future<List<Episode>> fetchEpisodes(String series) async {
    final episodes = await fetchAllEpisodes();
    return episodes.where((episode) => episode.series == series).toList();
  }

  Future<List<Episode>> loadCachedAdditions() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cachedAdditionsKey);
      if (raw == null || raw.isEmpty) return const [];
      final rows = jsonDecode(raw) as List<dynamic>;
      return rows
          .map((row) => Episode.fromJson((row as Map).cast<String, dynamic>()))
          .toList(growable: false);
    } catch (error) {
      debugPrint('Cached catalogue additions could not be read: $error');
      return const [];
    }
  }

  Future<void> saveCachedAdditions(Iterable<Episode> additions) async {
    final merged = <String, Episode>{
      for (final episode in await loadCachedAdditions()) episode.id: episode,
      for (final episode in additions) episode.id: episode,
    };
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _cachedAdditionsKey,
      jsonEncode(merged.values.map((episode) => episode.toJson()).toList()),
    );
  }

  Future<DateTime?> getLastCatalogCheck() async {
    final preferences = await SharedPreferences.getInstance();
    return DateTime.tryParse(preferences.getString(_lastCheckKey) ?? '');
  }

  Future<void> setLastCatalogCheck(DateTime value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastCheckKey, value.toUtc().toIso8601String());
  }
}

List<Episode> mergeEpisodeCatalogues(
  Iterable<Episode> bundled,
  Iterable<Episode> additions,
) {
  final merged = <String, Episode>{
    for (final episode in bundled) episode.id: episode,
    for (final episode in additions) episode.id: episode,
  };
  const seriesOrder = {
    'edition2000': 0,
    'classics': 1,
    'specials': 2,
    'tonstudio_braun': 3,
    'sinclair_reboot': 4,
  };
  return merged.values.toList(growable: false)
    ..sort((a, b) {
      final series = (seriesOrder[a.series] ?? 99).compareTo(
        seriesOrder[b.series] ?? 99,
      );
      return series != 0 ? series : a.number.compareTo(b.number);
    });
}
