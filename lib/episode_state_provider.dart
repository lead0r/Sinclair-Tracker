import 'dart:async';

import 'package:flutter/foundation.dart';

import 'catalog_update_service.dart';
import 'database_service.dart';
import 'episode.dart';
import 'episode_data_service.dart';
import 'services/cover_storage/cover_prefetch_service.dart';

class EpisodeStateProvider extends ChangeNotifier {
  EpisodeStateProvider({
    EpisodeDataService? dataService,
    DatabaseService? databaseService,
    CatalogUpdateService? updateService,
  })  : _dataService = dataService ?? EpisodeDataService(),
        _databaseService = databaseService ?? DatabaseService.instance,
        _updateService = updateService ?? CatalogUpdateService();

  final EpisodeDataService _dataService;
  final DatabaseService _databaseService;
  final CatalogUpdateService _updateService;

  List<Episode> _episodes = const [];
  bool _loading = false;
  Object? _error;
  bool _checkingForUpdates = false;
  DateTime? _lastCatalogCheck;
  String? _catalogUpdateMessage;

  List<Episode> get episodes => _episodes;
  bool get loading => _loading;
  Object? get error => _error;
  bool get checkingForUpdates => _checkingForUpdates;
  DateTime? get lastCatalogCheck => _lastCatalogCheck;
  String? get catalogUpdateMessage => _catalogUpdateMessage;

  @override
  void dispose() {
    _updateService.close();
    super.dispose();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    var loaded = false;
    try {
      final catalogue = await _dataService.fetchAllEpisodes();
      _lastCatalogCheck = await _dataService.getLastCatalogCheck();
      final states = await _databaseService.loadStates();
      _episodes = catalogue.map((episode) {
        return _withStoredState(episode, states[episode.id]);
      }).toList(growable: false);
      await CoverWarmupService.instance.handleNewEpisodes(_episodes);
      loaded = true;
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
    if (loaded) unawaited(checkForCatalogUpdates());
  }

  Future<String> checkForCatalogUpdates({bool force = false}) async {
    if (_checkingForUpdates) return 'Die Prüfung läuft bereits.';
    final now = DateTime.now().toUtc();
    if (!force &&
        _lastCatalogCheck != null &&
        now.difference(_lastCatalogCheck!) < const Duration(hours: 24)) {
      return 'Der Katalog wurde heute bereits geprüft.';
    }

    _checkingForUpdates = true;
    _catalogUpdateMessage = null;
    notifyListeners();
    try {
      final result = await _updateService.fetchUpdates(_episodes);
      if (result.newEpisodes.isNotEmpty) {
        await _dataService.saveCachedAdditions(result.newEpisodes);
        final states = await _databaseService.loadStates();
        _episodes = mergeEpisodeCatalogues(_episodes, result.newEpisodes)
            .map((episode) => _withStoredState(episode, states[episode.id]))
            .toList(growable: false);
        await CoverWarmupService.instance.handleNewEpisodes(_episodes);
      }
      if (result.failedSources.isEmpty) {
        await _dataService.setLastCatalogCheck(now);
        _lastCatalogCheck = now;
      }
      final count = result.newEpisodes.length;
      final base = count == 0
          ? 'Keine neuen Folgen gefunden.'
          : '$count neue ${count == 1 ? 'Folge' : 'Folgen'} hinzugefügt.';
      final warning = result.failedSources.isEmpty
          ? ''
          : ' ${result.failedSources.length} ${result.failedSources.length == 1 ? 'Reihe war' : 'Reihen waren'} nicht erreichbar.';
      _catalogUpdateMessage = '$base$warning';
      return _catalogUpdateMessage!;
    } catch (_) {
      _catalogUpdateMessage =
          'Online-Prüfung nicht möglich. Der gespeicherte Katalog bleibt erhalten.';
      return _catalogUpdateMessage!;
    } finally {
      _checkingForUpdates = false;
      notifyListeners();
    }
  }

  Episode? byId(String id) {
    for (final episode in _episodes) {
      if (episode.id == id) return episode;
    }
    return null;
  }

  Episode _withStoredState(Episode episode, EpisodeState? state) {
    if (state == null) return episode;
    return episode.copyWith(
      rating: state.rating,
      listened: state.listened,
      note: state.note,
    );
  }

  Future<void> updateEpisode(
    String id, {
    int? rating,
    bool? listened,
    String? note,
  }) async {
    final index = _episodes.indexWhere((episode) => episode.id == id);
    if (index < 0) return;
    final updated = _episodes[index].copyWith(
      rating: rating,
      listened: listened,
      note: note,
    );
    _episodes = [..._episodes]..[index] = updated;
    notifyListeners();
    await _databaseService.saveEpisode(updated);
  }
}
