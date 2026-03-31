import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class _MemoryCacheEntry {
  final List<Map<String, dynamic>> data;
  final DateTime cachedAt;
  final Duration ttl;

  const _MemoryCacheEntry({
    required this.data,
    required this.cachedAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}

class XtreamApi {
  late final Dio _dio;
  static final Set<XtreamApi> _instances = <XtreamApi>{};
  final Map<String, _MemoryCacheEntry> _memoryResponseCache = <String, _MemoryCacheEntry>{};

  static const Duration _categoriesTtl = Duration(minutes: 20);
  static const Duration _categoryItemsTtl = Duration(minutes: 10);
  static const Duration _accountInfoTtl = Duration(minutes: 5);

  late String _serverUrl;
  late String _username;
  late String _password;

  XtreamApi() {
    _instances.add(this);
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Connection': 'keep-alive',
        },
        validateStatus: (status) => status != null && status >= 200 && status < 500,
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (error.response?.statusCode == 403) {
            debugPrint('[API] 403 Forbidden — check credentials or User-Agent');
          }
          debugPrint('API Error: ${error.message}');
          handler.next(error);
        },
      ),
    );

    _dio.options.headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Connection': 'keep-alive',
    };
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  void setCredentials({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    _serverUrl = AppConstants.serverUrl;
    _username = username;
    _password = password;
  }

  String get serverUrl => _serverUrl;
  String get username => _username;
  String get password => _password;

  String get _baseUrl => '$_serverUrl/player_api.php?username=$_username&password=$_password';

  void clearInMemoryCache() {
    _memoryResponseCache.clear();
  }

  static void clearAllInMemoryCaches() {
    for (final instance in _instances) {
      instance._memoryResponseCache.clear();
    }
    debugPrint('XtreamApi: Cleared in-memory metadata/list caches for ${_instances.length} instance(s)');
  }

  Future<void> warmupLightweightContent({bool forceRefresh = false}) async {
    if (forceRefresh) {
      clearInMemoryCache();
    }

    await Future.wait<void>([
      getAccountInfo(forceRefresh: forceRefresh),
      getLiveCategories(forceRefresh: forceRefresh),
      getVodCategories(forceRefresh: forceRefresh),
      getSeriesCategories(forceRefresh: forceRefresh),
    ]);
  }

  Future<Map<String, dynamic>> authenticate(
    String serverUrl,
    String username,
    String password,
  ) async {
    try {
      final url = '${AppConstants.apiBase}?username=$username&password=$password&action=get_live_categories';
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Invalid username or password'};
    } on DioException catch (e) {
      debugPrint('Auth error: ${e.message}');
      return {'success': false, 'message': 'Invalid username or password'};
    } catch (e) {
      return {'success': false, 'message': 'Invalid username or password'};
    }
  }

  Future<Map<String, dynamic>> getAccountInfo({bool forceRefresh = false}) async {
    final list = await _getListWithCache(
      '$_baseUrl&action=get_account_info',
      ttl: _accountInfoTtl,
      forceRefresh: forceRefresh,
    );

    if (list.isNotEmpty) {
      return list.first;
    }
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getLiveCategories({bool forceRefresh = false}) async {
    try {
      return await _getListWithCache(
        '$_baseUrl&action=get_live_categories',
        ttl: _categoriesTtl,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      debugPrint('getLiveCategories error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLiveStreams({int? categoryId, bool forceRefresh = false}) async {
    try {
      var url = '$_baseUrl&action=get_live_streams';
      if (categoryId != null) url += '&category_id=$categoryId';
      return await _getListWithCache(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
        ttl: _categoryItemsTtl,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      debugPrint('getLiveStreams error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVodCategories({bool forceRefresh = false}) async {
    try {
      return await _getListWithCache(
        '$_baseUrl&action=get_vod_categories',
        ttl: _categoriesTtl,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      debugPrint('getVodCategories error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVodStreams({int? categoryId, bool forceRefresh = false}) async {
    try {
      var url = '$_baseUrl&action=get_vod_streams';
      if (categoryId != null) {
        url += '&category_id=$categoryId';
      }
      return await _getListWithCache(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
        ttl: _categoryItemsTtl,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      debugPrint('getVodStreams error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVodStreamsStrict({int? categoryId, bool forceRefresh = false}) async {
    var url = '$_baseUrl&action=get_vod_streams';
    if (categoryId != null) {
      url += '&category_id=$categoryId';
    }
    return _getListWithCache(
      url,
      options: Options(receiveTimeout: const Duration(seconds: 60)),
      ttl: _categoryItemsTtl,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Map<String, dynamic>>> getSeriesCategories({bool forceRefresh = false}) async {
    try {
      return await _getListWithCache(
        '$_baseUrl&action=get_series_categories',
        ttl: _categoriesTtl,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      debugPrint('getSeriesCategories error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSeries({int? categoryId, bool forceRefresh = false}) async {
    try {
      var url = '$_baseUrl&action=get_series';
      if (categoryId != null) {
        url += '&category_id=$categoryId';
      }
      return await _getListWithCache(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
        ttl: _categoryItemsTtl,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      debugPrint('getSeries error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSeriesInfo(int seriesId) async {
    final url = '$_baseUrl&action=get_series_info&series_id=$seriesId';
    try {
      final response = await _dio.get(url);
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('getSeriesInfo error: $e');
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> getVodInfo(int vodId) async {
    final url = '$_baseUrl&action=get_vod_info&vod_id=$vodId';
    try {
      final response = await _dio.get(url);
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('getVodInfo error: $e');
      return <String, dynamic>{};
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (data is Map) {
      final asMap = Map<String, dynamic>.from(data);
      if (asMap.values.every((value) => value is! Map)) {
        return <Map<String, dynamic>>[asMap];
      }

      return asMap.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getListWithCache(
    String url, {
    Options? options,
    Duration ttl = _categoryItemsTtl,
    bool forceRefresh = false,
  }) async {
    final cachedEntry = _memoryResponseCache[url];
    if (!forceRefresh && cachedEntry != null && !cachedEntry.isExpired) {
      return cachedEntry.data.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    final response = await _dio.get(url, options: options);
    final parsed = _parseList(response.data);
    _memoryResponseCache[url] = _MemoryCacheEntry(
      data: parsed.map((item) => Map<String, dynamic>.from(item)).toList(),
      cachedAt: DateTime.now(),
      ttl: ttl,
    );
    return parsed;
  }
}
