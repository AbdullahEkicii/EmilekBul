/// Jeton ekonomisinin tek kaynağı: tüm harcama ve kazanım miktarları burada tanımlanır.
///
/// Tasarım ilkesi: jeton kıt bir kaynak olmalı. Harcamalar kazanımdan yüksek tutulur,
/// pasif hediyeler azaltılır, kazanma yolları ise çaba ya da izleme gerektirir
/// (reklam, arkadaş daveti, oyun içi performans).
class TokenEconomy {
  TokenEconomy._();

  // ---------------------------------------------------------------- Harcamalar
  /// Ücretsiz günlük hak bittikten sonra bir test girişi
  static const int quizEntryCost = 25;

  /// 50/50 ve çift cevap jokerleri (her biri)
  static const int jokerCost = 12;

  /// Soru atlama jokeri
  static const int jokerSkipCost = 20;

  /// 1v1 düello giriş ücreti
  static const int duelEntryCost = 35;

  // ----------------------------------------------------------------- Kazanımlar
  /// Yeni hesap başlangıç bakiyesi (hoşgeldin bonusu ilk test sonunda verilir)
  static const int startingTokens = 0;

  /// Yeni kullanıcı hoşgeldin bonusu (bir kez, ilk test sonunda)
  static const int welcomeBonus = 40;

  /// Günlük ödül (her gün, seri ile birlikte)
  static const int dailyRewardAmount = 20;

  /// Ödüllü reklam izleme ödülü (cooldown ile sınırlı)
  static const int rewardedAdAmount = 30;

  /// Günlük reklam hedefi: bu kadar reklam izlenince bonus verilir
  static const int adGoalCount = 3;
  static const int adGoalBonus = 45;

  /// Davet edilen (yeni kullanıcı) ilk testini bitirince
  static const int referralInviteeReward = 250;

  /// Davet eden kişiye, davet ettiği her kullanıcı için
  static const int referrerReward = 150;

  /// Bir davet edene en fazla kaç arkadaş ödülü verilir
  static const int referrerRewardCap = 20;

  /// Günlük reklam hedefi bugün ödüllendirilebilir mi?
  static bool adGoalReady({required int watchedToday, required bool claimedToday}) {
    return watchedToday >= adGoalCount && !claimedToday;
  }

  /// Hızlı Tur: her çalıştırma için giriş ücreti ve doğru cevap başına kazanç
  static const int speedRoundEntryCost = 25;
  static const int speedRoundTokensPerCorrect = 2;

  /// Çarpanlı Tahta: giriş ücreti ve her 30 puan için 1 jeton
  static const int boardEntryCost = 40;
  static const int boardPointsPerToken = 30;

  /// Mini oyunlar (Token Arena): varsayılan giriş bahsi ve seçilebilir bahis kademeleri
  static const int miniGameStake = 50;
  static const List<int> arenaStakes = [25, 50, 100];

  /// Mini oyun galibiyet çarpanı (1.8x -> kasa avantajı korunur)
  static const double miniGamePayoutMultiplier = 1.8;

  // ------------------------------------------------------- Offline quiz ödülü
  /// Çevrimdışı (tek kişilik) bir quiz tamamlanınca sabit temel ödül
  static const int offlineQuizReward = 10;

  /// Haftalık kategoride çarpan
  static const int offlineWeeklyMultiplier = 2;

  /// Quiz performans bonusu: kusursuz (%100) -> +15, %80+ -> +8, %60+ -> +4 jeton
  static int offlinePerformanceBonus({
    required int score,
    required int totalQuestions,
  }) {
    if (totalQuestions <= 0 || score <= 0) return 0;
    final ratio = score / totalQuestions;
    if (ratio >= 1.0) return 15;
    if (ratio >= 0.8) return 8;
    if (ratio >= 0.6) return 4;
    return 0;
  }
}
