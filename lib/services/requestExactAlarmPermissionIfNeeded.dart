import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class NotificationPermissionManager {
  /// Tüm bildirim izinlerini kontrol eder ve gerekirse ister
  static Future<bool> requestAllNotificationPermissions(
      BuildContext context) async {
    if (!Platform.isAndroid) return true;

    bool allPermissionsGranted = true;
    final androidInfo = await DeviceInfoPlugin().androidInfo;

    // 1. Normal bildirim izni (Android 13+ için)
    if (androidInfo.version.sdkInt >= 33) {
      final notificationStatus = await Permission.notification.status;
      if (notificationStatus.isDenied) {
        // Kullanıcıya açıklama göster
        final shouldRequest = await _showPermissionDialog(
          context,
          'Bildirim İzni',
          'Günlük ödüller ve hatırlatıcılar için bildirim izni gerekiyor.',
          'Bildirim İzni Ver',
        );

        if (shouldRequest) {
          final result = await Permission.notification.request();
          if (!result.isGranted) {
            allPermissionsGranted = false;
            _showPermissionSettingsDialog(context, 'Bildirim İzni');
          }
        } else {
          allPermissionsGranted = false;
        }
      }
    }

    // 2. Exact Alarm izni (Android 12+ için hassas zamanlama)
    if (androidInfo.version.sdkInt >= 31) {
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      if (exactAlarmStatus.isDenied) {
        final shouldRequest = await _showPermissionDialog(
          context,
          'Hassas Alarm İzni',
          'Tam zamanında bildirimler için hassas alarm izni gerekiyor.',
          'Alarm İzni Ver',
        );

        if (shouldRequest) {
          // Exact alarm için settings sayfasına yönlendir
          await _openExactAlarmSettings();

          // Kullanıcıya ne yapması gerektiğini söyle
          await _showInstructionDialog(
            context,
            'Alarm İzni Ayarı',
            'Açılan ayarlar sayfasında "${await _getAppName()}" uygulaması için "Alarm ve hatırlatıcılar" iznini açın.',
          );
        } else {
          allPermissionsGranted = false;
        }
      }
    }

    return allPermissionsGranted;
  }

  /// Basit versiyon - dialog olmadan otomatik istek
  static Future<void> requestNotificationPermissionsSimple() async {
    if (!Platform.isAndroid) return;

    final androidInfo = await DeviceInfoPlugin().androidInfo;

    // Normal bildirim izni
    if (androidInfo.version.sdkInt >= 33) {
      await Permission.notification.request();
    }

    // Exact alarm izni
    if (androidInfo.version.sdkInt >= 31) {
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      if (exactAlarmStatus.isDenied) {
        await _openExactAlarmSettings();
      }
    }
  }

  /// Exact alarm ayarları sayfasını açar
  static Future<void> _openExactAlarmSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();
  }

  /// İzin açıklama dialogu
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
                  Icon(Icons.notifications_active, color: Color(0xFF7F7CFF)),
                  SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: Color(0xFF7F7CFF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                message,
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Şimdi Değil',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF7F7CFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Ayarlara yönlendirme dialogu
  static Future<void> _showPermissionSettingsDialog(
    BuildContext context,
    String permissionName,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'İzin Gerekli',
            style: TextStyle(
              color: Colors.orange[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '$permissionName reddedildi. Ayarlardan manuel olarak açabilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Tamam'),
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
                'Ayarlara Git',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Kullanıcı talimatları dialogu
  static Future<void> _showInstructionDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Color(0xFF7F7CFF),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7F7CFF),
              ),
              child: Text(
                'Anladım',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Uygulama adını al
  static Future<String> _getAppName() async {
    // Bu kısımda package_info_plus kullanabilirsiniz
    // Şimdilik sabit döndürüyoruz
    return "Emile Kbul";
  }

  /// Tüm izinlerin durumunu kontrol et
  static Future<Map<String, bool>> checkAllPermissions() async {
    final Map<String, bool> permissions = {};

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      // Normal bildirim izni durumu
      if (androidInfo.version.sdkInt >= 33) {
        permissions['notification'] = await Permission.notification.isGranted;
      } else {
        permissions['notification'] = true; // Eski sürümlerde otomatik granted
      }

      // Exact alarm izni durumu
      if (androidInfo.version.sdkInt >= 31) {
        permissions['exactAlarm'] =
            await Permission.scheduleExactAlarm.isGranted;
      } else {
        permissions['exactAlarm'] = true; // Eski sürümlerde gerekli değil
      }
    } else {
      permissions['notification'] = true;
      permissions['exactAlarm'] = true;
    }

    return permissions;
  }
}
