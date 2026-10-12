import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'catalog.dart';
import 'episode_state_provider.dart';
import 'widgets/square_cover_image.dart';

class EpisodeDetailPage extends StatefulWidget {
  const EpisodeDetailPage({super.key, required this.episodeId});

  final String episodeId;

  @override
  State<EpisodeDetailPage> createState() => _EpisodeDetailPageState();
}

class _EpisodeDetailPageState extends State<EpisodeDetailPage> {
  late final TextEditingController _noteController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final episode = context.watch<EpisodeStateProvider>().byId(
          widget.episodeId,
        );
    if (episode == null) {
      return const Scaffold(body: Center(child: Text('Folge nicht gefunden.')));
    }
    if (!_initialized) {
      _initialized = true;
      _noteController.text = episode.note;
    }
    final date = episode.releaseDate == null
        ? null
        : DateFormat('dd.MM.yyyy').format(episode.releaseDate!);
    return Scaffold(
      appBar: AppBar(title: Text('Folge ${episode.displayNumber}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          Center(child: _cover(episode.coverUrl)),
          const SizedBox(height: 20),
          Text(episode.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${seriesInfo(episode.series).name} · ${episode.template}'),
          if (date != null) Text('Veröffentlicht am $date'),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gehört'),
            subtitle: const Text('Wird dauerhaft auf diesem Gerät gespeichert'),
            value: episode.listened,
            onChanged: (value) => context
                .read<EpisodeStateProvider>()
                .updateEpisode(episode.id, listened: value),
          ),
          const SizedBox(height: 8),
          Text('Bewertung', style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: [
              for (var rating = 1; rating <= 5; rating++)
                IconButton(
                  tooltip: '$rating von 5 Sternen',
                  onPressed: () => context
                      .read<EpisodeStateProvider>()
                      .updateEpisode(episode.id, rating: rating),
                  icon: Icon(
                    rating <= episode.rating ? Icons.star : Icons.star_border,
                  ),
                ),
              if (episode.rating > 0)
                IconButton(
                  tooltip: 'Bewertung löschen',
                  onPressed: () => context
                      .read<EpisodeStateProvider>()
                      .updateEpisode(episode.id, rating: 0),
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Eigene Notiz',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async {
                await context.read<EpisodeStateProvider>().updateEpisode(
                      episode.id,
                      note: _noteController.text.trim(),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notiz gespeichert')),
                  );
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Notiz speichern'),
            ),
          ),
          if (episode.description.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Inhalt', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(episode.description),
          ],
          if (episode.director.isNotEmpty || episode.script.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Produktion', style: Theme.of(context).textTheme.titleLarge),
            if (episode.director.isNotEmpty) Text('Regie: ${episode.director}'),
            if (episode.script.isNotEmpty) Text('Skript: ${episode.script}'),
          ],
          if (episode.links.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Anhören & Quelle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            for (final entry in episode.links.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_linkIcon(entry.key)),
                title: Text(_linkName(entry.key)),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(
                  Uri.parse(entry.value),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _cover(String? url) {
    return SquareCoverImage(
      imageUrl: url,
      size: 240,
      borderRadius: BorderRadius.circular(16),
      iconSize: 64,
    );
  }

  String _linkName(String key) => switch (key) {
        'official' => 'Offizielle Produktseite',
        'spotify' => 'Spotify',
        'appleMusic' => 'Apple Music',
        'amazonMusic' => 'Amazon Music',
        'audible' => 'Audible',
        'youtubeMusic' => 'YouTube Music',
        _ => key,
      };

  IconData _linkIcon(String key) =>
      key == 'official' ? Icons.verified_outlined : Icons.play_circle_outline;
}
