import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPermissionManager {
  static bool _hasCheckedCount = false;
  static bool _hasPromptedThisSession = false;

  /// Sadece bildirim izni kontrolü (Android 13+)
  static Future<bool> notificationPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt < 33) return true;

    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isGranted) return true;

    final prefs = await SharedPreferences.getInstance();
    
    // Uygulama başlatma sayısını artır (oturum başına bir kez)
    if (!_hasCheckedCount) {
      _hasCheckedCount = true;
      int count = (prefs.getInt('app_notification_prompt_launch_count') ?? 0) + 1;
      await prefs.setInt('app_notification_prompt_launch_count', count);
    }
    
    // Bu oturumda zaten sorulduysa tekrar sorma
    if (_hasPromptedThisSession) return false;

    int currentLaunchCount = prefs.getInt('app_notification_prompt_launch_count') ?? 1;
    final List<int> targetLaunches = [5, 15, 30, 45];

    // Belirlenen giriş sayıları dışında izin isteme
    if (!targetLaunches.contains(currentLaunchCount)) {
      return false; 
    }

    // Bu oturumda soruldu olarak işaretle
    _hasPromptedThisSession = true;

    bool allPermissionsGranted = true;

    if (notificationStatus.isPermanentlyDenied) {
      allPermissionsGranted = false;
      if (!context.mounted) return false;
      await _showPermissionSettingsDialog(context);
    } else if (!notificationStatus.isGranted) {
      // isDenied veya diğer durumlar (isLimited, isRestricted vs.)
      if (!context.mounted) return false;
      final shouldRequest = await _showPermissionDialog(
        context,
        'notifications.permission_title'.tr(),
        'notifications.permission_desc'.tr(),
        'notifications.grant_button'.tr(),
      );

      if (shouldRequest) {
        final result = await Permission.notification.request();
        if (result.isPermanentlyDenied) {
          allPermissionsGranted = false;
          if (!context.mounted) return false;
          await _showPermissionSettingsDialog(context);
        } else if (!result.isGranted) {
          allPermissionsGranted = false;
        }
      } else {
        allPermissionsGranted = false;
      }
    }

    return allPermissionsGranted;
  }

  /// Basit bildirim izni isteği (dialog yok)
  static Future<void> requestNotificationPermissionsSimple() async {
    if (!Platform.isAndroid) return;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      await Permission.notification.request();
    }
  }

  /// Bildirim izni açıklama dialogu
  static Future<bool> _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
    String buttonText,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.notifications_active,
                      color: Color(0xFF7F7CFF)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF7F7CFF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'notifications.not_now'.tr(),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7F7CFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Ayarlar yönlendirme dialogu
  static Future<void> _showPermissionSettingsDialog(
    BuildContext context,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'notifications.required_title'.tr(),
            style: TextStyle(
              color: Colors.orange[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'notifications.denied_message'.tr(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('notifications.ok'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
              ),
              child: Text(
                'notifications.go_to_settings'.tr(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Bildirim izni durumunu kontrol et
  static Future<Map<String, bool>> checkAllPermissions() async {
    final Map<String, bool> permissions = {};

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        permissions['notification'] = await Permission.notification.isGranted;
      } else {
        permissions['notification'] = true;
      }
    } else {
      permissions['notification'] = true;
    }

    return permissions;
  }
}
