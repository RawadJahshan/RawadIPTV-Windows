import 'package:flutter/material.dart';

import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/movie_item.dart';
import '../../../data/models/movie_watch_progress.dart';
import '../../../data/services/movie_progress_service.dart';
import 'movie_player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  final MovieItem movie;

  const MovieDetailScreen({
    super.key,
    required this.xtreamApi,
    required this.movie,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  MovieWatchProgress? _progress;
  bool _loading = true;
  String _description = '';
  String _genre = '';
  String _rating = '';
  String _year = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = await MovieProgressService.getProgress(widget.movie.streamId);
    final vodInfo = await widget.xtreamApi.getVodInfo(widget.movie.streamId);
    final info = vodInfo['info'];

    if (!mounted) return;

    setState(() {
      _progress = progress;
      _description = info is Map
          ? (info['plot']?.toString() ?? info['description']?.toString() ?? widget.movie.description)
          : widget.movie.description;
      _genre = info is Map ? (info['genre']?.toString() ?? widget.movie.genre) : widget.movie.genre;
      _rating = info is Map ? (info['rating']?.toString() ?? widget.movie.rating) : widget.movie.rating;
      _year = info is Map ? (info['releasedate']?.toString() ?? info['year']?.toString() ?? widget.movie.year) : widget.movie.year;
      _loading = false;
    });
  }

  String _formatResume(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _openPlayer({Duration? startAt}) async {
    final streamUrl = widget.movie.streamUrl(
      widget.xtreamApi.serverUrl,
      widget.xtreamApi.username,
      widget.xtreamApi.password,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoviePlayerScreen(
          streamId: widget.movie.streamId,
          title: widget.movie.title,
          poster: widget.movie.posterUrl,
          streamUrl: streamUrl,
          startAt: startAt,
        ),
      ),
    );

    final updated = await MovieProgressService.getProgress(widget.movie.streamId);
    if (mounted) {
      setState(() {
        _progress = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Text(widget.movie.title),
        backgroundColor: const Color(0xFF0F0F1A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.movie.posterUrl,
                        width: 240,
                        height: 340,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 240,
                          height: 340,
                          color: Colors.white10,
                          child: const Icon(Icons.movie, color: Colors.white38, size: 64),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.movie.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(_description, style: const TextStyle(color: Colors.white70, height: 1.5)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text('Genre: ${_genre.isEmpty ? 'N/A' : _genre}', style: const TextStyle(color: Colors.white70)),
                      Text('Rating: ${_rating.isEmpty ? 'N/A' : _rating}', style: const TextStyle(color: Colors.white70)),
                      Text('Year: ${_year.isEmpty ? 'N/A' : _year}', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_progress != null && _progress!.positionMs > 0)
                    ElevatedButton.icon(
                      onPressed: () => _openPlayer(startAt: Duration(milliseconds: _progress!.positionMs)),
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Resume from ${_formatResume(Duration(milliseconds: _progress!.positionMs))}'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _openPlayer(),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                    ),
                ],
              ),
            ),
    );
  }
}
