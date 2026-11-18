import 'dart:convert';
import 'package:flutter/material.dart';
import '../constants/app_categories.dart';
import '../models/category_model.dart';
import 'remote_flags.dart';

class ThemedEvent {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final String categoryName;
  final int multiplier;
  final DateTime endsAt;
  final Color accentColor;
  final IconData icon;

  const ThemedEvent({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.categoryName,
    required this.multiplier,
    required this.endsAt,
    required this.accentColor,
    required this.icon,
  });

  CategoryItem? get category {
    for (final c in [...AppCategories.categories, ...AppCategories.bonusPoolCategories]) {
      if (c.name == categoryName) return c;
    }
    return AppCategories.categories.first;
  }
}

/// Haftalık / süreli "Gündem Özel" tematik etkinliklerini yönetir.
/// Remote Config `themed_event_json` ile anında özelleştirilebilir; boşsa haftaya göre otomatik döner.
class ThemedEventService {
  ThemedEventService._();

  static final List<({String id, String titleKey, String subtitleKey, String category, Color color, IconData icon})>
      _presets = [
    (
      id: 'cinema_night',
      titleKey: 'themed_event.cinema_title',
      subtitleKey: 'themed_event.cinema_sub',
      category: 'Sinema ve Dizi',
      color: const Color(0xFFE91E63),
      icon: Icons.movie_filter_rounded,
    ),
    (
      id: 'science_week',
      titleKey: 'themed_event.science_title',
      subtitleKey: 'themed_event.science_sub',
      category: 'Bilim',
      color: const Color(0xFF0A84FF),
      icon: Icons.science_rounded,
    ),
    (
      id: 'derby_special',
      titleKey: 'themed_event.sports_title',
      subtitleKey: 'themed_event.sports_sub',
      category: 'Futbol',
      color: const Color(0xFF10B981),
      icon: Icons.sports_soccer_rounded,
    ),
    (
      id: 'history_marathon',
      titleKey: 'themed_event.history_title',
      subtitleKey: 'themed_event.history_sub',
      category: 'Tarih',
      color: const Color(0xFFFF9F43),
      icon: Icons.history_edu_rounded,
    ),
  ];

  static ThemedEvent currentEvent({DateTime? now, String? overrideJson}) {
    final ref = now ?? DateTime.now();
    final rawJson = overrideJson ?? RemoteFlags.themedEventJson;
    if (rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          final endsMs = (decoded['endsAtMs'] as num?)?.toInt();
          final endsAt = endsMs != null
              ? DateTime.fromMillisecondsSinceEpoch(endsMs)
              : _endOfCurrentWeek(ref);
          if (endsAt.isAfter(ref)) {
            return ThemedEvent(
              id: decoded['id']?.toString() ?? 'custom_event',
              titleKey: decoded['titleKey']?.toString() ?? 'themed_event.default_title',
              subtitleKey: decoded['subtitleKey']?.toString() ?? 'themed_event.default_sub',
              categoryName: decoded['category']?.toString() ?? 'Genel Kültür',
              multiplier: ((decoded['multiplier'] as num?)?.toInt() ?? 2).clamp(2, 5),
              endsAt: endsAt,
              accentColor: const Color(0xFFE91E63),
              icon: Icons.local_fire_department_rounded,
            );
          }
        }
      } catch (_) {}
    }

    final weekOrdinal = ref.difference(DateTime(2024, 1, 1)).inDays ~/ 7;
    final preset = _presets[weekOrdinal.abs() % _presets.length];
    return ThemedEvent(
      id: preset.id,
      titleKey: preset.titleKey,
      subtitleKey: preset.subtitleKey,
      categoryName: preset.category,
      multiplier: 2,
      endsAt: _endOfCurrentWeek(ref),
      accentColor: preset.color,
      icon: preset.icon,
    );
  }

  static DateTime _endOfCurrentWeek(DateTime now) {
    final daysUntilMonday = 8 - now.weekday;
    return DateTime(now.year, now.month, now.day).add(Duration(days: daysUntilMonday));
  }

  static Duration timeRemaining({DateTime? now, String? overrideJson}) {
    final ref = now ?? DateTime.now();
    final diff = currentEvent(now: ref, overrideJson: overrideJson).endsAt.difference(ref);
    return diff.isNegative ? Duration.zero : diff;
  }

  static bool isActiveCategory(String categoryName, {DateTime? now, String? overrideJson}) {
    return currentEvent(now: now, overrideJson: overrideJson).categoryName == categoryName;
  }
}
