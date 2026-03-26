import 'package:flutter/material.dart';

import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/movie_category.dart';
import '../../../data/models/movie_item.dart';
import '../../../data/models/movie_watch_progress.dart';
import '../../../data/services/movie_progress_service.dart';
import 'movie_detail_screen.dart';

class MoviesScreen extends StatefulWidget {
  final XtreamApi xtreamApi;

  const MoviesScreen({super.key, required this.xtreamApi});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  static const String _allKey = 'all';
  static const String _continueKey = 'continue';

  final Map<int, List<MovieItem>> _moviesByCategory = <int, List<MovieItem>>{};
  final Map<int, MovieWatchProgress> _progressMap = <int, MovieWatchProgress>{};

  bool _loading = true;
  String _selectedKey = _allKey;
  List<MovieCategory> _categories = <MovieCategory>[];
  List<MovieItem> _allMovies = <MovieItem>[];
  List<MovieWatchProgress> _continueWatching = <MovieWatchProgress>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final categoriesRaw = await widget.xtreamApi.getVodCategories();
    final allRaw = await widget.xtreamApi.getVodStreams();
    final progressMap = await MovieProgressService.loadProgressMap();
    final continueWatching = await MovieProgressService.getContinueWatching();

    if (!mounted) return;

    setState(() {
      _categories = categoriesRaw.map((e) => MovieCategory.fromJson(e)).toList();
      _allMovies = allRaw.map((e) => MovieItem.fromJson(e)).toList();
      _progressMap
        ..clear()
        ..addAll(progressMap);
      _continueWatching = continueWatching;
      _loading = false;
    });
  }

  Future<void> _selectCategory(String key) async {
    if (_selectedKey == key) return;

    setState(() {
      _selectedKey = key;
    });

    if (key == _allKey || key == _continueKey) return;

    final categoryId = int.tryParse(key);
    if (categoryId == null || _moviesByCategory.containsKey(categoryId)) return;

    final raw = await widget.xtreamApi.getVodStreams(categoryId: categoryId);
    if (!mounted) return;

    setState(() {
      _moviesByCategory[categoryId] = raw.map((e) => MovieItem.fromJson(e)).toList();
    });
  }

  List<MovieItem> _selectedMovies() {
    if (_selectedKey == _allKey) return _allMovies;
    if (_selectedKey == _continueKey) {
      return _continueWatching
          .map((e) => MovieItem(
                streamId: e.streamId,
                title: e.title,
                posterUrl: e.poster,
                description: '',
                genre: '',
                rating: '',
                year: '',
                containerExtension: 'mp4',
              ))
          .toList();
    }

    final categoryId = int.tryParse(_selectedKey);
    if (categoryId == null) return <MovieItem>[];
    return _moviesByCategory[categoryId] ?? <MovieItem>[];
  }

  Future<void> _openMovie(MovieItem movie) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(
          xtreamApi: widget.xtreamApi,
          movie: movie,
        ),
      ),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final movies = _selectedMovies();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Movies'),
        backgroundColor: const Color(0xFF0F0F1A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      _buildChip(label: 'All', keyValue: _allKey),
                      ..._categories.map(
                        (category) => _buildChip(
                          label: category.name,
                          keyValue: category.id.toString(),
                        ),
                      ),
                      _buildChip(label: 'Continue Watching', keyValue: _continueKey),
                    ],
                  ),
                ),
                Expanded(
                  child: movies.isEmpty
                      ? const Center(
                          child: Text(
                            'No movies found',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.6,
                          ),
                          itemCount: movies.length,
                          itemBuilder: (context, index) {
                            final movie = movies[index];
                            final progress = _progressMap[movie.streamId];
                            return _MovieCard(
                              movie: movie,
                              progress: progress,
                              onTap: () => _openMovie(movie),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildChip({required String label, required String keyValue}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedKey == keyValue,
        onSelected: (_) => _selectCategory(keyValue),
        selectedColor: const Color(0xFF0072ff),
        labelStyle: TextStyle(
          color: _selectedKey == keyValue ? Colors.white : Colors.white70,
        ),
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final MovieItem movie;
  final MovieWatchProgress? progress;
  final VoidCallback onTap;

  const _MovieCard({
    required this.movie,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  movie.posterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white10,
                    child: const Icon(Icons.movie, color: Colors.white30, size: 38),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: LinearProgressIndicator(
                  value: progress!.progress,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00c6ff)),
                ),
              )
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
