import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'analytics_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  debugPrint('FCM background message: ${message.messageId}');
}

/// Sunucu taraflı push bildirim yöneticisi (FCM):
/// - Token'ı `users/{uid}.fcmToken` alanına senkronize eder.
/// - Etkinlik/turnuva konularına (`global_events`) abone olur.
/// - Ön planda gelen bildirimleri [NotificationService] ile gösterir.
class PushNotificationService {
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<User?>? _authSub;

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _syncCurrentToken();
        await messaging.subscribeToTopic('global_events');
      }

      _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen(_saveTokenForCurrentUser);

      _authSub?.cancel();
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _syncCurrentToken();
        }
      });

      FirebaseMessaging.onMessage.listen((message) {
        final notif = message.notification;
        final title = notif?.title ?? message.data['title']?.toString();
        final body = notif?.body ?? message.data['body']?.toString();
        if (title != null && body != null && title.isNotEmpty && body.isNotEmpty) {
          NotificationService.showRemoteMessageNotification(
            title: title,
            body: body,
            payload: message.data['type']?.toString() ?? 'fcm',
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        AnalyticsService.logNotificationOpen(
          type: message.data['type']?.toString() ?? 'fcm_push',
        );
      });
    } catch (e) {
      debugPrint('PushNotificationService init error: $e');
    }
  }

  static Future<void> _syncCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveTokenForCurrentUser(token);
      }
    } catch (e) {
      debugPrint('FCM getToken error: $e');
    }
  }

  static Future<void> _saveTokenForCurrentUser(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FCM token save error: $e');
    }
  }

  /// Kullanıcı bildirim izni verdiğinde çağrılabilir; token ve konu aboneliğini tazeler.
  static Future<void> onPermissionGranted() async {
    try {
      await _syncCurrentToken();
      await FirebaseMessaging.instance.subscribeToTopic('global_events');
    } catch (e) {
      debugPrint('FCM onPermissionGranted error: $e');
    }
  }
}
