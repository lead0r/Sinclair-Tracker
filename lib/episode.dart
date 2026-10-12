class Episode {
  const Episode({
    required this.id,
    required this.series,
    required this.number,
    required this.displayNumber,
    required this.title,
    required this.author,
    required this.description,
    required this.director,
    required this.script,
    required this.template,
    required this.links,
    this.releaseDate,
    this.coverUrl,
    this.season,
    this.seasonNumber,
    this.rating = 0,
    this.listened = false,
    this.note = '',
  });

  final String id;
  final String series;
  final int number;
  final String displayNumber;
  final String title;
  final String author;
  final String description;
  final String director;
  final String script;
  final DateTime? releaseDate;
  final String? coverUrl;
  final String template;
  final int? season;
  final int? seasonNumber;
  final int rating;
  final bool listened;
  final String note;
  final Map<String, String> links;

  String get formattedTitle => '$displayNumber · $title';

  bool get isFutureRelease =>
      releaseDate != null && releaseDate!.isAfter(DateTime.now());

  factory Episode.fromJson(Map<String, dynamic> json) {
    final rawLinks =
        (json['links'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Episode(
      id: json['id'] as String,
      series: json['series'] as String,
      number: (json['number'] as num).toInt(),
      displayNumber: json['displayNumber'].toString(),
      title: json['title'] as String,
      author: (json['author'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      director: (json['director'] as String?) ?? '',
      script: (json['script'] as String?) ?? '',
      releaseDate: json['releaseDate'] == null
          ? null
          : DateTime.tryParse(json['releaseDate'].toString()),
      coverUrl: json['coverUrl'] as String?,
      template: (json['template'] as String?) ?? '',
      season: (json['season'] as num?)?.toInt(),
      seasonNumber: (json['seasonNumber'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      listened: json['listened'] as bool? ?? false,
      note: json['note'] as String? ?? '',
      links: rawLinks.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  Episode copyWith({int? rating, bool? listened, String? note}) => Episode(
        id: id,
        series: series,
        number: number,
        displayNumber: displayNumber,
        title: title,
        author: author,
        description: description,
        director: director,
        script: script,
        releaseDate: releaseDate,
        coverUrl: coverUrl,
        template: template,
        season: season,
        seasonNumber: seasonNumber,
        rating: rating ?? this.rating,
        listened: listened ?? this.listened,
        note: note ?? this.note,
        links: links,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'series': series,
        'number': number,
        'displayNumber': displayNumber,
        'title': title,
        'author': author,
        'description': description,
        'director': director,
        'script': script,
        'releaseDate': releaseDate?.toIso8601String(),
        'coverUrl': coverUrl,
        'template': template,
        'season': season,
        'seasonNumber': seasonNumber,
        'rating': rating,
        'listened': listened,
        'note': note,
        'links': links,
      };
}
