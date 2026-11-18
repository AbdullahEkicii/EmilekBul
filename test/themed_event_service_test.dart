import 'dart:convert';

import 'package:emilekbul/services/themed_event_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemedEventService', () {
    test('weekly rotation alternates between themed presets', () {
      final w0 = ThemedEventService.currentEvent(
        now: DateTime(2024, 1, 3),
        overrideJson: '',
      );
      final w1 = ThemedEventService.currentEvent(
        now: DateTime(2024, 1, 10),
        overrideJson: '',
      );
      expect(w0.id, isNot(equals(w1.id)));
      expect(w0.multiplier, 2);
      expect(w0.category, isNotNull);
    });

    test('Remote Config JSON overrides weekly preset when future endsAtMs given', () {
      final futureMs =
          DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch;
      final override = jsonEncode({
        'id': 'remote_space',
        'titleKey': 'themed_event.science_title',
        'subtitleKey': 'themed_event.science_sub',
        'category': 'Bilim',
        'multiplier': 3,
        'endsAtMs': futureMs,
      });

      final event = ThemedEventService.currentEvent(overrideJson: override);
      expect(event.id, 'remote_space');
      expect(event.categoryName, 'Bilim');
      expect(event.multiplier, 3);
      expect(
        ThemedEventService.isActiveCategory('Bilim', overrideJson: override),
        isTrue,
      );
      expect(
        ThemedEventService.isActiveCategory('Tarih', overrideJson: override),
        isFalse,
      );
    });

    test('expired Remote Config override falls back to weekly event', () {
      final pastMs = DateTime(2020, 1, 1).millisecondsSinceEpoch;
      final expiredOverride = jsonEncode({
        'id': 'old_event',
        'category': 'Müzik',
        'endsAtMs': pastMs,
      });

      final event = ThemedEventService.currentEvent(
        now: DateTime(2024, 1, 3),
        overrideJson: expiredOverride,
      );
      expect(event.id, isNot('old_event'));
    });

    test('timeRemaining returns positive duration before week ends', () {
      final remaining = ThemedEventService.timeRemaining(
        now: DateTime(2024, 1, 3, 12),
        overrideJson: '',
      );
      expect(remaining.inHours, greaterThan(0));
    });
  });
}
