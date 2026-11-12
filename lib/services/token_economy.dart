/// Jeton ekonomisinin tek kaynağı: tüm harcama ve kazanım miktarları burada tanımlanır.
///
/// Tasarım ilkesi: jeton kıt bir kaynak olmalı. Harcamalar kazanımdan yüksek tutulur,
/// pasif hediyeler azaltılır, kazanma yolları ise çaba ya da izleme gerektirir
/// (reklam, arkadaş daveti, oyun içi performans).
class TokenEconomy {
  TokenEconomy._();

  // ---------------------------------------------------------------- Harcamalar
  /// Ücretsiz günlük hak bittikten sonra bir test girişi
  static const int quizEntryCost = 15;

  /// 50/50 ve çift cevap jokerleri (her biri)
  static const int jokerCost = 5;

  /// Soru atlama jokeri
  static const int jokerSkipCost = 10;

  /// 1v1 düello giriş ücreti
  static const int duelEntryCost = 20;

  // ----------------------------------------------------------------- Kazanımlar
  /// Yeni kullanıcı hoşgeldin bonusu (bir kez)
  static const int welcomeBonus = 60;

  /// Günlük ödül (her gün, seri ile birlikte)
  static const int dailyRewardAmount = 30;

  /// Ödüllü reklam izleme ödülü (cooldown ile sınırlı)
  static const int rewardedAdAmount = 30;

  /// Günlük reklam hedefi: bu kadar reklam izlenince bonus verilir
  static const int adGoalCount = 3;
  static const int adGoalBonus = 40;

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
  static const int speedRoundEntryCost = 10;
  static const int speedRoundTokensPerCorrect = 3;

  /// Çarpanlı Tahta: giriş ücreti ve her 20 puan için 1 jeton
  static const int boardEntryCost = 20;
  static const int boardPointsPerToken = 20;

  /// Mini oyunlar (Token Arena): bahis ve kazanınca geri dönen toplam tutar (2x)
  static const int miniGameStake = 50;
  static const int miniGamePayoutMultiplier = 2;

  // ------------------------------------------------------- Offline quiz ödülü
  /// Çevrimdışı (tek kişilik) bir quiz tamamlanınca sabit ödül; doğru sayısına bağlı değil
  static const int offlineQuizReward = 20;

  /// Haftalık kategoride çarpan
  static const int offlineWeeklyMultiplier = 2;
}
