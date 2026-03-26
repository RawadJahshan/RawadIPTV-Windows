import 'package:flutter/material.dart';

import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/movie_category.dart';
import '../../../data/services/performance_logger.dart';
import '../../../data/services/watch_progress_service.dart';
import '../../../utils/favorites_manager.dart';
import 'movie_detail_screen.dart';

class MoviesListScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  final MovieCategory category;

  const MoviesListScreen({super.key, required this.xtreamApi, required this.category});

  @override
  State<MoviesListScreen> createState() => _MoviesListScreenState();
}

class _MoviesListScreenState extends State<MoviesListScreen> {
  late Future<List<Movie>> _futureMovies;
  Set<String> _favoriteIds = {};
  List<Map<String, dynamic>> _continue = [];

  @override
  void initState() {
    super.initState();
    _futureMovies = _fetch();
  }

  Future<List<Movie>> _fetch() async {
    final sw = Stopwatch()..start();
    _favoriteIds = (await FavoritesManager.getFavoriteMovieIds()).toSet();
    _continue = await WatchProgressService.getMovieContinueWatching();

    final allRaw = await widget.xtreamApi.getMovies(
      categoryId: widget.category.id == -1 || widget.category.id <= -100 ? null : widget.category.id,
    );
    var movies = allRaw
        .map((json) => Movie.fromJson(json, widget.xtreamApi.serverUrl, widget.xtreamApi.username, widget.xtreamApi.password))
        .toList();

    if (widget.category.id == -101) {
      movies = movies.where((m) => _favoriteIds.contains(m.id.toString())).toList();
    }
    if (widget.category.id == -100) {
      final ids = _continue.map((e) => '${e['stream_id']}').toList();
      movies = movies.where((m) => ids.contains('${m.id}')).toList()
        ..sort((a, b) => ids.indexOf('${a.id}').compareTo(ids.indexOf('${b.id}')));
    }

    PerformanceLogger.log('movies_category_open_time', sw.elapsed, details: widget.category.name);
    return movies;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: FutureBuilder<List<Movie>>(
        future: _futureMovies,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final movies = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.64,
            ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              final progress = _continue.where((e) => '${e['stream_id']}' == '${movie.id}').cast<Map<String, dynamic>?>().firstOrNull;
              final p = int.tryParse('${progress?['position_ms']}') ?? 0;
              final d = int.tryParse('${progress?['duration_ms']}') ?? 0;
              final ratio = d <= 0 ? 0.0 : (p / d).clamp(0.0, 1.0);
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MovieDetailScreen(xtreamApi: widget.xtreamApi, movie: movie)),
                ),
                child: Card(
                  color: const Color(0xFF171721),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(movie.logoUrl, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(movie.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      if (ratio > 0) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: LinearProgressIndicator(value: ratio),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Remaining ${_fmt(Duration(milliseconds: d - p))}', style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '${h}h ${m}m' : '${d.inMinutes}m';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
