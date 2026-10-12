import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinclair_tracker/episode.dart';
import 'package:sinclair_tracker/episode_detail_page.dart';
import 'package:sinclair_tracker/episode_list_page.dart';
import 'package:sinclair_tracker/episode_state_provider.dart';
import 'package:sinclair_tracker/list_view_preferences.dart';
import 'package:sinclair_tracker/random_episode_page.dart';
import 'package:sinclair_tracker/settings_page.dart';
import 'package:sinclair_tracker/statistics_page.dart';
import 'package:sinclair_tracker/widgets/persistent_cover_image.dart';
import 'package:sinclair_tracker/widgets/square_cover_image.dart';

void main() {
  test('all main screens can be constructed', () {
    expect(const EpisodeListPage(), isNotNull);
    expect(const EpisodeDetailPage(episodeId: 'edition2000_1'), isNotNull);
    expect(const RandomEpisodePage(), isNotNull);
    expect(const StatisticsPage(), isNotNull);
    expect(const SettingsPage(), isNotNull);
  });

  testWidgets('cover frame is square and does not crop its image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SquareCoverImage(
            imageUrl: null,
            size: 123,
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(SquareCoverImage)), const Size(123, 123));
    expect(
      const PersistentCoverImage(imageUrl: 'cover').fit,
      BoxFit.contain,
    );
  });

  testWidgets('episode list opens a dated episode detail', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final episode = Episode(
      id: 'edition2000_1',
      series: 'edition2000',
      number: 1,
      displayNumber: '1',
      title: 'Im Nachtclub der Vampire',
      author: 'Jason Dark',
      description: 'Testbeschreibung',
      director: '',
      script: '',
      releaseDate: DateTime(2000, 10, 30),
      coverUrl: null,
      template: 'Hörspiel',
      links: const {},
    );
    final state = _FakeEpisodeStateProvider(episode);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EpisodeStateProvider>.value(value: state),
          ChangeNotifierProvider(
            create: (_) => EpisodeListPreferences(preferences),
          ),
        ],
        child: const MaterialApp(home: EpisodeListPage()),
      ),
    );
    await tester.tap(find.text('1 · Im Nachtclub der Vampire'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Im Nachtclub der Vampire'), findsOneWidget);
    expect(find.text('Veröffentlicht am 30.10.2000'), findsOneWidget);
  });
}

class _FakeEpisodeStateProvider extends EpisodeStateProvider {
  _FakeEpisodeStateProvider(this.episode);

  final Episode episode;

  @override
  List<Episode> get episodes => [episode];

  @override
  Episode? byId(String id) => id == episode.id ? episode : null;
}
