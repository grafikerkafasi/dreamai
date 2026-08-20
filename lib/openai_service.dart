import 'package:dio/dio.dart';
import 'data/interpreter_prompts.dart';
import 'services/device_id_service.dart';

class OpenAIService {
  static const _useDemoAnalysis = bool.fromEnvironment(
    'USE_DEMO_ANALYSIS',
    defaultValue: true,
  );
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static final Dio _dio = Dio(
    BaseOptions(
      // Generous timeouts: the free-tier backend host can take ~20-30s to
      // wake from an idle sleep before it even accepts the connection.
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );

  static Future<String> analyzeDream(String prompt, String interpreter) async {
    final dream = prompt.trim();
    if (dream.isEmpty) {
      throw const DreamAnalysisException('Please enter a dream first.');
    }

    final isTurkish = RegExp(r'[şğıçöüİŞĞÇÖÜ]').hasMatch(dream);
    if (_useDemoAnalysis) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return _demoAnalysis(interpreter, isTurkish);
    }

    if (_apiBaseUrl.isEmpty) {
      throw const DreamAnalysisException(
        'Analysis service URL is not configured.',
      );
    }

    final systemMessage = interpreterPrompts[interpreter]
            ?[isTurkish ? 'tr' : 'en'] ??
        (isTurkish
            ? '$interpreter gibi davranarak bu rüyayı yorumla.'
            : 'Act like $interpreter and interpret the dream.');

    try {
      final deviceId = await DeviceIdService.getId();
      final response = await _dio.post<Map<String, dynamic>>(
        '$_apiBaseUrl/analyze',
        data: {'prompt': 'Dream:\n$dream\n\n$systemMessage'},
        options: Options(headers: {'X-Device-Id': deviceId}),
      );
      final result = response.data?['result'];
      if (result is String && result.trim().isNotEmpty) {
        return result.trim();
      }
      throw const DreamAnalysisException(
          'The analysis service returned no result.');
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = responseData is Map && responseData['error'] is String
          ? responseData['error'] as String
          : 'Unable to analyze the dream. Please try again.';
      if (error.response?.statusCode == 402) {
        throw PaywallRequiredException(message);
      }
      throw DreamAnalysisException(message);
    }
  }

  static List<String> getAvailableInterpreters() =>
      interpreterPrompts.keys.toList();

  /// Returns null in demo mode (no backend is ever called) or if the
  /// usage lookup itself fails, so callers can simply hide the badge.
  static Future<UsageInfo?> getUsage() async {
    if (_useDemoAnalysis || _apiBaseUrl.isEmpty) return null;
    try {
      final deviceId = await DeviceIdService.getId();
      final response = await _dio.get<Map<String, dynamic>>(
        '$_apiBaseUrl/usage',
        options: Options(headers: {'X-Device-Id': deviceId}),
      );
      final data = response.data;
      if (data == null) return null;
      return UsageInfo(
        subscribed: data['subscribed'] == true,
        freeUsed: data['freeUsed'] as int? ?? 0,
        freeLimit: data['freeLimit'] as int? ?? 0,
        periodUsed: data['periodUsed'] as int? ?? 0,
        periodLimit: data['periodLimit'] as int? ?? 0,
      );
    } on DioException {
      return null;
    }
  }

  static String _demoAnalysis(String interpreter, bool isTurkish) {
    if (isTurkish) {
      return '$interpreter bakışıyla bu rüya, gündelik hayatın dışına çıkma ve yeni bir perspektif arama isteğini simgeliyor. Bu yerel demo yorumudur; hiçbir API çağrısı yapılmadı.';
    }
    return 'Through $interpreter\'s lens, this dream suggests a wish to step beyond routine and see life from a new perspective. This is a local demo analysis; no API request was made.';
  }
}

class UsageInfo {
  const UsageInfo({
    required this.subscribed,
    required this.freeUsed,
    required this.freeLimit,
    required this.periodUsed,
    required this.periodLimit,
  });

  final bool subscribed;
  final int freeUsed;
  final int freeLimit;
  final int periodUsed;
  final int periodLimit;

  int get remaining =>
      subscribed ? (periodLimit - periodUsed) : (freeLimit - freeUsed);
}

class DreamAnalysisException implements Exception {
  const DreamAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the backend's 402 response signals the free/monthly quota
/// is exhausted, so the UI can show the paywall instead of a generic error.
class PaywallRequiredException extends DreamAnalysisException {
  const PaywallRequiredException(super.message);
}
