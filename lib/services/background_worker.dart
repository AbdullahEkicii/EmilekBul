import 'nudge_engine.dart';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'retention_scheduler.dart';

const String _kUniqueName = 'retention_refresh';
const String _kTaskName = 'retention_refresh_task';

/// WorkManager arka plan giriş noktası (üst seviye + entry-point olmalı).
/// Çalışma süresi çok kısadır: yalnızca hatırlatma planını güncel duruma göre yeniler.
@pragma('vm:entry-point')
void retentionCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      await RetentionScheduler.refresh(fromWorker: true);
      await NudgeEngine.evaluate(fromWorker: true);
      return true;
    } catch (e) {
      debugPrint('Retention worker error: $e');
      return false;
    }
  });
}

/// Arka plan işi: işletim sisteminin yönettiği, pil dostu PERİYODİK görev (≈6 saatte bir).
/// Sürekli çalışan servis DEĞİLDİR; Android (Doze/App Standby) uygun zamanda çalıştırır.
/// Kullanıcı hatırlatmaları kapatırsa görev iptal edilir.
class BackgroundWorker {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      await Workmanager().initialize(retentionCallbackDispatcher);
      _initialized = true;
    } catch (e) {
      debugPrint('BackgroundWorker.init error: $e');
    }
  }

  /// Ayara göre görevi kaydeder veya iptal eder.
  static Future<void> sync() async {
    try {
      await init();
      if (!_initialized) return;
      if (await RetentionScheduler.remindersEnabled()) {
        await Workmanager().registerPeriodicTask(
          _kUniqueName,
          _kTaskName,
          frequency: const Duration(hours: 6),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
          constraints: Constraints(networkType: NetworkType.notRequired),
        );
      } else {
        await Workmanager().cancelByUniqueName(_kUniqueName);
      }
    } catch (e) {
      debugPrint('BackgroundWorker.sync error: $e');
    }
  }
}
