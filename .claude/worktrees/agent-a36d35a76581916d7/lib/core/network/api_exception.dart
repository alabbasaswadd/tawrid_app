import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;

  static ApiException fromDio(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    String msg = 'حدث خطأ، الرجاء المحاولة لاحقاً';
    if (body is Map<String, dynamic>) {
      msg = body['message'] as String?
          ?? body['title'] as String?
          ?? body['error'] as String?
          ?? msg;
    }
    return ApiException(msg, statusCode: status);
  }

  static ApiException from(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) return fromDio(e);
    return ApiException(e.toString());
  }
}
