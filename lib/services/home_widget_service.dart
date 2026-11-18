import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'streak_service.dart';
import 'token_service.dart';

/// Ana ekran widget'ına (streak + token) veri iter (Android & iOS Dart katmanı).
/// Native widget ekranda/hedefte yoksa güncelleme sessizce no-op'tur; exception fırlatmaz.
class HomeWidgetService {
  static const String _androidProvider = 'HomeWidgetProvider';
  static const String _qualifiedAndroidProvider =
      'com.abdullahekici.emilekbul.HomeWidgetProvider';
  static const String _iOSAppGroupId = 'group.com.abdullahekici.emilekbul';
  static const String _iOSWidgetKind = 'EmilekbulHomeWidget';

  static const String _keyStreak = 'widget_streak';
  static const String _keyTokens = 'widget_tokens';

  static Future<void> refresh() async {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    if (!isAndroid && !isIOS) return;

    try {
      if (isIOS) {
        await HomeWidget.setAppGroupId(_iOSAppGroupId);
      }
      final streak = await StreakService.getStreakCount();
      final tokens = await TokenService.getTokenAmount();
      await HomeWidget.saveWidgetData<int>(_keyStreak, streak);
      await HomeWidget.saveWidgetData<int>(_keyTokens, tokens);
      await HomeWidget.updateWidget(
        androidName: isAndroid ? _androidProvider : null,
        qualifiedAndroidName: isAndroid ? _qualifiedAndroidProvider : null,
        iOSName: isIOS ? _iOSWidgetKind : null,
      );
    } catch (e) {
      debugPrint('HomeWidgetService.refresh error: $e');
    }
  }
}
