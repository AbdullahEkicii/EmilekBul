import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _flattenKeys(Map<String, dynamic> jsonMap, [String prefix = '']) {
  final keys = <String>{};
  jsonMap.forEach((key, value) {
    final fullKey = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      keys.addAll(_flattenKeys(value, fullKey));
    } else if (value is Map) {
      keys.addAll(_flattenKeys(Map<String, dynamic>.from(value), fullKey));
    } else {
      keys.add(fullKey);
    }
  });
  return keys;
}

void main() {
  test('all 26 translation files parse cleanly and have identical keys', () {
    final dir = Directory('assets/translations');
    expect(dir.existsSync(), isTrue);

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    expect(files.length, 26);

    final keySets = <String, Set<String>>{};
    for (final file in files) {
      final decoded = jsonDecode(file.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      final name = file.uri.pathSegments.last;
      keySets[name] = _flattenKeys(decoded as Map<String, dynamic>);
    }

    final baseKeys = keySets['en.json']!;
    expect(baseKeys, isNotEmpty);

    for (final entry in keySets.entries) {
      final missing = baseKeys.difference(entry.value);
      final extra = entry.value.difference(baseKeys);
      expect(
        missing,
        isEmpty,
        reason: '${entry.key} is missing keys: $missing',
      );
      expect(
        extra,
        isEmpty,
        reason: '${entry.key} has extra keys: $extra',
      );
    }
  });
}
