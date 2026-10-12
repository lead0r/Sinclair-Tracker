import 'package:flutter/material.dart';

class SeriesInfo {
  const SeriesInfo({
    required this.id,
    required this.name,
    required this.shortName,
    required this.icon,
  });

  final String id;
  final String name;
  final String shortName;
  final IconData icon;
}

const seriesCatalog = <SeriesInfo>[
  SeriesInfo(
    id: 'edition2000',
    name: 'Edition 2000',
    shortName: '2000',
    icon: Icons.auto_stories,
  ),
  SeriesInfo(
    id: 'classics',
    name: 'Sinclair Classics',
    shortName: 'Classics',
    icon: Icons.history,
  ),
  SeriesInfo(
    id: 'specials',
    name: 'Sondereditionen',
    shortName: 'Specials',
    icon: Icons.star_outline,
  ),
  SeriesInfo(
    id: 'tonstudio_braun',
    name: 'Tonstudio Braun',
    shortName: 'Braun',
    icon: Icons.album_outlined,
  ),
  SeriesInfo(
    id: 'sinclair_reboot',
    name: 'SINCLAIR',
    shortName: 'SINCLAIR',
    icon: Icons.bolt,
  ),
];

SeriesInfo seriesInfo(String id) => seriesCatalog.firstWhere(
      (series) => series.id == id,
      orElse: () => SeriesInfo(
        id: id,
        name: id,
        shortName: id,
        icon: Icons.library_music_outlined,
      ),
    );

const officialCatalogUrl = 'https://www.john-sinclair.de/produkte/hoerspiele';
const wikipediaLuebbeUrl =
    'https://de.wikipedia.org/wiki/Geisterj%C3%A4ger_John_Sinclair_(H%C3%B6rspielserie_von_L%C3%BCbbe-Audio)';
const wikipediaBraunUrl =
    'https://de.wikipedia.org/wiki/Geisterj%C3%A4ger_John_Sinclair_(H%C3%B6rspielserie_von_Tonstudio_Braun)';
