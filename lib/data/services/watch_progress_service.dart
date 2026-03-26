import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WatchProgressService {
  static const _movieKey = 'watch_progress_movies';
  static const _episodeKey = 'watch_progress_episodes';

  static Future<Map<String, dynamic>> _readMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  static Future<void> _writeMap(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  static Future<void> saveMovieProgress({
    required int streamId,
    required int positionMs,
    required int durationMs,
    required String title,
    String? poster,
  }) async {
    if (durationMs <= 0) return;
    final map = await _readMap(_movieKey);
    final progress = positionMs / durationMs;
    map['$streamId'] = {
      'stream_id': streamId,
      'position_ms': positionMs,
      'duration_ms': durationMs,
      'title': title,
      'poster': poster ?? '',
      'completed': progress >= 0.95,
      'last_watched_at': DateTime.now().toIso8601String(),
    };
    await _writeMap(_movieKey, map);
  }

  static Future<Map<String, dynamic>?> getMovieProgress(int streamId) async {
    final map = await _readMap(_movieKey);
    final record = map['$streamId'];
    if (record is Map<String, dynamic>) return record;
    if (record is Map) return Map<String, dynamic>.from(record);
    return null;
  }

  static Future<List<Map<String, dynamic>>> getMovieContinueWatching() async {
    final map = await _readMap(_movieKey);
    final records = map.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['completed'] as bool?) != true)
        .toList();
    records.sort((a, b) => (b['last_watched_at']?.toString() ?? '')
        .compareTo(a['last_watched_at']?.toString() ?? ''));
    return records;
  }

  static Future<void> saveEpisodeProgress({
    required int episodeId,
    required int seriesId,
    required String seriesName,
    required String episodeTitle,
    required int episodeNumber,
    required int seasonNumber,
    required int positionMs,
    required int durationMs,
  }) async {
    if (durationMs <= 0) return;
    final map = await _readMap(_episodeKey);
    final progress = positionMs / durationMs;
    map['$episodeId'] = {
      'episode_id': episodeId,
      'series_id': seriesId,
      'series_name': seriesName,
      'episode_title': episodeTitle,
      'episode_number': episodeNumber,
      'season_number': seasonNumber,
      'position_ms': positionMs,
      'duration_ms': durationMs,
      'completed': progress >= 0.95,
      'last_watched_at': DateTime.now().toIso8601String(),
    };
    await _writeMap(_episodeKey, map);
  }

  static Future<Map<String, dynamic>?> getEpisodeProgress(int episodeId) async {
    final map = await _readMap(_episodeKey);
    final record = map['$episodeId'];
    if (record is Map<String, dynamic>) return record;
    if (record is Map) return Map<String, dynamic>.from(record);
    return null;
  }

  static Future<List<Map<String, dynamic>>> getSeriesContinueWatching() async {
    final map = await _readMap(_episodeKey);
    final records = map.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['completed'] as bool?) != true)
        .toList();
    records.sort((a, b) => (b['last_watched_at']?.toString() ?? '')
        .compareTo(a['last_watched_at']?.toString() ?? ''));

    final latestBySeries = <int, Map<String, dynamic>>{};
    for (final record in records) {
      final seriesId = int.tryParse(record['series_id'].toString()) ?? 0;
      latestBySeries.putIfAbsent(seriesId, () => record);
    }
    return latestBySeries.values.toList();
  }
}
