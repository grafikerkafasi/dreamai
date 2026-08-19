import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DreamStorageService {
  static const _key = 'dream_history';
  static const _maxEntries = 100;

  // Rüyayı ve yorumunu kaydet
  static Future<void> saveDream(String dream, String result) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_key) ?? [];

    final newEntry = jsonEncode({
      'dream': dream,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    });

    current.add(newEntry);
    if (current.length > _maxEntries) {
      current.removeRange(0, current.length - _maxEntries);
    }
    await prefs.setStringList(_key, current);
  }

  // Tüm rüyaları getir
  static Future<List<Map<String, dynamic>>> loadDreams() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_key) ?? [];

    final dreams = <Map<String, dynamic>>[];
    for (final rawEntry in rawList) {
      try {
        final decoded = jsonDecode(rawEntry);
        if (decoded is Map) {
          final dream = decoded['dream'];
          final result = decoded['result'];
          if (dream is String && result is String) {
            dreams.add(Map<String, dynamic>.from(decoded));
          }
        }
      } on FormatException {
        // Ignore legacy or corrupt entries instead of breaking the history view.
      }
    }
    if (dreams.length != rawList.length) {
      await prefs.setStringList(
        _key,
        dreams.map(jsonEncode).toList(growable: false),
      );
    }
    return dreams;
  }

  // Belirli rüyayı sil
  static Future<void> deleteDream(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_key) ?? [];
    if (index >= 0 && index < current.length) {
      current.removeAt(index);
      await prefs.setStringList(_key, current);
    }
  }
}
