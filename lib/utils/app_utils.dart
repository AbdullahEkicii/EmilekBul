import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

class AppUtils {
  /// Localizes a guest username if it starts with "Misafir"
  /// Example: "Misafir11" -> "Guest 11" (if in English)
  static String localizeUsername(String? username) {
    if (username == null || username.isEmpty) {
      return 'account.default_user'.tr();
    }

    final lower = username.toLowerCase();
    final guestPrefixes = ['misafir', 'guest', 'gast', 'invitado', 'invité', 'ospite', 'гость'];
    for (final prefix in guestPrefixes) {
      if (lower.startsWith(prefix)) {
        var remainder = username.substring(prefix.length).trim();
        if (remainder.startsWith('_')) {
          remainder = remainder.substring(1).trim();
        }
        final guestText = 'common.guest'.tr();
        if (remainder.isEmpty) return guestText;
        return '$guestText $remainder';
      }
    }

    return username;
  }

  /// Checks if the device has an active internet connection by looking up google.com
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }
}
