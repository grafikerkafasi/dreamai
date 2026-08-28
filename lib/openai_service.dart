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

    if (_useDemoAnalysis) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      // The offline demo text is canned, so there is no model to judge the
      // language for us — a diacritic guess is the best available option
      // here, and only picks between two hardcoded strings.
      final looksTurkish = RegExp(r'[şğıçöüİŞĞÇÖÜ]').hasMatch(dream);
      return _demoAnalysis(interpreter, looksTurkish);
    }

    if (_apiBaseUrl.isEmpty) {
      throw const DreamAnalysisException(
        'Analysis service URL is not configured.',
      );
    }

    // Always the English persona: it is an instruction *to* the model, not
    // the language it should answer in. Handing the model a Turkish persona
    // used to be what silently forced Turkish output, so the reply language
    // is now stated once, explicitly, and left for the model to resolve.
    final systemMessage = interpreterPrompts[interpreter] ??
        'Act like $interpreter and interpret the dream.';

    try {
      // Deliberately names no language. The model identifies the dream's
      // language itself — including text typed without its diacritics —
      // which is the whole point: users get an answer in whatever language
      // they wrote in, not in one of two we tried to guess between.
      const languageDirective = 'IMPORTANT: Write your entire reply in the '
          'same language the dream above is written in. Judge that from the '
          "dream's own words, and do not switch to another language even if "
          'these instructions are in English; the very first word of your '
          'reply must already be in the dream\'s language.';
      // Every persona prompt used to include a fixed quoted opening line
      // ("Begin with: '...'"), which made every reply from a given
      // interpreter start with the exact same sentence regardless of the
      // dream — repetitive enough to read as a templated bot. Openers are
      // no longer specified per persona; this directive replaces them with
      // an instruction to vary instead, shared across all interpreters.
      const varietyDirective = 'IMPORTANT: Do not open with a fixed or '
          'memorized phrase — invent a fresh opening line every time, '
          'grounded in this specific dream\'s actual details rather than a '
          'generic mood-setting sentence. Be direct, surprising, and '
          'confidently assertive in your interpretation rather than '
          'cautious or generic.';
      final deviceId = await DeviceIdService.getId();
      final response = await _dio.post<Map<String, dynamic>>(
        '$_apiBaseUrl/analyze',
        data: {
          'prompt': 'Dream:\n$dream\n\n$systemMessage\n\n'
              '$varietyDirective\n\n$languageDirective'
        },
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
        extraCredits: data['extraCredits'] as int? ?? 0,
      );
    } on DioException {
      return null;
    }
  }

  /// Tells the backend to look up any credit-pack purchases on RevenueCat
  /// that haven't been applied locally yet (belt-and-suspenders alongside
  /// the /revenuecat-webhook path — see revenuecat_client.js). Safe to call
  /// right after a purchase completes; returns the refreshed usage, or null
  /// if the lookup itself failed.
  static Future<UsageInfo?> redeemCredits() async {
    if (_useDemoAnalysis || _apiBaseUrl.isEmpty) return null;
    try {
      final deviceId = await DeviceIdService.getId();
      final response = await _dio.post<Map<String, dynamic>>(
        '$_apiBaseUrl/redeem-credits',
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
        extraCredits: data['extraCredits'] as int? ?? 0,
      );
    } on DioException {
      return null;
    }
  }

  /// Mirrors [redeemCredits], but for the subscription side: the
  /// RevenueCat webhook usually flips `subscribed` on within a few
  /// seconds of a purchase, but [getUsage] alone just reads whatever's
  /// already in the backend's DB — no self-heal — so calling it right
  /// after a successful subscribe/restore can still show the pre-purchase
  /// total if the webhook hasn't landed yet. This asks the backend to
  /// double-check RevenueCat directly first.
  static Future<UsageInfo?> syncSubscription() async {
    if (_useDemoAnalysis || _apiBaseUrl.isEmpty) return null;
    try {
      final deviceId = await DeviceIdService.getId();
      final response = await _dio.post<Map<String, dynamic>>(
        '$_apiBaseUrl/sync-subscription',
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
        extraCredits: data['extraCredits'] as int? ?? 0,
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
    this.extraCredits = 0,
  });

  final bool subscribed;
  final int freeUsed;
  final int freeLimit;
  final int periodUsed;
  final int periodLimit;
  final int extraCredits;

  int get remaining =>
      (subscribed ? (periodLimit - periodUsed) : (freeLimit - freeUsed)) +
      extraCredits;
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
