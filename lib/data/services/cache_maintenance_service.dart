import '../datasources/remote/xtream_api.dart';
import 'persistent_player_service.dart';
import 'watch_progress_service.dart';

class CacheMaintenanceService {
  static Future<void> clearAppCaches() async {
    XtreamApi.clearAllInMemoryCaches();
    await WatchProgressService.clearAllProgress();
    await PersistentPlayerService.instance.clearSessionCache();

    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }
}
