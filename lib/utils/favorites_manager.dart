import 'package:shared_preferences/shared_preferences.dart';

class FavoritesManager {
  static const String _liveKey = 'favorites_live';
  static const String _moviesKey = 'favorites_movies';
  static const String _seriesKey = 'favorites_series';

  // ─── Live TV ─────────────────────────────────────────────
  static Future<bool> isFavoriteLive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_liveKey) ?? [];
    return list.contains(id);
  }

  static Future<void> addFavoriteLive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_liveKey) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_liveKey, list);
    }
  }

  static Future<void> removeFavoriteLive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_liveKey) ?? [];
    list.remove(id);
    await prefs.setStringList(_liveKey, list);
  }

  static Future<List<String>> getFavoriteLiveIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_liveKey) ?? [];
  }

  // ─── Movies ──────────────────────────────────────────────
  static Future<bool> isFavoriteMovie(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_moviesKey) ?? [];
    return list.contains(id);
  }

  static Future<void> addFavoriteMovie(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_moviesKey) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_moviesKey, list);
    }
  }

  static Future<void> removeFavoriteMovie(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_moviesKey) ?? [];
    list.remove(id);
    await prefs.setStringList(_moviesKey, list);
  }

  static Future<List<String>> getFavoriteMovieIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_moviesKey) ?? [];
  }

  // ─── Series ──────────────────────────────────────────────
  static Future<bool> isFavoriteSeries(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_seriesKey) ?? [];
    return list.contains(id);
  }

  static Future<void> addFavoriteSeries(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_seriesKey) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_seriesKey, list);
    }
  }

  static Future<void> removeFavoriteSeries(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_seriesKey) ?? [];
    list.remove(id);
    await prefs.setStringList(_seriesKey, list);
  }

  static Future<List<String>> getFavoriteSeriesIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_seriesKey) ?? [];
  }

  // ─── Keep old methods for backward compatibility ──────────
  static Future<bool> isFavorite(String id) => isFavoriteLive(id);
  static Future<void> addFavorite(String id) => addFavoriteLive(id);
  static Future<void> removeFavorite(String id) => removeFavoriteLive(id);
  static Future<List<String>> getFavoriteIds() => getFavoriteLiveIds();
}