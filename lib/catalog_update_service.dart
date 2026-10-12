import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'episode.dart';

class CatalogUpdateResult {
  const CatalogUpdateResult({
    required this.newEpisodes,
    required this.successfulSources,
    required this.failedSources,
  });

  final List<Episode> newEpisodes;
  final int successfulSources;
  final List<String> failedSources;
}

class CatalogUpdateService {
  CatalogUpdateService({http.Client? client, Set<String>? enabledSources})
      : _client = client ?? http.Client(),
        _sources = enabledSources == null
            ? _defaultSources
            : _defaultSources
                .where((source) => enabledSources.contains(source.key))
                .toList(growable: false);

  static const _userAgent =
      'SinclairTracker/1.1 (private, non-commercial catalogue client)';

  final http.Client _client;
  final List<_SeriesSource> _sources;

  void close() => _client.close();

  Future<CatalogUpdateResult> fetchUpdates(
    List<Episode> currentEpisodes,
  ) async {
    final sourceResults = await Future.wait(
      _sources.map((source) => _fetchSafely(source, currentEpisodes)),
    );
    final successful = sourceResults.where((result) => result.error == null);
    if (_sources.isNotEmpty && successful.isEmpty) {
      throw StateError('Keine Katalogquelle war erreichbar.');
    }

    final unique = <String, Episode>{};
    for (final result in successful) {
      for (final episode in result.episodes) {
        unique[episode.id] = episode;
      }
    }
    final episodes = unique.values.toList(growable: false)
      ..sort((a, b) {
        final series = a.series.compareTo(b.series);
        return series != 0 ? series : a.number.compareTo(b.number);
      });
    return CatalogUpdateResult(
      newEpisodes: episodes,
      successfulSources: successful.length,
      failedSources: [
        for (final result in sourceResults)
          if (result.error != null) result.source.label,
      ],
    );
  }

  Future<_SourceResult> _fetchSafely(
    _SeriesSource source,
    List<Episode> currentEpisodes,
  ) async {
    try {
      return _SourceResult(
        source: source,
        episodes: await _fetchSeries(source, currentEpisodes),
      );
    } catch (error) {
      return _SourceResult(source: source, error: error);
    }
  }

  Future<List<Episode>> _fetchSeries(
    _SeriesSource source,
    List<Episode> currentEpisodes,
  ) async {
    final relevant = currentEpisodes
        .where(
          (episode) =>
              episode.series == source.series &&
              (source.season == null || episode.season == source.season),
        )
        .toList(growable: false);
    final currentMaximum = _currentMaximum(source, relevant);
    final knownTitles =
        relevant.map((episode) => _normalize(episode.title)).toSet();
    final candidates = <int, _OfficialProduct>{};

    var page = 0;
    Uri? next = Uri.parse(source.url).replace(queryParameters: {'s': 'desc'});
    while (next != null && page < 10) {
      final document = await _fetchDocument(next);
      final products = _parseProducts(source, document);
      if (page == 0 && products.isEmpty) {
        throw StateError(
          'Die offizielle Seite für ${source.label} enthielt keine Folgen.',
        );
      }
      var foundKnownEpisode = false;
      for (final product in products) {
        if (_isKnown(source, relevant, product)) {
          foundKnownEpisode = true;
          continue;
        }
        if (knownTitles.contains(_normalize(product.title))) continue;
        if (product.number <= currentMaximum ||
            product.number > currentMaximum + 100) {
          continue;
        }
        candidates.putIfAbsent(product.number, () => product);
      }

      final nextHref = document
          .querySelector('a.pagination-control__more')
          ?.attributes['href'];
      next = foundKnownEpisode || nextHref == null
          ? null
          : Uri.parse(source.url).resolve(nextHref);
      page++;
    }

    final products = candidates.values.toList(growable: false)
      ..sort((a, b) => a.number.compareTo(b.number));
    final enriched = await Future.wait(
      products.map((product) => _enrichSafely(source, product)),
    );
    final nextSeriesNumber = currentEpisodes
        .where((episode) => episode.series == source.series)
        .fold<int>(
          0,
          (maximum, episode) =>
              episode.number > maximum ? episode.number : maximum,
        );

    return [
      for (var index = 0; index < enriched.length; index++)
        _toEpisode(
          source,
          enriched[index],
          source.isSpecial
              ? nextSeriesNumber + index + 1
              : source.season != null
                  ? source.seriesOffset + enriched[index].number
                  : enriched[index].number,
        ),
    ];
  }

