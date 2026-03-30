import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CatalogCacheService {
  static const String _prefix = 'catalog_cache_v1';

  static String buildProfileKey({
    required String serverUrl,
    required String username,
  }) {
    final normalizedServer = serverUrl.trim().replaceAll(RegExp(r'/$'), '').toLowerCase();
    return '${normalizedServer}::${username.trim().toLowerCase()}';
  }

  static String _scoped(String profileKey, String field) => '$_prefix::$profileKey::$field';

  static Future<void> saveCatalog({
    required String profileKey,
    required List<Map<String, dynamic>> liveCategories,
    required List<Map<String, dynamic>> liveStreams,
    required List<Map<String, dynamic>> vodCategories,
    required List<Map<String, dynamic>> vodStreams,
    required List<Map<String, dynamic>> seriesCategories,
    required List<Map<String, dynamic>> seriesList,
    required DateTime refreshedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_scoped(profileKey, 'live_categories'), jsonEncode(liveCategories));
    await prefs.setString(_scoped(profileKey, 'live_streams'), jsonEncode(liveStreams));
    await prefs.setString(_scoped(profileKey, 'vod_categories'), jsonEncode(vodCategories));
    await prefs.setString(_scoped(profileKey, 'vod_streams'), jsonEncode(vodStreams));
    await prefs.setString(_scoped(profileKey, 'series_categories'), jsonEncode(seriesCategories));
    await prefs.setString(_scoped(profileKey, 'series_list'), jsonEncode(seriesList));
    await prefs.setString(_scoped(profileKey, 'last_refresh_iso'), refreshedAt.toUtc().toIso8601String());
  }

  static Future<List<Map<String, dynamic>>> getLiveCategories(String profileKey) =>
      _readList(profileKey, 'live_categories');

  static Future<List<Map<String, dynamic>>> getLiveStreams(String profileKey) =>
      _readList(profileKey, 'live_streams');

  static Future<List<Map<String, dynamic>>> getVodCategories(String profileKey) =>
      _readList(profileKey, 'vod_categories');

  static Future<List<Map<String, dynamic>>> getVodStreams(String profileKey) =>
      _readList(profileKey, 'vod_streams');

  static Future<List<Map<String, dynamic>>> getSeriesCategories(String profileKey) =>
      _readList(profileKey, 'series_categories');

  static Future<List<Map<String, dynamic>>> getSeriesList(String profileKey) =>
      _readList(profileKey, 'series_list');

  static Future<DateTime?> getLastRefresh(String profileKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scoped(profileKey, 'last_refresh_iso'));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  static Future<bool> hasCatalog(String profileKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_scoped(profileKey, 'live_categories')) ||
        prefs.containsKey(_scoped(profileKey, 'vod_categories')) ||
        prefs.containsKey(_scoped(profileKey, 'series_categories'));
  }

  static Future<List<Map<String, dynamic>>> _readList(String profileKey, String field) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scoped(profileKey, field));
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }

      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
