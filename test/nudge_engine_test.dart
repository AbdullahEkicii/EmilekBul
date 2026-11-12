import 'package:flutter_test/flutter_test.dart';
import 'package:emilekbul/services/behavior_tracker.dart';
import 'package:emilekbul/services/nudge_engine.dart';

BehaviorSnapshot snap({
  Map<String, int> uses = const {},
  Map<String, int> last = const {},
  Map<String, int> cats = const {},
  List<String> days = const [],
  Map<int, int> hours = const {},
  required DateTime now,
}) =>
    BehaviorSnapshot(
      uses: uses,
      lastUsedMs: last,
      categoryPlays: cats,
      playDays: days,
      hourHistogram: hours,
      now: now,
    );

NudgeInput input(BehaviorSnapshot s, {String date = '2026-10-21', int weeklyDays = 0, bool claimed = false,
    Map<String, String> lastSent = const {}, List<String> sentDays = const [], String? weak}) =>
    NudgeInput(
      snap: s,
      date: date,
      weeklyDays: weeklyDays,
      weeklyClaimed: claimed,
      weakTopic: weak,
      weakPct: weak == null ? 0 : 35,
      lastSent: lastSent,
      sentDays: sentDays,
    );

void main() {
  final now = DateTime(2026, 10, 21, 14);
  final todayStr = '2026-10-21';

  test('bugün oynayan oyuncuya bildirim gönderilmez', () {
    final s = snap(days: [todayStr], uses: {'solo': 3}, now: now);
    expect(NudgeEngine.choose(input(s)), isNull);
  });

  test('haftalık sandık: 2 gün oynandıysa "2 gün daha" (kalan 2)', () {
    final s = snap(now: now);
    final c = NudgeEngine.choose(input(s, weeklyDays: 2));
    expect(c?.id, 'weekly');
    expect(c?.args, ['2']);
  });

  test('haftalık sandık alınmışsa önerilmez', () {
    final s = snap(now: now);
    expect(NudgeEngine.choose(input(s, weeklyDays: 3, claimed: true))?.id == 'weekly', isFalse);
  });

  test('favori kategori: en az 3 oyunla belirlenir', () {
    final s = snap(cats: {'Genel Kültür': 3, 'Müzik': 1}, now: now);
    final c = NudgeEngine.choose(input(s));
    expect(c?.id, 'fav');
    expect(c?.args, ['Genel Kültür']);
    final few = snap(cats: {'Müzik': 2}, now: now);
    expect(NudgeEngine.choose(input(few))?.id == 'fav', isFalse);
  });

  test('bekleme süresi: aynı aday 2 gün içinde tekrar gönderilmez', () {
    final s = snap(cats: {'Genel Kültür': 5}, now: now);
    final c = NudgeEngine.choose(input(s, lastSent: {'fav': '2026-10-21'}));
    expect(c?.id == 'fav', isFalse);
  });

  test('haftalık sınır: son 7 günde 4 bildirim varsa yeni bildirim yok', () {
    final s = snap(cats: {'Genel Kültür': 5}, now: now);
    expect(NudgeEngine.choose(input(s, sentDays: ['2026-10-18', '2026-10-19', '2026-10-20', '2026-10-21'])), isNull);
  });

  test('hiç denenmemiş özellik yalnızca keşfedilebilir listeden seçilir', () {
    final s = snap(now: now);
    final c = NudgeEngine.choose(input(s));
    expect(c?.id, 'never');
    expect(NudgeEngine.discoverable.contains(c!.args.first), isTrue);
  });

  test('uzun süre oynamayan: 3+ gün sonra "geri dön"', () {
    final last = now.subtract(const Duration(days: 5)).millisecondsSinceEpoch;
    final s = snap(uses: {'solo': 4}, last: {'solo': last}, now: now);
    final c = NudgeEngine.choose(input(s));
    expect(c, isNotNull);
    expect(['lapsed', 'dormant'].contains(c!.id), isTrue);
  });

  test('tercih edilen saat: en az 5 örnek yoksa null, varsa en sık saat', () {
    expect(snap(hours: {20: 3}, now: now).preferredHour(), isNull);
    expect(snap(hours: {20: 4, 9: 1}, now: now).preferredHour(), 20);
  });

  test('nextSlot: saat geçmişse yarına, değilse bugüne kayar', () {
    final morning = DateTime(2026, 10, 21, 10);
    expect(NudgeEngine.nextSlot(morning, 19, minuteSeed: 0).day, 21);
    final evening = DateTime(2026, 10, 21, 21);
    expect(NudgeEngine.nextSlot(evening, 19, minuteSeed: 0).day, 22);
  });

  test('dakika :00 kümelenmesini önler (7–46 arası)', () {
    for (var seed = 0; seed < 200; seed++) {
      final m = NudgeEngine.nextSlot(DateTime(2026, 10, 21, 10), 19, minuteSeed: seed).minute;
      expect(m >= 7 && m <= 46, isTrue);
    }
  });
}
