import 'dart:io';

import 'package:dio/dio.dart';

/// صنف العطل — ما يحدّد ما يُعرض للمستخدم وهل يُجدي إعادة المحاولة.
///
/// الفرق ليس تجميلياً: «تحقق من الحقول» نصيحةٌ صحيحة لخطأ تحقّق وكاذبةٌ
/// لانقطاع الشبكة. وزرّ «أعد المحاولة» مفيدٌ مع عطل عابر وعبثٌ مع بيانات
/// مرفوضة ما لم تتغيّر.
enum ApiErrorKind {
  /// لا اتصال، أو الخادم لم يُجب ضمن المهلة. العطل في الطريق لا في الطلب.
  network,

  /// الخادم ردّ بخمسمئة فما فوق — خلل عنده، لا شيء يُصلحه المستخدم.
  server,

  /// ما رفضه الخادم عن قصد: تحقّق، صلاحية، قاعدة عمل. الرسالة هنا ذات
  /// معنى وتُعرض كما جاءت.
  request,
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiErrorKind.request,
  });

  final String message;
  final int? statusCode;
  final ApiErrorKind kind;

  bool get isNetwork => kind == ApiErrorKind.network;
  bool get isServer => kind == ApiErrorKind.server;

  @override
  String toString() => message;

  static ApiException fromDio(DioException e) {
    if (_isNetworkFailure(e)) {
      return const ApiException(
        'تعذّر الاتصال بالخادم — تحقّق من اتصالك بالإنترنت',
        kind: ApiErrorKind.network,
      );
    }

    final status = e.response?.statusCode;
    final kind = status != null && status >= 500
        ? ApiErrorKind.server
        : ApiErrorKind.request;

    // رسالة الخادم عند الخمسمئة لا تُعرض: إمّا مبهمة وإمّا تُفشي داخله.
    // ونصُّنا هنا يقول ما يعني المستخدم — أن العطل ليس عنده.
    if (kind == ApiErrorKind.server) {
      return ApiException(
        'عطلٌ مؤقّت في الخادم — نعمل على إصلاحه، أعد المحاولة بعد قليل',
        statusCode: status,
        kind: ApiErrorKind.server,
      );
    }

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
      msg =
          body['message'] as String? ??
          body['title'] as String? ??
          body['error'] as String? ??
          msg;
      if (msg.startsWith('One or more validation')) {
        msg = 'بيانات غير صحيحة — تحقق من الحقول وأعد المحاولة';
      }
    }
    return ApiException(msg, statusCode: status);
  }

  /// عطلٌ قبل أن يصل الطلب أو قبل أن يكتمل الردّ.
  ///
  /// [DioExceptionType.unknown] تُفحَص لأن انقطاع الشبكة يصل غالباً
  /// مغلّفاً بها: [SocketException] أو [HandshakeException] في `error`.
  static bool _isNetworkFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.unknown:
        return e.error is SocketException || e.error is HandshakeException;
      default:
        return false;
    }
  }

  static String _toArabic(String e) {
    if (e.contains('is already taken')) return 'اسم المستخدم مستخدم من قبل';
    if (e.contains('already taken')) return 'هذه القيمة مستخدمة بالفعل';
    if (e.contains('is invalid')) return 'تنسيق غير صحيح';
    if (e.toLowerCase().contains('password'))
      return 'كلمة المرور لا تستوفي المتطلبات';
    if (e.toLowerCase().contains('email') && e.contains('taken'))
      return 'البريد الإلكتروني مسجّل مسبقاً';
    return e;
  }

  static ApiException from(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) return fromDio(e);
    if (e is SocketException || e is HandshakeException) {
      return const ApiException(
        'تعذّر الاتصال بالخادم — تحقّق من اتصالك بالإنترنت',
        kind: ApiErrorKind.network,
      );
    }
    return ApiException(e.toString());
  }
}
