import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'catalog.dart';
import 'episode.dart';
import 'episode_detail_page.dart';
import 'episode_state_provider.dart';
import 'list_view_preferences.dart';
import 'random_episode_page.dart';
import 'settings_page.dart';
import 'statistics_page.dart';
import 'widgets/cover_warmup_banner.dart';
import 'widgets/sinclair_cross_mark.dart';
import 'widgets/square_cover_image.dart';

class EpisodeListPage extends StatefulWidget {
  const EpisodeListPage({super.key});

  @override
  State<EpisodeListPage> createState() => _EpisodeListPageState();
}

class _EpisodeListPageState extends State<EpisodeListPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;
  late int _rememberedTabIndex;

  @override
  void initState() {
    super.initState();
    final preferences = context.read<EpisodeListPreferences>();
    final savedIndex = seriesCatalog.indexWhere(
      (series) => series.id == preferences.selectedSeriesId,
    );
    _rememberedTabIndex = savedIndex < 0 ? 0 : savedIndex;
    _tabController = TabController(
      length: seriesCatalog.length,
      initialIndex: _rememberedTabIndex,
      vsync: this,
    )..addListener(_rememberSelectedSeries);
    _searchController.text = preferences.query;
  }

  void _rememberSelectedSeries() {
    final index = _tabController.index;
    if (index == _rememberedTabIndex) return;
    _rememberedTabIndex = index;
    context.read<EpisodeListPreferences>().setSelectedSeries(
          seriesCatalog[index].id,
        );
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_rememberSelectedSeries)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listPreferences = context.watch<EpisodeListPreferences>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SinclairCrossMark(size: 34),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sinclair Tracker'),
                Text(
                  '${context.watch<EpisodeStateProvider>().episodes.length} Hörspiele',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<EpisodeSort>(
            tooltip: 'Sortierung',
            initialValue: listPreferences.sort,
            onSelected: listPreferences.setSort,
            icon: const Icon(Icons.sort),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: EpisodeSort.number,
                child: Text('Folgennummer'),
              ),
              PopupMenuItem(
                value: EpisodeSort.newest,
                child: Text('Neueste zuerst'),
              ),
              PopupMenuItem(value: EpisodeSort.title, child: Text('Titel')),
              PopupMenuItem(
                value: EpisodeSort.rating,
                child: Text('Bewertung'),
              ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: _openPage,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'random', child: Text('Zufallsfolge')),
              PopupMenuItem(value: 'stats', child: Text('Statistik')),
              PopupMenuItem(
                value: 'settings',
                child: Text('Einstellungen & Backup'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            for (final series in seriesCatalog)
              Tab(icon: Icon(series.icon), text: series.shortName),
          ],
        ),
      ),
      body: Column(
        children: [
          const CoverWarmupBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchController,
              onChanged: listPreferences.setQuery,
              decoration: InputDecoration(
                hintText: 'Titel, Nummer oder Beschreibung suchen',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: listPreferences.query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          listPreferences.setQuery('');
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SegmentedButton<HeardFilter>(
                  segments: const [
                    ButtonSegment(
                      value: HeardFilter.all,
                      label: Text('Alle'),
                    ),
                    ButtonSegment(
                      value: HeardFilter.heard,
                      label: Text('Gehört'),
                    ),
                    ButtonSegment(
                      value: HeardFilter.unheard,
                      label: Text('Offen'),
                    ),
                  ],
                  selected: {listPreferences.heardFilter},
                  onSelectionChanged: (value) =>
                      listPreferences.setHeardFilter(value.first),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<int>(
                  initialValue: listPreferences.minimumRating,
                  onSelected: listPreferences.setMinimumRating,
                  itemBuilder: (_) => [
                    for (var rating = 0; rating <= 5; rating++)
                      PopupMenuItem(
                        value: rating,
                        child: Text(
                          rating == 0 ? 'Jede Bewertung' : 'Mind. $rating ★',
                        ),
                      ),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.star_outline, size: 18),
                    label: Text(
                      listPreferences.minimumRating == 0
                          ? 'Bewertung'
                          : 'ab ${listPreferences.minimumRating} ★',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final series in seriesCatalog)
                  _buildSeries(series.id, listPreferences),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeries(
    String seriesId,
    EpisodeListPreferences listPreferences,
  ) {
    final all = context.watch<EpisodeStateProvider>().episodes;
    final normalizedQuery = listPreferences.query.trim().toLowerCase();
    final episodes = all.where((episode) {
      if (episode.series != seriesId) return false;
      if (listPreferences.heardFilter == HeardFilter.heard &&
          !episode.listened) {
        return false;
      }
      if (listPreferences.heardFilter == HeardFilter.unheard &&
          episode.listened) {
        return false;
      }
      if (episode.rating < listPreferences.minimumRating) return false;
      return normalizedQuery.isEmpty ||
          episode.title.toLowerCase().contains(normalizedQuery) ||
          episode.displayNumber.toLowerCase().contains(normalizedQuery) ||
          episode.description.toLowerCase().contains(normalizedQuery);
    }).toList();
    switch (listPreferences.sort) {
      case EpisodeSort.number:
        episodes.sort((a, b) => a.number.compareTo(b.number));
      case EpisodeSort.newest:
        episodes.sort(
          (a, b) => (b.releaseDate ?? DateTime(1900)).compareTo(
            a.releaseDate ?? DateTime(1900),
          ),
        );
      case EpisodeSort.title:
        episodes.sort((a, b) => a.title.compareTo(b.title));
      case EpisodeSort.rating:
        episodes.sort((a, b) => b.rating.compareTo(a.rating));
    }
    if (episodes.isEmpty) {
      return const Center(child: Text('Keine passenden Folgen gefunden.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 96),
      itemCount: episodes.length,
      itemBuilder: (context, index) => _EpisodeCard(episode: episodes[index]),
    );
  }

  void _openPage(String page) {
    final widget = switch (page) {
      'random' => const RandomEpisodePage(),
      'stats' => const StatisticsPage(),
      _ => const SettingsPage(),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => widget));
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: episode.listened
          ? scheme.secondaryContainer.withValues(alpha: 0.55)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EpisodeDetailPage(episodeId: episode.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _cover(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.formattedTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      episode.template,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (episode.rating > 0) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${'★' * episode.rating}${'☆' * (5 - episode.rating)}',
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: episode.listened
                    ? 'Als ungehört markieren'
                    : 'Als gehört markieren',
                onPressed: () => context
                    .read<EpisodeStateProvider>()
                    .updateEpisode(episode.id, listened: !episode.listened),
                icon: Icon(
                  episode.listened
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: episode.listened ? scheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover() {
    return SquareCoverImage(
      imageUrl: episode.coverUrl,
      size: 72,
      borderRadius: BorderRadius.circular(8),
      iconSize: 30,
    );
  }
}