  Future<_OfficialProduct> _enrichSafely(
    _SeriesSource source,
    _OfficialProduct product,
  ) async {
    final link = product.officialLink;
    if (link == null) return product;
    try {
      final document = await _fetchDocument(Uri.parse(link));
      final meta = _clean(
        document.querySelector('.product-meta-paragraph')?.text,
      );
      final description = _clean(document.querySelector('.rich-text p')?.text);
      final coverPath =
          document.querySelector('img.product__cover')?.attributes['src'];
      return product.copyWith(
        releaseDate: _parseReleaseDate(meta),
        description: description.isEmpty ? product.description : description,
        coverUrl: coverPath == null
            ? product.coverUrl
            : Uri.parse(source.url).resolve(coverPath).toString(),
      );
    } catch (_) {
      return product;
    }
  }

  Future<Document> _fetchDocument(Uri uri) async {
    final response = await _client.get(uri, headers: {
      'User-Agent': _userAgent
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw StateError('HTTP ${response.statusCode} für ${uri.host}');
    }
    return html_parser.parse(utf8.decode(response.bodyBytes));
  }

  List<_OfficialProduct> _parseProducts(
    _SeriesSource source,
    Document document,
  ) {
    final products = <_OfficialProduct>[];
    final seen = <String>{};
    for (final article in document.querySelectorAll('article.list-item')) {
      final number = int.tryParse(
        _clean(article.querySelector('.product-number__count')?.text),
      );
      if (number == null) continue;
      final headingLink = article.querySelector('.headline a.link') ??
          article.querySelector('.headline a');
      final heading = _clean(headingLink?.text);
      final subline = _clean(
        article.querySelector('.text-header__subline')?.text,
      );
      final title = source.isSpecial ? _stripBrand(heading) : subline;
      if (title.isEmpty || title.toLowerCase().startsWith('folgen ')) continue;
      final key = '$number:${_normalize(title)}';
      if (!seen.add(key)) continue;

      final coverPath =
          article.querySelector('img.product__cover')?.attributes['src'];
      final href = headingLink?.attributes['href'];
      products.add(
        _OfficialProduct(
          number: number,
          title: title,
          description: _clean(
            article.querySelector('.product-result__details .paragraph')?.text,
          ),
          coverUrl: coverPath == null
              ? null
              : Uri.parse(source.url)
                  .resolve(
                    coverPath.replaceFirst(
                      '/site/thumbnails/225/',
                      '/site/thumbnails/736/',
                    ),
                  )
                  .toString(),
          officialLink: href == null
              ? null
              : Uri.parse(source.url).resolve(href).toString(),
        ),
      );
    }
    return products;
  }

  bool _isKnown(
    _SeriesSource source,
    List<Episode> relevant,
    _OfficialProduct product,
  ) {
    return relevant.any((episode) {
      if (_normalize(episode.title) == _normalize(product.title)) return true;
      if (source.season != null) return episode.seasonNumber == product.number;
      if (source.isSpecial) {
        return int.tryParse(episode.displayNumber) == product.number;
      }
      return episode.number == product.number;
    });
  }

  int _currentMaximum(_SeriesSource source, List<Episode> episodes) {
    var maximum = 0;
    for (final episode in episodes) {
      var value = source.season != null
          ? episode.seasonNumber ?? -1
          : source.isSpecial
              ? int.tryParse(episode.displayNumber) ?? -1
              : episode.number;
      // "2000 – Das Höllenkreuz" is a named one-off special, not episode
      // 2000 of the consecutively numbered special editions.
      if (source.isSpecial && value >= 1000) value = -1;
      if (value > maximum) maximum = value;
    }
    return maximum;
  }

  Episode _toEpisode(
    _SeriesSource source,
    _OfficialProduct product,
    int seriesNumber,
  ) {
    final displayNumber = source.season == null
        ? product.number.toString()
        : seriesNumber.toString();
    final template = source.season == null
        ? '${source.seriesName} · Folge ${product.number}'
        : 'SINCLAIR · Staffel ${source.season} · Folge ${product.number}';
    return Episode(
      id: '${source.series}_$displayNumber',
      series: source.series,
      number: seriesNumber,
      displayNumber: displayNumber,
      title: product.title,
      author: source.season == null ? 'Jason Dark' : 'Dennis Ehrhardt',
      description: product.description,
      director: '',
      script: '',
      releaseDate: product.releaseDate,
      coverUrl: product.coverUrl,
      template: template,
      season: source.season,
      seasonNumber: source.season == null ? null : product.number,
      links: _providerLinks(product, displayNumber),
    );
  }

  Map<String, String> _providerLinks(
    _OfficialProduct product,
    String displayNumber,
  ) {
    final query = 'John Sinclair $displayNumber ${product.title}';
    final encodedPath = Uri.encodeComponent(query);
    final encodedQuery = Uri.encodeQueryComponent(query);
    return {
      if (product.officialLink != null) 'official': product.officialLink!,
      'spotify': 'https://open.spotify.com/search/$encodedPath',
      'appleMusic': 'https://music.apple.com/de/search?term=$encodedQuery',
      'amazonMusic': 'https://music.amazon.de/search/$encodedPath',
      'audible': 'https://www.audible.de/search?keywords=$encodedQuery',
      'youtubeMusic': 'https://music.youtube.com/search?q=$encodedQuery',
    };
  }

  DateTime? _parseReleaseDate(String value) {
    final match = RegExp(
      r'Ersterscheinung:\s*(\d{1,2})\.(\d{1,2})\.(\d{4})',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }

  String _stripBrand(String value) => value.replaceFirst(
        RegExp(r'^John Sinclair\s*[-–:]\s*', caseSensitive: false),
        '',
      );

  String _clean(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß]+'), '');
}

class _OfficialProduct {
  const _OfficialProduct({
    required this.number,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.officialLink,
    this.releaseDate,
  });

  final int number;
  final String title;
  final String description;
  final String? coverUrl;
  final String? officialLink;
  final DateTime? releaseDate;

  _OfficialProduct copyWith({
    String? description,
    String? coverUrl,
    DateTime? releaseDate,
  }) =>
      _OfficialProduct(
        number: number,
        title: title,
        description: description ?? this.description,
        coverUrl: coverUrl ?? this.coverUrl,
        officialLink: officialLink,
        releaseDate: releaseDate ?? this.releaseDate,
      );
}

class _SourceResult {
  const _SourceResult({
    required this.source,
    this.episodes = const [],
    this.error,
  });

  final _SeriesSource source;
  final List<Episode> episodes;
  final Object? error;
}

class _SeriesSource {
  const _SeriesSource({
    required this.key,
    required this.label,
    required this.series,
    required this.seriesName,
    required this.url,
    this.season,
    this.isSpecial = false,
    this.seriesOffset = 0,
  });

  final String key;
  final String label;
  final String series;
  final String seriesName;
  final String url;
  final int? season;
  final bool isSpecial;
  final int seriesOffset;
}

const _defaultSources = <_SeriesSource>[
  _SeriesSource(
    key: 'edition2000',
    label: 'Edition 2000',
    series: 'edition2000',
    seriesName: 'Edition 2000',
    url:
        'https://www.john-sinclair.de/serie/geisterjaeger-john-sinclair/2189646',
  ),
  _SeriesSource(
    key: 'classics',
    label: 'Sinclair Classics',
    series: 'classics',
    seriesName: 'Sinclair Classics',
    url:
        'https://www.john-sinclair.de/serie/geisterjaeger-john-sinclair-classics/2189562',
  ),
  _SeriesSource(
    key: 'specials',
    label: 'Sondereditionen',
    series: 'specials',
    seriesName: 'Sondereditionen',
    url:
        'https://www.john-sinclair.de/serie/john-sinclair-hoerspiel-sonderedition/2746036',
    isSpecial: true,
  ),
  _SeriesSource(
    key: 'tonstudio_braun',
    label: 'Tonstudio Braun',
    series: 'tonstudio_braun',
    seriesName: 'Tonstudio Braun',
    url:
        'https://www.john-sinclair.de/serie/john-sinclair-tonstudio-braun/2476668',
  ),
  _SeriesSource(
    key: 'dead_zone',
    label: 'SINCLAIR: Dead Zone',
    series: 'sinclair_reboot',
    seriesName: 'SINCLAIR',
    url:
        'https://www.john-sinclair.de/serie/sinclair-staffel-01-dead-zone/2781722',
    season: 1,
  ),
  _SeriesSource(
    key: 'underworld',
    label: 'SINCLAIR: Underworld',
    series: 'sinclair_reboot',
    seriesName: 'SINCLAIR',
    url:
        'https://www.john-sinclair.de/serie/sinclair-staffel-2-underworld/3622433',
    season: 2,
    seriesOffset: 7,
  ),
];
