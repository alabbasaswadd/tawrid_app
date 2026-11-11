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
      // ASP.NET Core ProblemDetails: errors map contains field-level messages
      final errorsMap = body['errors'];
      if (errorsMap is Map && errorsMap.isNotEmpty) {
        final parts = <String>[];
        for (final v in errorsMap.values) {
          if (v is List) {
            for (final err in v) {
              parts.add(_toArabic(err.toString()));
            }
          }
        }
        if (parts.isNotEmpty) {
          return ApiException(parts.join(' · '), statusCode: status);
        }
      }
      msg = body['message'] as String?
          ?? body['title'] as String?
          ?? body['error'] as String?
          ?? msg;
      if (msg.startsWith('One or more validation')) {
        msg = 'بيانات غير صحيحة — تحقق من الحقول وأعد المحاولة';
      }
    }
    return ApiException(msg, statusCode: status);
  }

  static String _toArabic(String e) {
    if (e.contains('is already taken')) return 'اسم المستخدم مستخدم من قبل';
    if (e.contains('already taken')) return 'هذه القيمة مستخدمة بالفعل';
    if (e.contains('is invalid')) return 'تنسيق غير صحيح';
    if (e.toLowerCase().contains('password')) return 'كلمة المرور لا تستوفي المتطلبات';
    if (e.toLowerCase().contains('email') && e.contains('taken')) return 'البريد الإلكتروني مسجّل مسبقاً';
    return e;
  }

  static ApiException from(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) return fromDio(e);
    return ApiException(e.toString());
  }
}
