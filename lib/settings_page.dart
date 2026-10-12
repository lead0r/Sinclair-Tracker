import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'backup_service.dart';
import 'catalog.dart';
import 'episode_state_provider.dart';
import 'main.dart';
import 'services/cover_storage/cover_image_loader.dart';
import 'services/cover_storage/cover_prefetch_service.dart';
import 'widgets/sinclair_cross_mark.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _cacheBytes = 0;
  int _cacheCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCache();
  }

  Future<void> _refreshCache() async {
    final values = await Future.wait([
      getCoverCacheSizeBytes(),
      getCachedCoverCount(),
    ]);
    if (mounted) {
      setState(() {
        _cacheBytes = values[0];
        _cacheCount = values[1];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen & Backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _heading('Darstellung'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_brightness),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('Hell'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('Dunkel'),
              ),
            ],
            selected: {theme.mode},
            onSelectionChanged: (value) => theme.setMode(value.first),
          ),
          const SizedBox(height: 14),
          Text('Akzentfarbe', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final palette in AppColorPalette.values)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: palette.seedColor),
                  label: Text(palette.label),
                  selected: theme.palette == palette,
                  onSelected: (_) => theme.setPalette(palette),
                ),
            ],
          ),
          const SizedBox(height: 26),
          _heading('Episodenkatalog'),
          Consumer<EpisodeStateProvider>(
            builder: (context, state, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${state.episodes.length} Hörspiele gespeichert'),
                const SizedBox(height: 4),
                Text(
                  state.lastCatalogCheck == null
                      ? 'Noch keine erfolgreiche Online-Prüfung'
                      : 'Zuletzt geprüft: ${DateFormat('dd.MM.yyyy HH:mm').format(state.lastCatalogCheck!.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Die App prüft beim Öffnen höchstens einmal täglich die offiziellen Reihen. Offline bleibt der gespeicherte Katalog verfügbar.',
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: state.checkingForUpdates
                      ? null
                      : () async {
                          final message = await context
                              .read<EpisodeStateProvider>()
                              .checkForCatalogUpdates(force: true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          }
                        },
                  icon: state.checkingForUpdates
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    state.checkingForUpdates
                        ? 'Prüfung läuft …'
                        : 'Jetzt auf neue Folgen prüfen',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _heading('Datensicherung'),
          const Text(
            'Gehört-Status, Bewertungen und Notizen lassen sich als JSON sichern.',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => BackupService.exportBackup(context),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Exportieren'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => BackupService.importBackup(
                    context,
                    context.read<EpisodeStateProvider>(),
                  ),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Importieren'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _heading('Offline-Cover'),
          Text(
            '$_cacheCount Cover · ${(_cacheBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<CoverWarmupProgress>(
            valueListenable: CoverWarmupService.instance.progressNotifier,
            builder: (context, progress, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (progress.isRunning) ...[
                  LinearProgressIndicator(value: progress.coverFraction),
                  const SizedBox(height: 6),
                  Text(
                    '${progress.completedCovers} / ${progress.totalCovers} Cover',
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: progress.isRunning
                      ? null
                      : () async {
                          await CoverWarmupService.instance
                              .restartWithFullDownload(
                            showInitializingState: true,
                          );
                          await _refreshCache();
                        },
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Alle Cover neu herunterladen'),
                ),
                TextButton.icon(
                  onPressed: progress.isRunning
                      ? null
                      : () async {
                          await clearPersistentCoverCache();
                          await _refreshCache();
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Cover-Cache leeren'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _heading('Quellen'),
          _link(
            'Offizieller John-Sinclair-Hörspielkatalog',
            officialCatalogUrl,
          ),
          _link('Episodenindex: Lübbe Audio', wikipediaLuebbeUrl),
          _link('Episodenindex: Tonstudio Braun', wikipediaBraunUrl),
          const SizedBox(height: 24),
          _heading('Über die App'),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SinclairCrossMark(size: 54),
            ),
          ),
          const Text(
            'Sinclair Tracker ist ein inoffizielles, nicht kommerzielles Fanprojekt. '
            'Es besteht keine Verbindung zu Bastei Lübbe, Lübbe Audio oder Jason Dark. '
            'Marken, Cover und Inhaltsangaben gehören ihren jeweiligen Rechteinhabern.',
          ),
          const SizedBox(height: 8),
          const Text('Version 1.1.0 · Fork des MIT-lizenzierten DDF Tracker'),
        ],
      ),
    );
  }

  Widget _heading(String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(value, style: Theme.of(context).textTheme.titleLarge),
      );

  Widget _link(String label, String url) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      );
}
