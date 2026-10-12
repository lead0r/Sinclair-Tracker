import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';

enum HeardFilter { all, heard, unheard }

enum EpisodeSort { number, newest, title, rating }

class EpisodeListPreferences extends ChangeNotifier {
  EpisodeListPreferences(this._preferences) {
    heardFilter = HeardFilter.values.firstWhere(
      (value) => value.name == _preferences.getString(_heardFilterKey),
      orElse: () => HeardFilter.all,
    );
    sort = EpisodeSort.values.firstWhere(
      (value) => value.name == _preferences.getString(_sortKey),
      orElse: () => EpisodeSort.number,
    );

    final savedRating = _preferences.getInt(_minimumRatingKey) ?? 0;
    minimumRating = savedRating < 0
        ? 0
        : savedRating > 5
            ? 5
            : savedRating;

    final savedSeries = _preferences.getString(_selectedSeriesKey);
    selectedSeriesId = seriesCatalog.any(
      (series) => series.id == savedSeries,
    )
        ? savedSeries!
        : seriesCatalog.first.id;
    query = _preferences.getString(_queryKey) ?? '';
  }

  static const _heardFilterKey = 'episode_list_heard_filter';
  static const _sortKey = 'episode_list_sort';
  static const _minimumRatingKey = 'episode_list_minimum_rating';
  static const _selectedSeriesKey = 'episode_list_selected_series';
  static const _queryKey = 'episode_list_query';

  final SharedPreferences _preferences;

  late HeardFilter heardFilter;
  late EpisodeSort sort;
  late int minimumRating;
  late String selectedSeriesId;
  late String query;

  Future<void> setHeardFilter(HeardFilter value) async {
    if (heardFilter == value) return;
    heardFilter = value;
    notifyListeners();
    await _preferences.setString(_heardFilterKey, value.name);
  }

  Future<void> setSort(EpisodeSort value) async {
    if (sort == value) return;
    sort = value;
    notifyListeners();
    await _preferences.setString(_sortKey, value.name);
  }

  Future<void> setMinimumRating(int value) async {
    final normalized = value < 0
        ? 0
        : value > 5
            ? 5
            : value;
    if (minimumRating == normalized) return;
    minimumRating = normalized;
    notifyListeners();
    await _preferences.setInt(_minimumRatingKey, normalized);
  }

  Future<void> setSelectedSeries(String seriesId) async {
    if (!seriesCatalog.any((series) => series.id == seriesId) ||
        selectedSeriesId == seriesId) {
      return;
    }
    selectedSeriesId = seriesId;
    notifyListeners();
    await _preferences.setString(_selectedSeriesKey, seriesId);
  }

  Future<void> setQuery(String value) async {
    if (query == value) return;
    query = value;
    notifyListeners();
    await _preferences.setString(_queryKey, value);
  }
}
