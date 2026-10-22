import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawrid_app/core/constants/storage_keys.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/core/session/warehouse_session.dart';

// خادم Tawrid.api التطويري المشترك (Development فقط — بيئة مؤقتة، سيُعلن
// رابط البروكشن لاحقاً). ملاحظة: بدون "/tawrid-api" هنا — البادئة موجودة
// فعلاً في كل مسارات ApiEndpoints. للعمل على باك إند محلي بدلاً منه:
//   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5289   (محاكي أندرويد)
//   flutter run --dart-define=API_BASE_URL=http://localhost:5289  (ويندوز/ويب)
const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://169.58.139.217:5040',
);

final _logger = Logger();

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient._create(ref);
});

class ApiClient {
  ApiClient._(this._dio);

  final Dio _dio;

  static ApiClient _create(Ref ref) {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor(ref));
    dio.interceptors.add(_LogInterceptor());

    return ApiClient._(dio);
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _dio.get(path, queryParameters: queryParameters);
    return _unwrap(res.data);
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    final res = await _dio.post(path, data: data);
    return _unwrap(res.data);
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    final res = await _dio.put(path, data: data);
    return _unwrap(res.data);
  }

  Future<void> delete(String path) async {
    await _dio.delete(path);
  }

  dynamic _unwrap(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'];
    }
    return data;
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref);
  final Ref _ref;

  // كل مسارات المستودع تحت tawrid-api/warehouse/... — يكفي التحقق من
  // وجود هذا القسم بدل افتراض بادئة كاملة مختلفة.
  bool _isWarehouseRequest(RequestOptions options) =>
      options.path.contains('/warehouse/');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    const store = FlutterSecureStorage();
    final key = _isWarehouseRequest(options)
        ? StorageKeys.warehouseToken
        : StorageKeys.pharmacyToken;
    final token = await store.read(key: key);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      final isWh = _isWarehouseRequest(err.requestOptions);
      const store = FlutterSecureStorage();
      if (isWh) {
        await store.delete(key: StorageKeys.warehouseToken);
        await prefs.setBool(StorageKeys.hasWarehouseSession, false);
        _ref.invalidate(warehouseSessionProvider);
      } else {
        await store.delete(key: StorageKeys.pharmacyToken);
        await prefs.setBool(StorageKeys.hasPharmacySession, false);
        _ref.invalidate(pharmacySessionProvider);
      }
    }
    handler.next(err);
  }
}

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.d('[API] ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e('[API] ERROR ${err.response?.statusCode}: ${err.message}');
    handler.next(err);
  }
}
