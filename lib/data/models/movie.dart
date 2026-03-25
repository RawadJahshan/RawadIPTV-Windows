class Movie {
  final int id;
  final String name;
  final String streamUrl;
  final String logoUrl;
  final String rating;
  final String year;
  final String genre;
  final String plot;
  final String director;
  final String cast;
  final String duration;
  final String containerExtension;

  Movie({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.logoUrl,
    required this.rating,
    required this.year,
    required this.genre,
    required this.plot,
    required this.director,
    required this.cast,
    required this.duration,
    required this.containerExtension,
  });

  factory Movie.fromJson(
    Map<String, dynamic> json,
    String serverUrl,
    String username,
    String password,
  ) {
    final streamId = json['stream_id']?.toString() ?? '0';
    final ext = json['container_extension']?.toString() ?? 'mp4';
    return Movie(
      id: int.tryParse(streamId) ?? 0,
      name: json['name']?.toString() ?? '',
      streamUrl:
          '$serverUrl/movie/$username/$password/$streamId.$ext',
      logoUrl: json['stream_icon']?.toString() ?? '',
      rating: json['rating']?.toString() ?? '0',
      year: json['year']?.toString() ?? '',
      genre: json['genre']?.toString() ?? '',
      plot: json['plot']?.toString() ?? '',
      director: json['director']?.toString() ?? '',
      cast: json['cast']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      containerExtension: ext,
    );
  }
}