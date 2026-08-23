import 'package:flutter/material.dart';
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

  /// Localizes standard difficulty names into current app language
  static String localizeDifficulty(String? difficulty) {
    if (difficulty == null || difficulty.isEmpty) return '';
    final diffLower = difficulty.toLowerCase().trim();
    if (diffLower == 'kolay' || diffLower == 'easy') {
      return 'category_ui.difficulty.easy'.tr();
    } else if (diffLower == 'orta' || diffLower == 'medium') {
      return 'category_ui.difficulty.medium'.tr();
    } else if (diffLower == 'zor' || diffLower == 'hard') {
      return 'category_ui.difficulty.hard'.tr();
    } else if (diffLower == 'imkansız' || diffLower == 'imkansiz' || diffLower == 'impossible') {
      return 'category_ui.difficulty.impossible'.tr();
    }
    return difficulty;
  }

  /// Gets standard color representation for a difficulty level
  static Color getDifficultyColor(String? difficulty) {
    if (difficulty == null) return const Color(0xFF10B981);
    final diffLower = difficulty.toLowerCase().trim();
    if (diffLower == 'kolay' || diffLower == 'easy') {
      return const Color(0xFF10B981); // Emerald Green
    } else if (diffLower == 'orta' || diffLower == 'medium') {
      return const Color(0xFFFF9F43); // Warm Orange
    } else if (diffLower == 'zor' || diffLower == 'hard') {
      return const Color(0xFFEF4444); // Crimson Red
    } else if (diffLower == 'imkansız' || diffLower == 'imkansiz' || diffLower == 'impossible') {
      return const Color(0xFFA855F7); // Purple
    }
    return const Color(0xFF6366F1);
  }
}
