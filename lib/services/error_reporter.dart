

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Hata ve çökme raporlama (Firebase Crashlytics).
/// Debug derlemelerde toplama kapalıdır; yalnızca konsola yazar.
/// Fatal olmayan hatalar (misafir girişi, soru yükleme vb.) `record` ile gönderilir.
class ErrorReporter {
  static bool _ready = false;

  static Future<void> init() async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (_ready) FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (_ready) FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      _ready = true;
    } catch (e) {
      debugPrint('ErrorReporter init error: $e');
    }
  }

  /// Fatal olmayan hata: akış devam eder, ancak Crashlytics'te görünür.
  static void record(Object error, StackTrace? stack, {String reason = ''}) {
    debugPrint('ErrorReporter[$reason]: $error');
    if (!_ready || kDebugMode) return;
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack ?? StackTrace.current,
        reason: reason,
        fatal: false,
      );
    } catch (_) {}
  }

  /// Sonraki çökme/hata raporuna eklenecek kısa iz bırakır.
  static void breadcrumb(String message) {
    if (!_ready || kDebugMode) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }
}
