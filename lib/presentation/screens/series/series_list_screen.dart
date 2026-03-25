import 'package:flutter/material.dart';
import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/series.dart';
import '../../../data/models/series_category.dart';
import '../../../utils/favorites_manager.dart';
import 'series_detail_screen.dart';

class SeriesListScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  final SeriesCategory category;

  const SeriesListScreen({
    super.key,
    required this.xtreamApi,
    required this.category,
  });

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  late Future<List<Series>> _futureSeries;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  Set<String> _favoriteIds = {};
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _futureSeries = _fetchSeries();
    _loadFavorites();
  }

  Future<List<Series>> _fetchSeries() async {
    final raw = await widget.xtreamApi.getSeries(
      // if id is -1 load ALL series
      categoryId: widget.category.id == -1 ? null : widget.category.id,
    );
    return raw.map((json) => Series.fromJson(json)).toList();
  }

  Future<void> _loadFavorites() async {
    final ids = await FavoritesManager.getFavoriteSeriesIds();
    if (mounted) setState(() => _favoriteIds = ids.toSet());
  }

    Future<void> _toggleFavorite(Series series) async {
    final id = series.id.toString();
    if (_favoriteIds.contains(id)) {
      await FavoritesManager.removeFavoriteSeries(id);
      setState(() => _favoriteIds.remove(id));
    } else {
      await FavoritesManager.addFavoriteSeries(id);
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
      body: FutureBuilder<List<Series>>(
        future: _futureSeries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading series...'),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No series found'));
          }

          final allSeries = snapshot.data!;

          // Apply filters
          var series = allSeries.where((s) {
            final matchesSearch = _searchQuery.isEmpty ||
                s.name
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
            final matchesFavorite = !_showFavoritesOnly ||
                _favoriteIds.contains(s.id.toString());
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
                    hintText: 'Search series...',
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
                      '${series.length} Series',
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

              // Series grid
              Expanded(
                child: series.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showFavoritesOnly
                                  ? Icons.favorite_border
                                  : Icons.video_library_outlined,
                              color: Colors.white24,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showFavoritesOnly
                                  ? 'No favorite series yet'
                                  : 'No series found',
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
                        itemCount: series.length,
                        itemBuilder: (context, index) {
                          final s = series[index];
                          final isFav =
                              _favoriteIds.contains(s.id.toString());
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SeriesDetailScreen(
                                    xtreamApi: widget.xtreamApi,
                                    series: s,
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
                                          child: s.logoUrl.isNotEmpty
                                              ? Image.network(
                                                  s.logoUrl,
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
                                              s.name,
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
                                                if (s.year.isNotEmpty)
                                                  Text(
                                                    s.year,
                                                    style: const TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                const Spacer(),
                                                if (s.rating.isNotEmpty &&
                                                    s.rating != '0')
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
                                                        s.rating,
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
                                      onTap: () => _toggleFavorite(s),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withOpacity(0.6),
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
          Icons.video_library,
          color: Colors.white24,
          size: 40,
        ),
      ),
    );
  }
}