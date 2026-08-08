import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FullScreenService {
  static bool _isFullScreen = true; // default
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isFullScreen = prefs.getBool('full_screen') ?? true;
      _isInitialized = true;
      applyCurrentMode();
    } catch (e) {
      debugPrint('FullScreenService init error: $e');
    }
  }

  static bool get isFullScreen => _isFullScreen;

  static Future<void> setFullScreen(bool enabled) async {
    _isFullScreen = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('full_screen', enabled);
      applyCurrentMode();
    } catch (e) {
      debugPrint('Error saving full screen setting: $e');
    }
  }

  static void applyCurrentMode() {
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Wait to apply overlay style to ensure edgeToEdge is applied
      Future.delayed(const Duration(milliseconds: 100), () {
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          statusBarColor: Color(0x00000000), // Colors.transparent
          systemNavigationBarColor: Color(0x00000000), // Colors.transparent
          systemNavigationBarDividerColor: Color(0x00000000),
        ));
      });
    }
  }
}
