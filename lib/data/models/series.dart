class Series {
  final int id;
  final String name;
  final String logoUrl;
  final String rating;
  final String year;
  final String genre;
  final String plot;
  final String director;
  final String cast;

  Series({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.rating,
    required this.year,
    required this.genre,
    required this.plot,
    required this.director,
    required this.cast,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: int.tryParse(json['series_id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      logoUrl: json['cover']?.toString() ?? '',
      rating: json['rating']?.toString() ?? '0',
      year: json['year']?.toString() ?? '',
      genre: json['genre']?.toString() ?? '',
      plot: json['plot']?.toString() ?? '',
      director: json['director']?.toString() ?? '',
      cast: json['cast']?.toString() ?? '',
    );
  }
}