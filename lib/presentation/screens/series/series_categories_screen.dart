import 'package:flutter/material.dart';

import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/series_category.dart';
import '../../../data/services/performance_logger.dart';
import 'series_list_screen.dart';

class SeriesCategoriesScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  const SeriesCategoriesScreen({super.key, required this.xtreamApi});

  @override
  State<SeriesCategoriesScreen> createState() => _SeriesCategoriesScreenState();
}

class _SeriesCategoriesScreenState extends State<SeriesCategoriesScreen> {
  late Future<List<SeriesCategory>> _futureCategories;

  @override
  void initState() {
    super.initState();
    _futureCategories = _fetchCategories();
  }

  Future<List<SeriesCategory>> _fetchCategories() async {
    final sw = Stopwatch()..start();
    final raw = await widget.xtreamApi.getSeriesCategories();
    final categories = raw.map((json) => SeriesCategory.fromJson(json)).toList();
    PerformanceLogger.log('series_home_load_time', sw.elapsed, details: 'categories=${categories.length}');
    return [
      SeriesCategory(id: -100, name: 'Continue Watching'),
      SeriesCategory(id: -101, name: 'Favorites'),
      SeriesCategory(id: -1, name: 'All'),
      ...categories,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Series')),
      body: FutureBuilder<List<SeriesCategory>>(
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
                    builder: (_) => SeriesListScreen(xtreamApi: widget.xtreamApi, category: category),
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
