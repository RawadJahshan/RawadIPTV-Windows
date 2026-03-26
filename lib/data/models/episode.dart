import 'safe_parsing.dart';

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
    String seasonKey,
  ) {
    final info = SafeParsing.asMap(json['info']);
    final ext = SafeParsing.asString(
      json['container_extension'],
      fallback: 'mp4',
    );
    final streamId = SafeParsing.asString(
      json['id'] ?? json['episode_id'] ?? json['stream_id'],
      fallback: '0',
    );

    return Episode(
      id: SafeParsing.asInt(streamId),
      title: SafeParsing.asString(
        json['title'] ?? json['name'],
        fallback: 'Episode',
      ),
      streamUrl: '$serverUrl/series/$username/$password/$streamId.$ext',
      duration: SafeParsing.asString(info['duration']),
      plot: SafeParsing.asString(info['plot']),
      episodeNum: SafeParsing.asInt(
        json['episode_num'] ?? json['episode_number'],
      ),
      season: SafeParsing.asInt(
        json['season'] ?? json['season_num'] ?? seasonKey,
      ),
      containerExtension: ext,
    );
  }
}
