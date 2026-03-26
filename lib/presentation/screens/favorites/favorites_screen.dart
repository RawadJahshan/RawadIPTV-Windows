import 'package:flutter/material.dart';
import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/channel.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/series.dart';
import '../../../utils/favorites_manager.dart';
import '../live_tv/channels_detail_screen.dart';
import '../movies/movie_detail_screen.dart';
import '../series/series_detail_screen.dart';
import '../../../data/models/live_tv_category.dart';

class FavoritesScreen extends StatefulWidget {
  final XtreamApi xtreamApi;

  const FavoritesScreen({super.key, required this.xtreamApi});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Channel> _favoriteChannels = [];
  List<Movie> _favoriteMovies = [];
  List<Series> _favoriteSeries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    try {
      final liveIds = await FavoritesManager.getFavoriteLiveIds();
      final movieIds = await FavoritesManager.getFavoriteMovieIds();
      final seriesIds = await FavoritesManager.getFavoriteSeriesIds();

      final results = await Future.wait([
        widget.xtreamApi.getLiveStreams(),
        widget.xtreamApi.getMovies(),
        widget.xtreamApi.getSeries(),
      ]);

      final allChannels =
          (results[0] as List)
              .map((json) => Channel.fromJson(
                    Map<String, dynamic>.from(json as Map),
                    widget.xtreamApi.serverUrl,
                    widget.xtreamApi.username,
                    widget.xtreamApi.password,
                  ))
              .toList();

      final allMovies =
          (results[1] as List)
              .map((json) => Movie.fromJson(
                    Map<String, dynamic>.from(json as Map),
                    widget.xtreamApi.serverUrl,
                    widget.xtreamApi.username,
                    widget.xtreamApi.password,
                  ))
              .toList();

      final allSeries =
          (results[2] as List)
              .map((json) => Series.fromJson(Map<String, dynamic>.from(json as Map)))
              .toList();

      if (mounted) {
        setState(() {
          _favoriteChannels = allChannels
              .where((c) => liveIds.contains(c.id.toString()))
              .toList();
          _favoriteMovies = allMovies
              .where((m) => movieIds.contains(m.id.toString()))
              .toList();
          _favoriteSeries = allSeries
              .where((s) => seriesIds.contains(s.id.toString()))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('loadFavorites error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadFavorites,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          tabs: [
            Tab(
              icon: const Icon(Icons.live_tv),
              text: 'Live (${_favoriteChannels.length})',
            ),
            Tab(
              icon: const Icon(Icons.movie),
              text: 'Movies (${_favoriteMovies.length})',
            ),
            Tab(
              icon: const Icon(Icons.video_library),
              text: 'Series (${_favoriteSeries.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChannelsList(),
                _buildMoviesGrid(),
                _buildSeriesGrid(),
              ],
            ),
    );
  }

  Widget _buildChannelsList() {
    if (_favoriteChannels.isEmpty) {
      return _buildEmpty(
        'No favorite channels yet',
        Icons.live_tv,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      separatorBuilder: (_, index) =>
          const Divider(color: Colors.white12),
      itemCount: _favoriteChannels.length,
      itemBuilder: (context, index) {
        final channel = _favoriteChannels[index];
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: channel.logoUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      channel.logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stackTrace) => const Icon(
                        Icons.tv,
                        color: Colors.white54,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.tv,
                    color: Colors.white54,
                  ),
          ),
          title: Text(
            channel.name,
            style: const TextStyle(color: Colors.white),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.favorite,
                  color: Colors.red,
                ),
                onPressed: () async {
                  await FavoritesManager.removeFavoriteLive(
                    channel.id.toString(),
                  );
                  setState(
                    () => _favoriteChannels.remove(channel),
                  );
                },
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white38,
                size: 14,
              ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChannelsDetailScreen(
                  xtreamApi: widget.xtreamApi,
                  category: LiveTvCategory(
                    id: channel.id,
                    name: channel.name,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMoviesGrid() {
    if (_favoriteMovies.isEmpty) {
      return _buildEmpty(
        'No favorite movies yet',
        Icons.movie,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: _favoriteMovies.length,
      itemBuilder: (context, index) {
        final movie = _favoriteMovies[index];
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
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                        child: movie.logoUrl.isNotEmpty
                            ? Image.network(
                                movie.logoUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stackTrace) =>
                                    _buildPlaceholder(Icons.movie),
                              )
                            : _buildPlaceholder(Icons.movie),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        movie.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () async {
                    await FavoritesManager.removeFavoriteMovie(
                      movie.id.toString(),
                    );
                    setState(() => _favoriteMovies.remove(movie));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
    Widget _buildSeriesGrid() {
    if (_favoriteSeries.isEmpty) {
      return _buildEmpty(
        'No favorite series yet',
        Icons.video_library,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: _favoriteSeries.length,
      itemBuilder: (context, index) {
        final series = _favoriteSeries[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SeriesDetailScreen(
                  xtreamApi: widget.xtreamApi,
                  series: series,
                ),
              ),
            );
          },
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                        child: series.logoUrl.isNotEmpty
                            ? Image.network(
                                series.logoUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stackTrace) =>
                                    _buildPlaceholder(
                                      Icons.video_library,
                                    ),
                              )
                            : _buildPlaceholder(
                                Icons.video_library,
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            series.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (series.year.isNotEmpty)
                            Text(
                              series.year,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () async {
                    await FavoritesManager.removeFavoriteSeries(
                      series.id.toString(),
                    );
                    setState(
                      () => _favoriteSeries.remove(series),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white24,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(IconData icon) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white24,
          size: 40,
        ),
      ),
    );
  }
}