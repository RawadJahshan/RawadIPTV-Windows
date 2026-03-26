import 'package:flutter/material.dart';

import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/movie_category.dart';
import '../../../data/services/performance_logger.dart';
import 'movies_list_screen.dart';

class MoviesCategoriesScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  const MoviesCategoriesScreen({super.key, required this.xtreamApi});

  @override
  State<MoviesCategoriesScreen> createState() => _MoviesCategoriesScreenState();
}

class _MoviesCategoriesScreenState extends State<MoviesCategoriesScreen> {
  late Future<List<MovieCategory>> _futureCategories;

  @override
  void initState() {
    super.initState();
    _futureCategories = _fetchCategories();
  }

  Future<List<MovieCategory>> _fetchCategories() async {
    final sw = Stopwatch()..start();
    final raw = await widget.xtreamApi.getMovieCategories();
    final categories = raw.map((json) => MovieCategory.fromJson(json)).toList();
    PerformanceLogger.log('movies_home_load_time', sw.elapsed, details: 'categories=${categories.length}');
    return [
      MovieCategory(id: -100, name: 'Continue Watching'),
      MovieCategory(id: -101, name: 'Favorites'),
      MovieCategory(id: -1, name: 'All'),
      ...categories,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movies')),
      body: FutureBuilder<List<MovieCategory>>(
        future: _futureCategories,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final categories = snapshot.data!;
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MoviesListScreen(xtreamApi: widget.xtreamApi, category: category),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
