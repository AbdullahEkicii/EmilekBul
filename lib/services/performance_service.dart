import 'package:shared_preferences/shared_preferences.dart';

class PerformanceService {
  static bool _performanceModeEnabled = false;
  static bool _isInitialized = false;

  /// Initializes the performance service and loads preference
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _performanceModeEnabled = prefs.getBool('performance_mode') ?? true;
      _isInitialized = true;
    } catch (e) {
      print('PerformanceService init error: $e');
    }
  }

  static bool get isPerformanceMode => _performanceModeEnabled;

  /// Enables or disables performance mode
  static Future<void> setPerformanceMode(bool enabled) async {
    _performanceModeEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('performance_mode', enabled);
    } catch (e) {
      print('Error saving performance setting: $e');
    }
  }
}
