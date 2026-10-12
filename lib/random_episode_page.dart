import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'catalog.dart';
import 'episode.dart';
import 'episode_detail_page.dart';
import 'episode_state_provider.dart';
import 'widgets/square_cover_image.dart';

class RandomEpisodePage extends StatefulWidget {
  const RandomEpisodePage({super.key});

  @override
  State<RandomEpisodePage> createState() => _RandomEpisodePageState();
}

class _RandomEpisodePageState extends State<RandomEpisodePage> {
  String? _series;
  bool _onlyUnheard = true;
  Episode? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zufallsfolge')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _series,
            decoration: const InputDecoration(labelText: 'Reihe'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Alle Reihen')),
              for (final series in seriesCatalog)
                DropdownMenuItem(value: series.id, child: Text(series.name)),
            ],
            onChanged: (value) => setState(() => _series = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nur ungehörte Folgen'),
            value: _onlyUnheard,
            onChanged: (value) => setState(() => _onlyUnheard = value),
          ),
          FilledButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.casino_outlined),
            label: const Text('Folge auswählen'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 28),
            Center(child: _cover(_result!)),
            const SizedBox(height: 16),
            Text(
              _result!.formattedTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(seriesInfo(_result!.series).name),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EpisodeDetailPage(episodeId: _result!.id),
                ),
              ),
              child: const Text('Details öffnen'),
            ),
          ],
        ],
      ),
    );
  }

  void _pick() {
    final episodes = context.read<EpisodeStateProvider>().episodes.where((
      episode,
    ) {
      if (_series != null && episode.series != _series) return false;
      if (_onlyUnheard && episode.listened) return false;
      return !episode.isFutureRelease;
    }).toList();
    if (episodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Für diese Auswahl gibt es keine Folge.')),
      );
      return;
    }
    setState(
      () => _result = episodes[Random.secure().nextInt(episodes.length)],
    );
  }

  Widget _cover(Episode episode) {
    return SquareCoverImage(
      imageUrl: episode.coverUrl,
      size: 220,
      borderRadius: BorderRadius.circular(14),
      iconSize: 64,
    );
  }
}
