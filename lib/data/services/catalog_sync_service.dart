import '../datasources/remote/xtream_api.dart';
import 'catalog_cache_service.dart';

class CatalogSyncProgress {
  final int step;
  final int totalSteps;
  final String message;

  const CatalogSyncProgress({
    required this.step,
    required this.totalSteps,
    required this.message,
  });

  double get fraction => totalSteps == 0 ? 0 : step / totalSteps;
}

class CatalogSyncSummary {
  final DateTime refreshedAt;
  final int liveCategoryCount;
  final int liveStreamCount;
  final int movieCategoryCount;
  final int movieCount;
  final int seriesCategoryCount;
  final int seriesCount;

  const CatalogSyncSummary({
    required this.refreshedAt,
    required this.liveCategoryCount,
    required this.liveStreamCount,
    required this.movieCategoryCount,
    required this.movieCount,
    required this.seriesCategoryCount,
    required this.seriesCount,
  });
}

class CatalogSyncService {
  static const int _totalSteps = 6;

  static Future<CatalogSyncSummary> syncXtreamCatalog({
    required XtreamApi xtreamApi,
    required String profileKey,
    required void Function(CatalogSyncProgress progress) onProgress,
  }) async {
    onProgress(
      const CatalogSyncProgress(
        step: 1,
        totalSteps: _totalSteps,
        message: 'Fetching categories...',
      ),
    );

    final liveCategoriesFuture = xtreamApi.getLiveCategories();
    final vodCategoriesFuture = xtreamApi.getVodCategories();
    final seriesCategoriesFuture = xtreamApi.getSeriesCategories();

    final liveCategories = await liveCategoriesFuture;
    final vodCategories = await vodCategoriesFuture;
    final seriesCategories = await seriesCategoriesFuture;

    onProgress(
      const CatalogSyncProgress(
        step: 2,
        totalSteps: _totalSteps,
        message: 'Loading Live TV...',
      ),
    );
    final liveStreams = await xtreamApi.getLiveStreams();

    onProgress(
      const CatalogSyncProgress(
        step: 3,
        totalSteps: _totalSteps,
        message: 'Loading Movies...',
      ),
    );
    final vodStreams = await xtreamApi.getVodStreamsStrict();

    onProgress(
      const CatalogSyncProgress(
        step: 4,
        totalSteps: _totalSteps,
        message: 'Loading Series...',
      ),
    );
    final seriesList = await xtreamApi.getSeries();

    onProgress(
      const CatalogSyncProgress(
        step: 5,
        totalSteps: _totalSteps,
        message: 'Saving content...',
      ),
    );

    final refreshedAt = DateTime.now();
    await CatalogCacheService.saveCatalog(
      profileKey: profileKey,
      liveCategories: liveCategories,
      liveStreams: liveStreams,
      vodCategories: vodCategories,
      vodStreams: vodStreams,
      seriesCategories: seriesCategories,
      seriesList: seriesList,
      refreshedAt: refreshedAt,
    );

    onProgress(
      const CatalogSyncProgress(
        step: 6,
        totalSteps: _totalSteps,
        message: 'Completed',
      ),
    );

    return CatalogSyncSummary(
      refreshedAt: refreshedAt,
      liveCategoryCount: liveCategories.length,
      liveStreamCount: liveStreams.length,
      movieCategoryCount: vodCategories.length,
      movieCount: vodStreams.length,
      seriesCategoryCount: seriesCategories.length,
      seriesCount: seriesList.length,
    );
  }
}
