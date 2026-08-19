import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A stable per-install identifier used both as the backend's quota key
/// and as RevenueCat's app_user_id, so the two systems agree on who a
/// "user" is without requiring an account or login.
class DeviceIdService {
  static const _key = 'device_id';
  static String? _cached;

  static Future<String> getId() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }
}
