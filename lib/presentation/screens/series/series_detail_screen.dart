import 'package:flutter/material.dart';

import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/episode.dart';
import '../../../data/models/series.dart';
import '../../../data/services/performance_logger.dart';
import '../../../data/services/watch_progress_service.dart';
import '../../../utils/favorites_manager.dart';
import '../player/fullscreen_player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  final Series series;

  const SeriesDetailScreen({super.key, required this.xtreamApi, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  bool _isFavorite = false;
  Map<String, dynamic>? _info;
  Map<String, List<Episode>> _episodesBySeason = {};
  final Map<int, Map<String, dynamic>?> _progressByEpisode = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sw = Stopwatch()..start();
    _isFavorite = await FavoritesManager.isFavoriteSeries(widget.series.id.toString());
    if (mounted) setState(() {});
    final info = await widget.xtreamApi.getSeriesInfo(widget.series.id);
    PerformanceLogger.log('series_metadata_fetch_duration', sw.elapsed, details: widget.series.name);

    final parsed = <String, List<Episode>>{};
    final rawEpisodes = info['episodes'];
    if (rawEpisodes is Map) {
      for (final entry in rawEpisodes.entries) {
        final season = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          parsed[season] = value
              .map((e) => Episode.fromJson(
                    Map<String, dynamic>.from(e as Map),
                    widget.xtreamApi.serverUrl,
                    widget.xtreamApi.username,
                    widget.xtreamApi.password,
                  ))
              .toList();
        }
      }
    }

    for (final e in parsed.values.expand((x) => x)) {
      _progressByEpisode[e.id] = await WatchProgressService.getEpisodeProgress(e.id);
    }

    if (mounted) {
      setState(() {
        _info = info;
        _episodesBySeason = parsed;
      });
    }
  }

  Future<void> _playEpisode(Episode episode) async {
    final sw = Stopwatch()..start();
    Duration? startAt;
    final progress = _progressByEpisode[episode.id];
    final positionMs = int.tryParse('${progress?['position_ms']}') ?? 0;
    final durationMs = int.tryParse('${progress?['duration_ms']}') ?? 0;
    if (positionMs > 0 && durationMs > 0 && positionMs < durationMs) {
      final resume = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Resume Playback'),
          content: Text('Resume from ${_format(Duration(milliseconds: positionMs))}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Start Over')),
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resume')),
          ],
        ),
      );
      if (resume == null) return;
      if (resume) startAt = Duration(milliseconds: positionMs);
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenPlayerScreen(
          args: FullscreenPlayerArgs(
            title: episode.title,
            streamUrl: episode.streamUrl,
            type: PlaybackType.episode,
            contentId: episode.id,
            seriesId: widget.series.id,
            seriesName: widget.series.name,
            seasonNumber: episode.season,
            episodeNumber: episode.episodeNum,
            startAt: startAt,
            triggerElapsed: sw.elapsed,
          ),
        ),
      ),
    );
    _progressByEpisode[episode.id] = await WatchProgressService.getEpisodeProgress(episode.id);
    if (mounted) setState(() {});
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoritesManager.removeFavoriteSeries(widget.series.id.toString());
    } else {
      await FavoritesManager.addFavoriteSeries(widget.series.id.toString());
    }
    if (mounted) setState(() => _isFavorite = !_isFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final info = (_info?['info'] is Map) ? Map<String, dynamic>.from(_info!['info'] as Map) : <String, dynamic>{};
    final backdrop = info['backdrop_path']?.toString();

    return Scaffold(
      body: Stack(
        children: [
          if (backdrop != null && backdrop.isNotEmpty) Positioned.fill(child: Image.network(backdrop, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.78))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(widget.series.logoUrl, width: 220, height: 330, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.series.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(info['plot']?.toString().isNotEmpty == true ? info['plot'].toString() : widget.series.plot),
                          const SizedBox(height: 12),
                          Text('Genre: ${info['genre'] ?? widget.series.genre}'),
                          Text('Rating: ${info['rating'] ?? widget.series.rating}'),
                          Text('Cast: ${info['cast'] ?? widget.series.cast}'),
                          Text('Director: ${info['director'] ?? widget.series.director}'),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _toggleFavorite,
                            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
                            label: Text(_isFavorite ? 'Favorited' : 'Favorite'),
                          )
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                ..._episodesBySeason.entries.map(
                  (entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Season ${entry.key}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...entry.value.map((episode) {
                        final progress = _progressByEpisode[episode.id];
                        final position = int.tryParse('${progress?['position_ms']}') ?? 0;
                        final duration = int.tryParse('${progress?['duration_ms']}') ?? 0;
                        final ratio = duration <= 0 ? 0.0 : (position / duration).clamp(0.0, 1.0);
                        final completed = (progress?['completed'] as bool?) == true;
                        return Card(
                          color: const Color(0xFF202030),
                          child: ListTile(
                            title: Text('E${episode.episodeNum} • ${episode.title}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (episode.duration.isNotEmpty) Text('Duration: ${episode.duration}'),
                                if (ratio > 0) LinearProgressIndicator(value: ratio),
                                if (progress != null)
                                  Text(completed ? 'Completed' : 'Remaining ${_format(Duration(milliseconds: duration - position))}'),
                              ],
                            ),
                            trailing: const Icon(Icons.play_arrow),
                            onTap: () => _playEpisode(episode),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
