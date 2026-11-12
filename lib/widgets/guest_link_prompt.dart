import 'package:flutter/material.dart';
import 'glass_alert_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_register_screen.dart';
import '../services/analytics_service.dart';

/// Misafir (bağlanmamış anonim) kullanıcıya hesabını kaydetmeyi öneren kapatılabilir dialog.
/// Tetikler: 'first_quiz' (en az 1 tamamlanan test) ve 'day2' (ilk açılışın ertesi günü ve sonrası).
/// Her tetik tek sefer; 'Sonra'ya basılırsa en az 3 gün tekrar sorulmaz.
class GuestLinkPrompt {
  static const _kFirstOpen = 'guest_link_first_open_ms';
  static const _kLastDismiss = 'guest_link_last_dismiss_ms';
  static const _kOfferedPrefix = 'guest_link_offered_';
  static const _cooldown = Duration(days: 3);

  /// Gösterilmesi gereken tetik ('first_quiz' / 'day2') ya da null.
  static Future<String?> pendingTrigger(int completedQuizzes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final firstOpenMs = prefs.getInt(_kFirstOpen);
      if (firstOpenMs == null) {
        await prefs.setInt(_kFirstOpen, now.millisecondsSinceEpoch);
      }
      final lastDismiss = prefs.getInt(_kLastDismiss);
      if (lastDismiss != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(lastDismiss)) < _cooldown) {
        return null;
      }
      if (completedQuizzes >= 1 && !(prefs.getBool('${_kOfferedPrefix}first_quiz') ?? false)) {
        return 'first_quiz';
      }
      if (firstOpenMs != null) {
        final first = DateTime.fromMillisecondsSinceEpoch(firstOpenMs);
        final dayDiff = DateTime(now.year, now.month, now.day)
            .difference(DateTime(first.year, first.month, first.day))
            .inDays;
        if (dayDiff >= 1 && !(prefs.getBool('${_kOfferedPrefix}day2') ?? false)) {
          return 'day2';
        }
      }
    } catch (e) {
      debugPrint('GuestLinkPrompt.pendingTrigger error: $e');
    }
    return null;
  }

  static Future<void> show(BuildContext context, String trigger) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_kOfferedPrefix$trigger', true);
    } catch (_) {}
    AnalyticsService.logCustomEvent(name: 'guest_link_offered', parameters: {'trigger': trigger});
    if (!context.mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        backgroundColor: const Color(0xFF1E1B3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: Color(0xFFA67BFF)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('guest_link.title'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text('guest_link.body'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('guest_link.later'.tr(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F7CFF),
              foregroundColor: Colors.white,
            ),
            child: Text('guest_link.save'.tr()),
          ),
        ],
      ),
    );

    if (accepted == true) {
      AnalyticsService.logCustomEvent(name: 'guest_link_accepted', parameters: {'trigger': trigger});
      if (!context.mounted) return;
      // Hesap ekranındaki misafir kartıyla aynı akış
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginRegisterScreen(onStart: () {}, isForced: false),
        ),
      );
    } else {
      AnalyticsService.logCustomEvent(name: 'guest_link_dismissed', parameters: {'trigger': trigger});
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kLastDismiss, DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}
    }
  }
}
