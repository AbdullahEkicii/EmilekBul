import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PerformanceService {
  static bool _performanceModeEnabled = false;
  static bool _isInitialized = false;

  /// Initializes the performance service and loads preference.
  /// Kullanıcı hiç tercih kaydetmediyse varsayılan cihaz kademesine göre belirlenir.
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('performance_mode');
      _performanceModeEnabled = saved ?? await _isLowEndDevice();
      _isInitialized = true;
    } catch (e) {
      debugPrint('PerformanceService init error: $e');
    }
  }

  /// Düşük RAM'li Android cihazları (~3 GB altı) düşük uç kabul eder.
  static Future<bool> _isLowEndDevice() async {
    try {
      if (!Platform.isAndroid) return false;
      final info = await DeviceInfoPlugin().androidInfo;
      // Emülatör yazılım GPU ile çizer; efekt yoğun ekranlar orada çöker. Gerçek cihazlar etkilenmez.
      if (!info.isPhysicalDevice) return true;
      if (info.isLowRamDevice) return true;
      return info.physicalRamSize > 0 && info.physicalRamSize < 3000;
    } catch (_) {
      return false;
    }
  }

  static bool get isPerformanceMode => _performanceModeEnabled;

  /// Performans modunda pahalı BackdropFilter blur'ünü atlar (animasyonlar etkilenmez).
  static Widget blur({required double sigma, required Widget child}) {
    if (_performanceModeEnabled) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }

  /// Enables or disables performance mode
  static Future<void> setPerformanceMode(bool enabled) async {
    _performanceModeEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('performance_mode', enabled);
    } catch (e) {
      debugPrint('Error saving performance setting: $e');
    }
  }
}
