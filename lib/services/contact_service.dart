import 'package:dio/dio.dart';

class ContactService {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ),
  );

  static Future<void> send({
    required String name,
    required String email,
    required String message,
  }) async {
    if (_apiBaseUrl.isEmpty) {
      throw const ContactException('Contact service URL is not configured.');
    }
    try {
      await _dio.post<void>(
        '$_apiBaseUrl/contact',
        data: {'name': name, 'email': email, 'message': message},
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'Your message could not be sent. Please try again later.';
      throw ContactException(message);
    }
  }
}

class ContactException implements Exception {
  const ContactException(this.message);
  final String message;
  @override
  String toString() => message;
}
