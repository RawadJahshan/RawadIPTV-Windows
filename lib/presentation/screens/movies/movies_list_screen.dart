import 'package:flutter/material.dart';
import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/movie_category.dart';
import '../../../utils/favorites_manager.dart';
import 'movie_detail_screen.dart';

class MoviesListScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  final MovieCategory category;

  const MoviesListScreen({
    super.key,
    required this.xtreamApi,
    required this.category,
  });

  @override
  State<MoviesListScreen> createState() => _MoviesListScreenState();
}

class _MoviesListScreenState extends State<MoviesListScreen> {
  late Future<List<Movie>> _futureMovies;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  Set<String> _favoriteIds = {};
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _futureMovies = _fetchMovies();
    _loadFavorites();
  }

  Future<List<Movie>> _fetchMovies() async {
    final raw = await widget.xtreamApi.getMovies(
      // if id is -1 load ALL movies
      categoryId: widget.category.id == -1 ? null : widget.category.id,
    );
    return raw
        .map((json) => Movie.fromJson(
              json,
              widget.xtreamApi.serverUrl,
              widget.xtreamApi.username,
              widget.xtreamApi.password,
            ))
        .toList();
  }

  Future<void> _loadFavorites() async {
    final ids = await FavoritesManager.getFavoriteMovieIds();
    if (mounted) setState(() => _favoriteIds = ids.toSet());
  }

  Future<void> _toggleFavorite(Movie movie) async {
    final id = movie.id.toString();
    if (_favoriteIds.contains(id)) {
      await FavoritesManager.removeFavoriteMovie(id);
      setState(() => _favoriteIds.remove(id));
    } else {
      await FavoritesManager.addFavoriteMovie(id);
      setState(() => _favoriteIds.add(id));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Text(widget.category.name),
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        actions: [
          // Favorites filter toggle
          IconButton(
            onPressed: () {
              setState(() => _showFavoritesOnly = !_showFavoritesOnly);
            },
            icon: Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _showFavoritesOnly ? Colors.red : Colors.white,
            ),
            tooltip: 'Show Favorites',
          ),
        ],
      ),
      body: FutureBuilder<List<Movie>>(
        future: _futureMovies,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading movies...'),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No movies found'));
          }

          final allMovies = snapshot.data!;

          // Apply filters
          var movies = allMovies.where((m) {
            final matchesSearch = _searchQuery.isEmpty ||
                m.name
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
            final matchesFavorite = !_showFavoritesOnly ||
                _favoriteIds.contains(m.id.toString());
            return matchesSearch && matchesFavorite;
          }).toList();

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search movies...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white38,
                            ),
                            onPressed: () {
                              _searchController.clear();
                                                            setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF0F0F1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value),
                ),
              ),

              // Count + filter info
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      '${movies.length} Movies',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    if (_showFavoritesOnly) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Favorites only',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Movies grid
              Expanded(
                child: movies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showFavoritesOnly
                                  ? Icons.favorite_border
                                  : Icons.movie_outlined,
                              color: Colors.white24,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showFavoritesOnly
                                  ? 'No favorite movies yet'
                                  : 'No movies found',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: movies.length,
                        itemBuilder: (context, index) {
                          final movie = movies[index];
                          final isFav = _favoriteIds
                              .contains(movie.id.toString());
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MovieDetailScreen(
                                    xtreamApi: widget.xtreamApi,
                                    movie: movie,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F0F1A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Poster
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(10),
                                          ),
                                          child: movie.logoUrl.isNotEmpty
                                              ? Image.network(
                                                  movie.logoUrl,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                          _buildPlaceholder(),
                                                )
                                              : _buildPlaceholder(),
                                        ),
                                      ),
                                      // Info
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              movie.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (movie.year.isNotEmpty)
                                                  Text(
                                                    movie.year,
                                                    style: const TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                const Spacer(),
                                                if (movie.rating.isNotEmpty &&
                                                    movie.rating != '0')
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.star,
                                                        color: Colors.amber,
                                                        size: 11,
                                                      ),
                                                      const SizedBox(
                                                          width: 2),
                                                      Text(
                                                        movie.rating,
                                                        style:
                                                            const TextStyle(
                                                          color: Colors.amber,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Favorite button
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () => _toggleFavorite(movie),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.black.withOpacity(0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isFav
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isFav
                                              ? Colors.red
                                              : Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(
          Icons.movie,
          color: Colors.white24,
          size: 40,
        ),
      ),
    );
  }
}