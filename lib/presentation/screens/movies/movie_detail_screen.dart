import 'package:flutter/material.dart';

import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/movie.dart';
import '../../../data/services/performance_logger.dart';
import '../../../data/services/watch_progress_service.dart';
import '../../../utils/favorites_manager.dart';
import '../player/fullscreen_player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  final Movie movie;

  const MovieDetailScreen({super.key, required this.xtreamApi, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;
  Map<String, dynamic>? _richInfo;
  Map<String, dynamic>? _progress;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final sw = Stopwatch()..start();
    final favoriteFuture = FavoritesManager.isFavoriteMovie(widget.movie.id.toString());
    final progressFuture = WatchProgressService.getMovieProgress(widget.movie.id);
    final infoFuture = widget.xtreamApi.getMovieInfo(widget.movie.id);
    final favorite = await favoriteFuture;
    final progress = await progressFuture;
    if (mounted) {
      setState(() {
        _isFavorite = favorite;
        _progress = progress;
      });
    }
    final info = await infoFuture;
    PerformanceLogger.log('movie_metadata_fetch_duration', sw.elapsed, details: widget.movie.name);
    if (mounted) setState(() => _richInfo = info);
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoritesManager.removeFavoriteMovie(widget.movie.id.toString());
    } else {
      await FavoritesManager.addFavoriteMovie(widget.movie.id.toString());
    }
    if (mounted) setState(() => _isFavorite = !_isFavorite);
  }

  Future<void> _play() async {
    final sw = Stopwatch()..start();
    Duration? startAt;
    if (_progress != null) {
      final positionMs = int.tryParse('${_progress!['position_ms']}') ?? 0;
      final durationMs = int.tryParse('${_progress!['duration_ms']}') ?? 0;
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
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenPlayerScreen(
          args: FullscreenPlayerArgs(
            title: widget.movie.name,
            streamUrl: widget.movie.streamUrl,
            type: PlaybackType.movie,
            contentId: widget.movie.id,
            poster: widget.movie.logoUrl,
            startAt: startAt,
            triggerElapsed: sw.elapsed,
          ),
        ),
      ),
    );

    _progress = await WatchProgressService.getMovieProgress(widget.movie.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final infoMovie = (_richInfo?['info'] is Map) ? Map<String, dynamic>.from(_richInfo!['info'] as Map) : <String, dynamic>{};
    final backdrop = infoMovie['backdrop_path']?.toString();
    final plot = infoMovie['plot']?.toString().isNotEmpty == true ? infoMovie['plot'].toString() : widget.movie.plot;
    final genre = infoMovie['genre']?.toString().isNotEmpty == true ? infoMovie['genre'].toString() : widget.movie.genre;
    final cast = infoMovie['cast']?.toString().isNotEmpty == true ? infoMovie['cast'].toString() : widget.movie.cast;
    final director = infoMovie['director']?.toString().isNotEmpty == true ? infoMovie['director'].toString() : widget.movie.director;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backdrop != null && backdrop.isNotEmpty) Image.network(backdrop, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.75)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(widget.movie.logoUrl, width: 240, height: 360, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.movie.name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          children: [
                            Text('⭐ ${widget.movie.rating}'),
                            Text(widget.movie.year),
                            Text(genre),
                            Text(infoMovie['releasedate']?.toString() ?? ''),
                            Text(infoMovie['duration']?.toString() ?? widget.movie.duration),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(plot),
                        const SizedBox(height: 16),
                        Text('Director: $director'),
                        const SizedBox(height: 6),
                        Text('Cast: $cast'),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            FilledButton.icon(onPressed: _play, icon: const Icon(Icons.play_arrow), label: const Text('Play Movie')),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _toggleFavorite,
                              icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
                              label: Text(_isFavorite ? 'Favorited' : 'Favorite'),
                            ),
                          ],
                        ),
                        if (_progress != null) ...[
                          const SizedBox(height: 14),
                          LinearProgressIndicator(
                            value: ((int.tryParse('${_progress!['position_ms']}') ?? 0) /
                                    (int.tryParse('${_progress!['duration_ms']}') ?? 1))
                                .clamp(0.0, 1.0),
                          ),
                        ],
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
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
