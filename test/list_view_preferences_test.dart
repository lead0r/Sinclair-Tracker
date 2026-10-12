import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinclair_tracker/list_view_preferences.dart';

void main() {
  test('list view preferences survive a restart', () async {
    SharedPreferences.setMockInitialValues({
      'episode_list_heard_filter': 'unheard',
      'episode_list_sort': 'newest',
      'episode_list_minimum_rating': 3,
      'episode_list_selected_series': 'classics',
      'episode_list_query': 'Vampir',
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = EpisodeListPreferences(preferences);

    expect(controller.heardFilter, HeardFilter.unheard);
    expect(controller.sort, EpisodeSort.newest);
    expect(controller.minimumRating, 3);
    expect(controller.selectedSeriesId, 'classics');
    expect(controller.query, 'Vampir');

    await controller.setHeardFilter(HeardFilter.heard);
    await controller.setSort(EpisodeSort.rating);
    await controller.setMinimumRating(5);
    await controller.setSelectedSeries('specials');
    await controller.setQuery('Kreuz');

    final restored = EpisodeListPreferences(preferences);
    expect(restored.heardFilter, HeardFilter.heard);
    expect(restored.sort, EpisodeSort.rating);
    expect(restored.minimumRating, 5);
    expect(restored.selectedSeriesId, 'specials');
    expect(restored.query, 'Kreuz');
  });

  test('invalid saved values fall back safely', () async {
    SharedPreferences.setMockInitialValues({
      'episode_list_heard_filter': 'invalid',
      'episode_list_sort': 'invalid',
      'episode_list_minimum_rating': 99,
      'episode_list_selected_series': 'invalid',
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = EpisodeListPreferences(preferences);

    expect(controller.heardFilter, HeardFilter.all);
    expect(controller.sort, EpisodeSort.number);
    expect(controller.minimumRating, 5);
    expect(controller.selectedSeriesId, 'edition2000');
  });
}
