import 'package:flutter/material.dart';

import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/episode.dart';
import '../../../data/models/safe_parsing.dart';
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
  String? _selectedSeason;
  bool _isLaunchingPlayer = false;

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

    final parsed = _parseEpisodesBySeason(info);
    final seasonOrder = _buildSeasonOrder(info, parsed);

    for (final e in parsed.values.expand((x) => x)) {
      _progressByEpisode[e.id] = await WatchProgressService.getEpisodeProgress(e.id);
    }

    if (!mounted) return;
    setState(() {
      _info = info;
      _episodesBySeason = parsed;
      _selectedSeason = seasonOrder.isNotEmpty ? seasonOrder.first : null;
    });
  }

  Map<String, List<Episode>> _parseEpisodesBySeason(Map<String, dynamic> info) {
    final output = <String, List<Episode>>{};
    final rawEpisodes = info['episodes'];

    if (rawEpisodes is Map) {
      for (final entry in rawEpisodes.entries) {
        final seasonKey = SafeParsing.asString(entry.key);
        final episodeItems = SafeParsing.asListFlexible(entry.value);
        final episodes = <Episode>[];

        for (final item in episodeItems) {
          final rawEpisode = SafeParsing.asMap(item);
          if (rawEpisode.isEmpty) continue;

          final episode = Episode.fromJson(
            rawEpisode,
            widget.xtreamApi.serverUrl,
            widget.xtreamApi.username,
            widget.xtreamApi.password,
            seasonKey,
          );
          if (episode.id > 0) episodes.add(episode);
        }

        if (episodes.isNotEmpty) {
          output[seasonKey] = episodes;
        }
      }
    } else if (rawEpisodes is List) {
      for (final item in rawEpisodes) {
        final rawEpisode = SafeParsing.asMap(item);
        if (rawEpisode.isEmpty) continue;
        final info = SafeParsing.asMap(rawEpisode['info']);
        final seasonKey = SafeParsing.asString(
          rawEpisode['season'] ?? rawEpisode['season_num'] ?? info['season'],
          fallback: '1',
        );
        final episode = Episode.fromJson(
          rawEpisode,
          widget.xtreamApi.serverUrl,
          widget.xtreamApi.username,
          widget.xtreamApi.password,
          seasonKey,
        );
        if (episode.id <= 0) continue;
        output.putIfAbsent(seasonKey, () => <Episode>[]).add(episode);
      }
    }

    return output;
  }

  List<String> _buildSeasonOrder(Map<String, dynamic> info, Map<String, List<Episode>> parsed) {
    final fromSeasons = <String>[];
    for (final seasonData in SafeParsing.asList(info['seasons'])) {
      final season = SafeParsing.asMap(seasonData);
      if (season.isEmpty) continue;
      final seasonNumber = SafeParsing.asString(
        season['season_number'] ?? season['season'] ?? season['name'],
      );
      if (seasonNumber.isNotEmpty) fromSeasons.add(seasonNumber);
    }

    final all = <String>{...fromSeasons, ...parsed.keys};
    final sortable = all.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a);
        final bi = int.tryParse(b);
        if (ai != null && bi != null) return ai.compareTo(bi);
        return a.compareTo(b);
      });

    return sortable;
  }

  Future<void> _playEpisode(Episode episode) async {
    if (_isLaunchingPlayer) return;
    setState(() => _isLaunchingPlayer = true);
    final sw = Stopwatch()..start();
    PerformanceLogger.log('play_button_pressed', Duration.zero, details: episode.title);
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

    try {
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
    } finally {
      if (mounted) {
        setState(() => _isLaunchingPlayer = false);
      } else {
        _isLaunchingPlayer = false;
      }
    }
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
    final info = SafeParsing.asMap(_info?['info']);
    final backdrop = SafeParsing.normalizeBackdropUrl(info['backdrop_path']);
    final seasons = _buildSeasonOrder(_info ?? const <String, dynamic>{}, _episodesBySeason);
    final effectiveSeason = (_selectedSeason != null && _episodesBySeason.containsKey(_selectedSeason))
        ? _selectedSeason
        : (seasons.isNotEmpty ? seasons.first : null);
    final selectedEpisodes = (effectiveSeason == null) ? const <Episode>[] : (_episodesBySeason[effectiveSeason] ?? const <Episode>[]);

    return Scaffold(
      body: Stack(
        children: [
          if (backdrop != null)
            Positioned.fill(
              child: Image.network(
                backdrop,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.78))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.series.logoUrl,
                        width: 220,
                        height: 330,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 220,
                          height: 330,
                          color: Colors.white10,
                          child: const Icon(Icons.movie, size: 48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.series.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(SafeParsing.asString(info['plot'], fallback: widget.series.plot)),
                          const SizedBox(height: 12),
                          Text('Genre: ${SafeParsing.asString(info['genre'], fallback: widget.series.genre)}'),
                          Text('Rating: ${SafeParsing.asString(info['rating'], fallback: widget.series.rating)}'),
                          Text('Cast: ${SafeParsing.asString(info['cast'], fallback: widget.series.cast)}'),
                          Text('Director: ${SafeParsing.asString(info['director'], fallback: widget.series.director)}'),
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
                if (seasons.isNotEmpty) ...[
                  const Text('Seasons', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: seasons.map((season) {
                      final selected = season == effectiveSeason;
                      return InkWell(
                        onTap: () => setState(() => _selectedSeason = season),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 64,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF2A3A8A) : const Color(0xFF1E2130),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: selected ? Colors.white70 : Colors.white24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'S$season',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : Colors.white70,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                ],
                if (selectedEpisodes.isEmpty)
                  const Card(
                    color: Color(0xFF202030),
                    child: ListTile(
                      title: Text('No episodes available for this season.'),
                    ),
                  ),
                ...selectedEpisodes.map((episode) {
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
                      trailing: _isLaunchingPlayer
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      onTap: _isLaunchingPlayer ? null : () => _playEpisode(episode),
                    ),
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _SeriesBackButton(onPressed: () => Navigator.maybePop(context)),
              ),
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

class _SeriesBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SeriesBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white54),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Back',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
