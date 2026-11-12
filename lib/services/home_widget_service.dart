import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'streak_service.dart';
import 'token_service.dart';

/// Android ana ekran widget'ına (streak + token) veri iter.
/// Widget ekranda yoksa güncelleme sessizce bir no-op'tur; hiçbir zaman exception fırlatmaz.
class HomeWidgetService {
  static const String _androidProvider = 'HomeWidgetProvider';
  static const String _qualifiedAndroidProvider =
      'com.abdullahekici.emilekbul.HomeWidgetProvider';

  static const String _keyStreak = 'widget_streak';
  static const String _keyTokens = 'widget_tokens';

  static Future<void> refresh() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final streak = await StreakService.getStreakCount();
      final tokens = await TokenService.getTokenAmount();
      await HomeWidget.saveWidgetData<int>(_keyStreak, streak);
      await HomeWidget.saveWidgetData<int>(_keyTokens, tokens);
      await HomeWidget.updateWidget(
        androidName: _androidProvider,
        qualifiedAndroidName: _qualifiedAndroidProvider,
      );
    } catch (e) {
      debugPrint('HomeWidgetService.refresh error: $e');
    }
  }
}
