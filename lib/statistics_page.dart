import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'catalog.dart';
import 'episode_state_provider.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final episodes = context.watch<EpisodeStateProvider>().episodes;
    final heard = episodes.where((episode) => episode.listened).length;
    final rated = episodes.where((episode) => episode.rating > 0).toList();
    final average = rated.isEmpty
        ? 0.0
        : rated.fold<int>(0, (sum, episode) => sum + episode.rating) /
            rated.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Gehört',
                  value: '$heard / ${episodes.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(label: 'Bewertet', value: '${rated.length}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Ø Sterne',
                  value: average.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Fortschritt je Reihe',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          for (final series in seriesCatalog) ...[
            Builder(
              builder: (context) {
                final items = episodes
                    .where((episode) => episode.series == series.id)
                    .toList();
                final completed =
                    items.where((episode) => episode.listened).length;
                final progress = items.isEmpty ? 0.0 : completed / items.length;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(series.icon),
                            const SizedBox(width: 8),
                            Expanded(child: Text(series.name)),
                            Text('$completed / ${items.length}'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: progress, minHeight: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 18),
          Text('Bewertungen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (var stars = 5; stars >= 1; stars--)
            _RatingRow(
              stars: stars,
              count:
                  episodes.where((episode) => episode.rating == stars).length,
              total: rated.length,
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.stars,
    required this.count,
    required this.total,
  });

  final int stars;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(width: 56, child: Text('$stars ★')),
            Expanded(
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : count / total,
                minHeight: 8,
              ),
            ),
            SizedBox(
                width: 42, child: Text('$count', textAlign: TextAlign.end)),
          ],
        ),
      );
}
