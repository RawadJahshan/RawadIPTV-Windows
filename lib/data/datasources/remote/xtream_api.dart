import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class XtreamApi {
  late final Dio _dio;
  static final Set<XtreamApi> _instances = <XtreamApi>{};
  final Map<String, dynamic> _memoryResponseCache = <String, dynamic>{};

  late String _serverUrl;
  late String _username;
  late String _password;

  XtreamApi() {
    _instances.add(this);
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Connection': 'keep-alive',
          'Accept-Encoding': 'gzip, deflate',
          'Accept': '*/*',
        },
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          debugPrint('API Error: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  void setCredentials({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    if (serverUrl.endsWith('/')) {
      serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    }
    _serverUrl = serverUrl;
    _username = username;
    _password = password;
  }

  String get serverUrl => _serverUrl;
  String get username => _username;
  String get password => _password;

  String get _baseUrl => '$_serverUrl/player_api.php?username=$_username&password=$_password';

  static void clearAllInMemoryCaches() {
    for (final instance in _instances) {
      instance._memoryResponseCache.clear();
    }
    debugPrint('XtreamApi: Cleared in-memory metadata/list caches for ${_instances.length} instance(s)');
  }

  Future<Map<String, dynamic>> authenticate(
    String serverUrl,
    String username,
    String password,
  ) async {
    try {
      if (serverUrl.endsWith('/')) {
        serverUrl = serverUrl.substring(0, serverUrl.length - 1);
      }
      final url = '$serverUrl/player_api.php?username=$username&password=$password';
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Invalid credentials'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'Connection failed'};
    } catch (e) {
      return {'success': false, 'message': 'Something went wrong'};
    }
  }

  Future<List<Map<String, dynamic>>> getLiveCategories() async {
    try {
      return await _getListWithCache('$_baseUrl&action=get_live_categories');
    } catch (e) {
      debugPrint('getLiveCategories error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLiveStreams({int? categoryId}) async {
    try {
      var url = '$_baseUrl&action=get_live_streams';
      if (categoryId != null) url += '&category_id=$categoryId';
      return await _getListWithCache(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
    } catch (e) {
      debugPrint('getLiveStreams error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVodCategories() async {
    try {
      return await _getListWithCache('$_baseUrl&action=get_vod_categories');
    } catch (e) {
      debugPrint('getVodCategories error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVodStreams({int? categoryId}) async {
    try {
      var url = '$_baseUrl&action=get_vod_streams';
      if (categoryId != null) {
        url += '&category_id=$categoryId';
      }
      return await _getListWithCache(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
    } catch (e) {
      debugPrint('getVodStreams error: $e');
      return [];
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
      return data.values.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getListWithCache(
    String url, {
    Options? options,
  }) async {
    final cached = _memoryResponseCache[url];
    if (cached is List<Map<String, dynamic>>) {
      return cached.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    final response = await _dio.get(url, options: options);
    final parsed = _parseList(response.data);
    _memoryResponseCache[url] = parsed.map((item) => Map<String, dynamic>.from(item)).toList();
    return parsed;
  }
}
