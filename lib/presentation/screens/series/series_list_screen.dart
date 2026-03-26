import 'package:flutter/material.dart';

import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/series.dart';
import '../../../data/models/series_category.dart';
import '../../../data/services/performance_logger.dart';
import '../../../data/services/watch_progress_service.dart';
import '../../../utils/favorites_manager.dart';
import 'series_detail_screen.dart';

class SeriesListScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  final SeriesCategory category;

  const SeriesListScreen({super.key, required this.xtreamApi, required this.category});

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  late Future<List<Series>> _futureSeries;
  Set<String> _favoriteIds = {};
  List<Map<String, dynamic>> _continue = [];

  @override
  void initState() {
    super.initState();
    _futureSeries = _fetch();
  }

  Future<List<Series>> _fetch() async {
    final sw = Stopwatch()..start();
    _favoriteIds = (await FavoritesManager.getFavoriteSeriesIds()).toSet();
    _continue = await WatchProgressService.getSeriesContinueWatching();

    final allRaw = await widget.xtreamApi.getSeries(
      categoryId: widget.category.id == -1 || widget.category.id <= -100 ? null : widget.category.id,
    );
    var list = allRaw.map((json) => Series.fromJson(json)).toList();

    if (widget.category.id == -101) {
      list = list.where((s) => _favoriteIds.contains(s.id.toString())).toList();
    }
    if (widget.category.id == -100) {
      final ids = _continue.map((e) => '${e['series_id']}').toList();
      list = list.where((s) => ids.contains('${s.id}')).toList()
        ..sort((a, b) => ids.indexOf('${a.id}').compareTo(ids.indexOf('${b.id}')));
    }

    PerformanceLogger.log('series_category_open_time', sw.elapsed, details: widget.category.name);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: FutureBuilder<List<Series>>(
        future: _futureSeries,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final seriesList = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.64,
            ),
            itemCount: seriesList.length,
            itemBuilder: (context, index) {
              final series = seriesList[index];
              final progress = _continue.where((e) => '${e['series_id']}' == '${series.id}').cast<Map<String, dynamic>?>().firstOrNull;
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SeriesDetailScreen(xtreamApi: widget.xtreamApi, series: series)),
                ),
                child: Card(
                  color: const Color(0xFF171721),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(series.logoUrl, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(series.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      if (progress != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Text(
                            'S${progress['season_number']} E${progress['episode_number']} • ${progress['episode_title']}',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
