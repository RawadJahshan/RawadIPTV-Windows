class Episode {
  final int id;
  final String title;
  final String streamUrl;
  final String duration;
  final String plot;
  final int episodeNum;
  final int season;
  final String containerExtension;

  Episode({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.duration,
    required this.plot,
    required this.episodeNum,
    required this.season,
    required this.containerExtension,
  });

  factory Episode.fromJson(
    Map<String, dynamic> json,
    String serverUrl,
    String username,
    String password,
  ) {
    final streamId = json['id']?.toString() ?? '0';
    final ext = json['container_extension']?.toString() ?? 'mp4';
    return Episode(
      id: int.tryParse(streamId) ?? 0,
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          'Episode',
      streamUrl:
          '$serverUrl/series/$username/$password/$streamId.$ext',
      duration: json['info']?['duration']?.toString() ?? '',
      plot: json['info']?['plot']?.toString() ?? '',
      episodeNum:
          int.tryParse(json['episode_num']?.toString() ?? '0') ?? 0,
      season: int.tryParse(json['season']?.toString() ?? '0') ?? 0,
      containerExtension: ext,
    );
  }
}