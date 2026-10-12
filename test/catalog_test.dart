import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinclair_tracker/episode.dart';
import 'package:sinclair_tracker/episode_data_service.dart';

void main() {
  late List<Map<String, dynamic>> rows;

  setUpAll(() async {
    final raw = await File(
      'assets/data/john_sinclair_episodes.json',
    ).readAsString();
    final root = jsonDecode(raw) as Map<String, dynamic>;
    rows = (root['episodes'] as List)
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  });

  test('catalogue contains 390 unique episodes', () {
    expect(rows, hasLength(390));
    expect(rows.map((row) => row['id']).toSet(), hasLength(390));
    expect(
      {
        for (final series in [
          'edition2000',
          'classics',
          'specials',
          'tonstudio_braun',
          'sinclair_reboot',
        ])
          series: rows.where((row) => row['series'] == series).length,
      },
      {
        'edition2000': 196,
        'classics': 50,
        'specials': 21,
        'tonstudio_braun': 108,
        'sinclair_reboot': 15,
      },
    );
  });

  test('latest Edition 2000 entry is episode 196', () {
    final latest = rows.singleWhere(
      (row) => row['series'] == 'edition2000' && row['number'] == 196,
    );
    expect(latest['title'], 'Die Maske');
    expect(latest['releaseDate'], '2026-08-28');
  });

  test('copyWith preserves catalogue fields and updates local state', () {
    final episode = Episode.fromJson(rows.first);
    final updated = episode.copyWith(listened: true, rating: 5, note: 'Top');
    expect(updated.id, episode.id);
    expect(updated.title, episode.title);
    expect(updated.listened, isTrue);
    expect(updated.rating, 5);
    expect(updated.note, 'Top');
  });

  test('online additions merge without replacing local episode state', () {
    final bundled = Episode.fromJson(
      rows.first,
    ).copyWith(listened: true, rating: 4, note: 'Bleibt erhalten');
    final addition = Episode(
      id: 'edition2000_197',
      series: 'edition2000',
      number: 197,
      displayNumber: '197',
      title: 'Der Horror-Helikopter',
      author: 'Jason Dark',
      description: '',
      director: '',
      script: '',
      template: 'Edition 2000 · Folge 197',
      links: const {},
    );

    final merged = mergeEpisodeCatalogues([bundled], [addition]);

    expect(merged, hasLength(2));
    expect(merged.first.listened, isTrue);
    expect(merged.first.rating, 4);
    expect(merged.last.id, 'edition2000_197');
  });
}
