import 'dart:convert';
import 'dart:io';

import 'package:sinclair_tracker/catalog_update_service.dart';
import 'package:sinclair_tracker/episode.dart';

Future<void> main() async {
  final raw = await File(
    'assets/data/john_sinclair_episodes.json',
  ).readAsString();
  final root = jsonDecode(raw) as Map<String, dynamic>;
  final episodes = (root['episodes'] as List<dynamic>)
      .map(
        (row) => Episode.fromJson(
          (row as Map<dynamic, dynamic>).cast<String, dynamic>(),
        ),
      )
      .toList(growable: false);

  final service = CatalogUpdateService();
  final result =
      await service.fetchUpdates(episodes).whenComplete(service.close);
  stdout.writeln(
    '${result.successfulSources} offizielle Reihen geprüft, '
    '${result.newEpisodes.length} neue Einträge gefunden.',
  );
  for (final episode in result.newEpisodes) {
    stdout.writeln('${episode.id}: ${episode.title}');
  }
  if (result.failedSources.isNotEmpty) {
    stderr.writeln('Nicht erreichbar: ${result.failedSources.join(', ')}');
    exitCode = 2;
  }
}
