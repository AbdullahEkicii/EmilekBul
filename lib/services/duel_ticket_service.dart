import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'cloud_state_service.dart';
import 'token_service.dart';

enum BetPaymentMethod { free, ticket, tokens, insufficient }

/// Düello bahis ödemesi: 0 bahis (dostluk maçı) ücretsizdir; [maxTicketBet] ve altı
/// bahislerde önce günlük ücretsiz bilet kullanılır, bilet yoksa jeton düşülür.
class DuelTicketService {
  static const int ticketsPerDay = 3;
  static const int maxTicketBet = 10;
  static const int defaultBet = 10;

  static const String _dateKey = 'duel_tickets_date';
  static const String _usedKey = 'duel_tickets_used';

  // Bu oturumda bahsi biletle ödenen odalar (sonuç ekranı ve iade mantığı için)
  static final Set<String> _ticketRooms = {};

  static bool paidWithTicket(String roomCode) => _ticketRooms.contains(roomCode);

  static String _today() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  static Future<int> ticketsLeft() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_dateKey) != _today()) return ticketsPerDay;
    return (ticketsPerDay - (prefs.getInt(_usedKey) ?? 0)).clamp(0, ticketsPerDay);
  }

  static bool canCover({required int bet, required int tokens, required int tickets}) =>
      bet <= 0 || (bet <= maxTicketBet && tickets > 0) || tokens >= bet;

  static Future<BetPaymentMethod> payBet(int bet, {String? roomCode}) async {
    if (roomCode != null) _ticketRooms.remove(roomCode);
    if (bet <= 0) return BetPaymentMethod.free;
    if (bet <= maxTicketBet && await ticketsLeft() > 0) {
      await _useTicket();
      if (roomCode != null) _ticketRooms.add(roomCode);
      AnalyticsService.logCustomEvent(name: 'duel_ticket_used', parameters: {'bet': bet});
      return BetPaymentMethod.ticket;
    }
    final paid = await TokenService.spendTokens(bet, reason: 'duel_bet');
    return paid ? BetPaymentMethod.tokens : BetPaymentMethod.insufficient;
  }

  static Future<void> _useTicket() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final used = prefs.getString(_dateKey) == today ? (prefs.getInt(_usedKey) ?? 0) : 0;
    await prefs.setString(_dateKey, today);
    await prefs.setInt(_usedKey, used + 1);
    await CloudStateService.save('duelTickets', {'date': today, 'used': used + 1});
  }

  /// Aynı gün için buluttaki kullanım yereldekinden fazlaysa onu uygular (yeniden kurulum istismarını önler).
  static Future<void> importState(Map<String, dynamic> cloud) async {
    final date = cloud['date'] as String?;
    if (date != _today()) return;
    final cloudUsed = (cloud['used'] as num?)?.toInt() ?? 0;
    final prefs = await SharedPreferences.getInstance();
    final localUsed = prefs.getString(_dateKey) == date ? (prefs.getInt(_usedKey) ?? 0) : 0;
    if (cloudUsed > localUsed) {
      await prefs.setString(_dateKey, date!);
      await prefs.setInt(_usedKey, cloudUsed);
    }
  }
}
