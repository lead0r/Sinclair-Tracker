import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sinclair_tracker/catalog_update_service.dart';
import 'package:sinclair_tracker/episode.dart';

void main() {
  test('official Edition 2000 page adds announced episodes', () async {
    final client = MockClient((request) async {
      if (request.url.path.startsWith('/produkt/')) {
        return _htmlResponse('''
          <p class="product-meta-paragraph">Ersterscheinung: 27.02.2027</p>
          <div class="rich-text"><p>Vollständige Inhaltsangabe.</p></div>
          <img class="product__cover" src="/site/thumbnails/736/cover.jpg">
        ''');
      }
      return _htmlResponse('''
        ${_editionArticle(199, 'Das Bluthaus')}
        ${_editionArticle(198, 'Medusas Rache')}
        ${_editionArticle(197, 'Der Horror-Helikopter')}
        ${_editionArticle(196, 'Die Maske')}
      ''');
    });
    final service = CatalogUpdateService(
      client: client,
      enabledSources: const {'edition2000'},
    );

    final result = await service.fetchUpdates([
      _episode(
        id: 'edition2000_196',
        series: 'edition2000',
        number: 196,
        displayNumber: '196',
        title: 'Die Maske',
      ),
    ]);

    expect(result.successfulSources, 1);
    expect(result.failedSources, isEmpty);
    expect(result.newEpisodes.map((episode) => episode.id), [
      'edition2000_197',
      'edition2000_198',
      'edition2000_199',
    ]);
    expect(result.newEpisodes.first.title, 'Der Horror-Helikopter');
    expect(result.newEpisodes.first.releaseDate, DateTime(2027, 2, 27));
    expect(result.newEpisodes.first.description, 'Vollständige Inhaltsangabe.');
    expect(
      result.newEpisodes.first.links['official'],
      'https://www.john-sinclair.de/produkt/197',
    );
  });

  test('special 2000 does not block the next numbered special', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/special/19') {
        return _htmlResponse('''
          <p class="product-meta-paragraph">Ersterscheinung: 31.10.2026</p>
          <div class="rich-text"><p>Eine neue Sonderedition.</p></div>
        ''');
      }
      return _htmlResponse('''
        ${_specialArticle(2000, 'John Sinclair - Das Höllenkreuz')}
        ${_specialArticle(19, 'John Sinclair - Nacht der Schatten')}
        ${_specialArticle(18, 'John Sinclair - Horror-Disco')}
      ''');
    });
    final service = CatalogUpdateService(
      client: client,
      enabledSources: const {'specials'},
    );

    final result = await service.fetchUpdates([
      _episode(
        id: 'specials_18',
        series: 'specials',
        number: 20,
        displayNumber: '18',
        title: 'Horror-Disco',
      ),
      _episode(
        id: 'specials_2000',
        series: 'specials',
        number: 21,
        displayNumber: '2000',
        title: 'Das Höllenkreuz',
      ),
    ]);

    expect(result.newEpisodes, hasLength(1));
    expect(result.newEpisodes.single.id, 'specials_19');
    expect(result.newEpisodes.single.number, 22);
    expect(result.newEpisodes.single.displayNumber, '19');
    expect(result.newEpisodes.single.title, 'Nacht der Schatten');
  });

  test(
    'changed or unavailable official page keeps offline catalogue',
    () async {
      final service = CatalogUpdateService(
        client: MockClient((_) async => _htmlResponse('<html></html>')),
        enabledSources: const {'edition2000'},
      );

      await expectLater(
        service.fetchUpdates(const []),
        throwsA(isA<StateError>()),
      );
    },
  );
}

String _editionArticle(int number, String title) => '''
  <article class="list-item">
    <span class="product-number__count">$number</span>
    <div class="text-header__subline">$title</div>
    <h2 class="headline">
      <a class="link" href="/produkt/$number">John Sinclair $number</a>
    </h2>
    <div class="product-result__details"><p class="paragraph">Kurztext.</p></div>
    <img class="product__cover" src="/site/thumbnails/225/$number.jpg">
  </article>
''';

String _specialArticle(int number, String title) => '''
  <article class="list-item">
    <span class="product-number__count">$number</span>
    <div class="text-header__subline">Sonderedition $number</div>
    <h2 class="headline">
      <a class="link" href="/special/$number">$title</a>
    </h2>
    <div class="product-result__details"><p class="paragraph">Kurztext.</p></div>
  </article>
''';

http.Response _htmlResponse(String body) => http.Response.bytes(
      utf8.encode(body),
      200,
      headers: const {'content-type': 'text/html; charset=utf-8'},
    );

Episode _episode({
  required String id,
  required String series,
  required int number,
  required String displayNumber,
  required String title,
}) =>
    Episode(
      id: id,
      series: series,
      number: number,
      displayNumber: displayNumber,
      title: title,
      author: '',
      description: '',
      director: '',
      script: '',
      template: '',
      links: const {},
    );
